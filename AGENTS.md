# Ecstatic Project Guide

## Project Overview

Ecstatic is a static site generator written in Wattle, a Lisp with
Clojure-like syntax that runs on a Zig rewrite of the Janet virtual machine.
The executable is `ecstatic`. It is intended to replace Jekyll for
articles.inqk.net and updates.inqk.net.

`PLAN.md` holds the design decisions, the URLs each site must keep and the
milestones. Read it before starting a milestone, and update it when a
decision changes or a milestone is done.

**Author**: Michael Camilleri
**License**: MIT
**Language**: Wattle
**Repository**: https://github.com/pyrmont/ecstatic

## Directory Structure

```
ecstatic/
├── lib/
│   ├── cli.wattle       # Command line (Gum's Argy-Bargy port) and `main`
│   ├── site.wattle      # Builds a site: reads it, runs the theme, writes files
│   ├── theme.wattle     # Loads `_ecstatic.wattle` from a source directory
│   ├── content.wattle   # Reads posts, pages and static files; URLs
│   ├── frontmatter.wattle # Splits and parses YAML front matter (a subset)
│   ├── markdown.wattle  # Options, transforms, rendering, inline and excerpts
│   ├── date.wattle      # Parses and formats dates and offsets (strftime, RFC 3339, RFC 822)
│   ├── feed.wattle      # Atom, RSS 2.0 and JSON with sorted keys
│   ├── fs.wattle        # Directory creation, file writing and removal
│   ├── git.wattle       # Revision and per-file commit times
│   ├── hiccup.wattle    # Hiccup to HTML or XML
│   ├── highlight.wattle # Loads TextMate grammars and highlights code
│   ├── hl/              # Copied from Augite: engine.wattle, classes.wattle
│   ├── paginate.wattle  # Splits items into numbered pages
│   ├── serve.wattle     # `ecstatic serve`: a static file server for previews
│   └── version.wattle   # Version label, fixed at compile time
├── test/
│   ├── executable.wattle       # Runs zig-out/bin/ecstatic
│   ├── cmark.wattle            # The native module itself
│   ├── content.wattle
│   ├── date.wattle
│   ├── feed.wattle
│   ├── frontmatter.wattle
│   ├── git.wattle              # Builds a repository under tmp/test/
│   ├── hiccup.wattle
│   ├── hl.wattle               # Scanner, classes, engine and highlight
│   ├── markdown.wattle
│   ├── paginate.wattle
│   ├── serve.wattle            # Starts a server in-process on a free port
│   ├── site.wattle
│   └── theme.wattle
├── src/cmark.zig        # Native module `cmark` over cmark-gfm
├── src/onig.zig         # Native module `onig` over Oniguruma (from Augite)
├── deps/gum/            # Vendored with `wattle gum args test`
├── deps/cmark-gfm/      # cmark-gfm 0.29.0.gfm.13: src/, config/ (hand-written headers)
├── deps/oniguruma/      # Oniguruma 6.9.10 (from Augite)
├── res/
│   ├── fixtures/        # Sites and grammars that tests copy to tmp/test/
│   ├── helpers/util.wattle # Test helpers: copy, make-site and rmrf
│   └── tools/           # version.wattle (release tooling)
├── man/man1/
│   ├── ecstatic.1.predoc  # Man page source (Predoc)
│   └── ecstatic.1         # Generated man page (committed)
├── info.edn             # Project and build declaration
├── CHANGELOG.md         # Changes by release, with an Unreleased section
└── PLAN.md              # Design and milestones
```

## Themes

A site's theme is `_ecstatic.wattle` in its source directory. `theme/load`
compiles it with `dofile` in a fresh environment (`make-env`), so a theme can
import files beside it by relative path and cannot change Ecstatic's own
bindings. This works in the built executable, including the cross-compiled
musl build, because the executable contains the compiler.

The theme must define `build`, a function that takes the site map and returns
a vector or array of pages, each a map with `:path` and `:body`. `site/build`
checks every page before writing any (no path twice, none that is a static
file), then writes the pages and copies the static files into a new
directory that replaces the destination (see Build pipeline). The theme may
also define:

- `config`, a map. Ecstatic reads `:offset` (such as `"+0900"`, default
  `"+0000"`), `:include` (underscore paths to read, such as `["_pages"]`),
  `:exclude` (paths to skip), `:future?` (include posts dated in the
  future), `:markdown` and `:keep` (paths in the destination to carry over,
  by default `site/default-keep`: `.git`, `.gitkeep` and `.svn`). The whole
  map is passed to `build` as `:config`.
- `permalink`, a function from a post to its URL. Without it, posts get
  Jekyll's `date` style, `/:categories/:year/:month/:day/:title.html`. A
  post's own `permalink` front matter takes precedence over both.

The site map has `:config`, `:source`, `:destination`, `:posts` (newest
first, each with `:url`), `:pages`, `:static` (paths), `:revision` (the
commit hash of HEAD, or nil) and `:time` (when the build started).
`content/read-site` documents the keys of a post and a page; `site/build`
adds `:html`, `:excerpt` and `:modified` (the last commit to the file, or its
modification time if it has none) to both.

## Markdown

`src/cmark.zig` wraps cmark-gfm as the native module `cmark`. `cmark/parse`
returns the document node; the other functions take and return node handles.
Each handle refers to its document's payload, which owns the tree. Nodes that
are unlinked or made with `cmark/new` are recorded on the document and freed
with it if they still have no parent, so a handle never points at freed
memory. `cmark/nodes` returns a snapshot, so a transform can edit the tree
while iterating it. Mutating functions end in `!`.

`lib/markdown.wattle` maps option keywords to cmark's bits and runs the
configuration's transforms. `site/build` gives every post and page `:html`
(converted when the path has a Markdown extension) and `:excerpt` (the
`excerpt` front matter, or for Markdown the HTML of
`markdown/excerpt-source`). The site's Markdown configuration is the theme
config's `:markdown`, `{:options [...] :transforms [...]}`.

Rendering uses cmark's C renderer. Jekyll used commonmarker's Ruby renderer;
on both sites the only difference is the footnote markup (see milestone 3
in `PLAN.md`).

`deps/cmark-gfm/README.md` says what was vendored. To update cmark-gfm,
replace `src/` from the release (without `main.c`), regenerate
`config/cmark-gfm_version.h` and check the list of `.c` files in `info.edn`.

## Highlighting

`lib/hl/engine.wattle`, `lib/hl/classes.wattle` and `src/onig.zig` are
copied from Augite. The engine follows vscode-textmate; Ecstatic's copy adds
begin/while rules (which YAML needs), and its classes add operators,
built-ins, constants, escapes and console prompts and output, and leave a
shell command's arguments plain. Mark changes to the copies in their header
comments so that they can be compared with Augite's.

`highlight/load-grammars` reads the `.json` grammars in a directory, keyed by
scope name, and `highlight/lines` gives the HTML of each line. The grammars
belong to the site, not to Ecstatic: articles.inqk.net keeps them in
`src/_grammars/` with a README that says where each came from. The theme
replaces each code block in a Markdown transform.

## Build pipeline

`site/build` writes into `.<name>.ecstatic-new` beside the destination
(removing any left from an earlier run), then `replace-destination` moves the
`:keep` paths from the old destination into it, renames the destination to
`.<name>.ecstatic-old`, renames the new directory into place, and removes the
old one. The new directory gets the old one's permissions. The destination is
refused if it is a file or contains the source, since replacing it would
remove the source.

Nothing is removed once a kept path has moved: a failure before then removes
only the new directory, and a failure after it raises an error naming where
both sites are. Keep it that way, since `.git` can be a kept path.

## Templates and helpers

- `lib/hiccup.wattle`: `html`, `html5` (with `<!doctype html>`), `xml`
  (self-closing empty elements, no void elements), `raw` and `escape`.
  Attributes are sorted so that output is the same on each run. Tags can carry an ID and
  classes, as in `:div#main.post`; this needs a Wattle that reads `#`
  inside keywords.
- `lib/date.wattle`: `format` (strftime directives, including `%-d`; checked
  against Ruby's), `rfc3339` (Jekyll's `date_to_xmlschema`), `rfc822`
  (`date_to_rfc822`) and `format-offset`.
- `lib/feed.wattle`: `atom`, `rss` and `json`. `json/encode` writes map keys
  in hash order, so `feed/json` writes its own objects, with sorted keys.
- `lib/paginate.wattle`: `pages`, which always gives at least one page.
- `lib/highlight.wattle`: `load-grammars` and `lines` (see Highlighting).
- `lib/git.wattle`: `revision` and `modified-times`, which reads the whole
  history in one `git log` call. Both give nothing, rather than an error,
  outside a repository.

## Content

`lib/content.wattle` follows Jekyll's rules: files under `_posts/` named
`YYYY-MM-DD-slug.ext` are posts, other files that begin with front matter are
pages, and the rest are static. Names beginning with `_` or `.` are skipped
unless under `:include`. Posts with equal dates are in descending order of
path, as in Jekyll. Dates are seconds since the epoch, with fractions
dropped; a date without an offset is read at the site's offset.

`lib/frontmatter.wattle` parses a subset of YAML: the YAML that the two
sites and Blueshift's output use, plus block lists of scalars (see the
comment at the top of the file). Anything else is an error that names the
line. Dates stay strings in the parsed map. It was checked against Ruby's
Psych, which Jekyll uses, on every file with front matter in both sites
(1,930 files) and matched on all of them; block lists were checked against
Psych separately. A construct that is not supported should raise an error
rather than parse differently from Psych.

A theme cannot `import` Ecstatic's modules, because a built executable has
no module path. Instead `theme/load` copies the bindings whose names begin
with a prefix in `theme/exposed` (`cmark/`, `date/`, `feed/`, `hiccup/`,
`highlight/`, `markdown/` and `paginate/`) into the theme's environment before `dofile`
runs. To offer a theme another module, import it
in `lib/theme.wattle` and add its prefix.

## Writing Wattle

Wattle is not Janet. Code copied from Janet or written from memory of it often
fails to parse or means something else:

- **Mutable literals use `!`**: `![]` is an array, `!{}` a table and `!""` a
  buffer. `@[]` and `@{}` are parse errors.
- **Splice is `|`**: `(f |args)`. A `;` starts a comment.
- **Short functions are `#(...)`**: `$` (or `$0`) is the first argument, `$1`
  the second and `$&` the rest. `|(...)` is a splice, not a function. A short
  function whose body is a collection literal needs `do`, as in
  `#(do {:path $})`, since `#({:path $})` calls the map.
- **Collections**: `[...]` is a persistent vector, `{...}` a persistent map and
  `#{...}` a set. `(...)` is a tuple and is only for calls; use vectors for
  data. There are no structs.
- **Updating persistent collections is cheap.** `assoc`, `conj`, `dissoc` and
  `disj` return a new collection that shares structure with the old one, so
  build values with them rather than filling a table and converting it.
  Assoc-ing `nil` removes a key. There is no persistent `update`; write
  `(assoc m k (f (get m k)))`. `update!` and `update-in!` are for tables.
  Mutable arrays and tables (`put!`, `array/push!`) are for accumulating
  inside one function.
- **Iterating a map**: `(each [k v] (pairs m) ...)`, or `eachk` and `eachv`.
  There is no `eachp`.
- **Quasiquote is a backtick and unquote is `~`**, as in a PEG grammar that
  calls a function: `` `(/ (<- :d) ~f) ``. Janet's `~(...)` and `,f` are
  wrong here: `~` outside a quasiquote is an unquote and `,` is whitespace.
- **Argument order differs from Janet in places**: `(string/join sep parts)`
  takes the separator first, like `string/split` and `string/find`.
- **There is no `some`**: use `find` with a predicate, or `any?` on values.
- **A backtick is quasiquote, not a string delimiter.** Use `"..."` or a raw
  string, `"""..."""`. A raw string drops the line break before its closing
  quotes.
- **`doc` is a macro.** Binding `doc` (as a parameter, say) compiles with a
  warning, which a theme's build prints. Name a document node `root`.
- **`map`, `filter` and similar return arrays**, which compare by identity.
  Compare results with `==` in tests, or convert them.
- **Parameter lists are vectors**, `& rest` binds a vector, and named options
  are `& {:keys [a b] :or {a 1}}`. Map patterns put the binding first:
  `{name :name}`.
- **Error helpers**: `error`, `errorf`, `assertf`, and `try` with a `([e] ...)`
  handler.

`man 7 wattle` describes the language and `wattle/notes/LANGUAGE.md` records
how it differs from Janet. Run `wattle check <file>` on each changed file.
It cannot resolve the native `cmark` and `onig` imports, so files that
import them (directly or through `markdown`, `highlight`, `hl/engine`,
`theme`, `site` or `cli`) fail with "could not find module"; the tests cover
those.

## Build

The build is declared in `info.edn` and driven by `wattle build exe`. There is
no `build.zig`.

```bash
wattle build exe                                        # zig-out/bin/ecstatic
wattle build lib                                        # zig-out/lib/libcmark and libonig, for tests
wattle build exe --release fast -t x86_64-linux-musl    # static Linux binary
```

The man page source is `man/man1/ecstatic.1.predoc`. Regenerate
`man/man1/ecstatic.1` with `predoc man/man1/ecstatic.1.predoc -o
man/man1/ecstatic.1` and commit both. Code blocks in Predoc use four
backticks.

`wattle res/tools/version.wattle <version>` sets the version in `info.edn`
and the man page and updates `CHANGELOG.md`.

## Testing

Tests are plain Wattle scripts in `test/`, using `deps/gum/test.wattle`
(`deftest`, `is`, `run-tests!`). `wattle test` runs every file in `test/`, so
put nothing else there. Helpers are in `res/helpers/util.wattle`, imported as
`(import ../res/helpers/util :as h)`.

Tests write sites under `tmp/test/`, which is ignored by Git, and remove them
when they finish. A site that is static content, such as a theme with posts
or a directory of grammars, is a committed tree in `res/fixtures/<name>/`
that the test copies with `h/copy`; a test never writes into `res/`. A small
site that is clearer beside its assertion is written from a map with
`h/make-site`.

```bash
wattle build exe      # test/executable.wattle runs zig-out/bin/ecstatic
wattle build lib      # tests that import cmark or onig load zig-out/lib
wattle test
```

## Common Tasks

### Adding a CLI option
1. Add it to the rules in `lib/cli.wattle` and pass it to `site/build`.
2. Update `man/man1/ecstatic.1.predoc`, regenerate `ecstatic.1`, and update
   the help text in `README.md` and `test/executable.wattle`.
3. Add an entry to the Unreleased section of `CHANGELOG.md`.
