# Ecstatic

[![Latest Release][release-badge]][release-latest]
[![Test Status][test-badge]][test-status]

[release-badge]: https://img.shields.io/github/v/release/pyrmont/ecstatic
[release-latest]: https://github.com/pyrmont/ecstatic/releases/latest
[test-badge]: https://github.com/pyrmont/ecstatic/actions/workflows/test.yml/badge.svg
[test-status]: https://github.com/pyrmont/ecstatic/actions/workflows/test.yml

Ecstatic is a static site generator. This repository provides `ecstatic`, a
command-line utility written in the [Wattle][] programming language. It is
intended to be a drop-in replacement for simple Jekyll installations.

[Wattle]: https://github.com/pyrmont/wattle

It reads a site's posts, pages and static files as [Jekyll][] does but differs
in that:

[Jekyll]: https://jekyllrb.com

- templates are Wattle functions that return Hiccup rather than Liquid
- features that Jekyll adds with plug-ins are written in the site's theme
- Markdown is converted with cmark-gfm, and a theme can edit each parsed
  document before it is rendered
- code is highlighted using TextMate's language grammars
- everything is compiled into one executable, with no Ruby or gems to install

## Building

#### Pre-Built

Pre-built binaries of `ecstatic` are available as tarballs via the
[Releases][github-releases] section on GitHub for:

- Linux (x86-64 and aarch64, statically linked)
- macOS (aarch64)

[github-releases]: https://github.com/pyrmont/ecstatic/releases

```console
$ curl -LO https://github.com/pyrmont/ecstatic/releases/latest/download/ecstatic-<version>-<platform>-<arch>.tar.gz
$ tar -xzf ecstatic-<version>-<platform>-<arch>.tar.gz
$ cd ecstatic-<version>
```

Each tarball holds the binary and the man page.

#### From Source

To build the `ecstatic` binary from source, you need [Zig][] 0.17.1 and
Wattle, installed with the `<prefix>/share/wattle` support files. `-p` gives
the Wattle install prefix, or set `WATTLE_PREFIX` instead:

[Zig]: https://ziglang.org

```console
$ git clone https://github.com/pyrmont/ecstatic
$ cd ecstatic
$ wattle -p ~/.local build exe --release fast
```

The executable is at `zig-out/bin/ecstatic`. It includes the Wattle runtime,
[cmark-gfm][] and [Oniguruma][] (vendored in `deps/`), so the target system
does not need Wattle or any other library to be installed.

[cmark-gfm]: https://github.com/github/cmark-gfm
[Oniguruma]: https://github.com/kkos/oniguruma

Ecstatic builds for Unix-like systems and has been tested on `aarch64-macos`
and `x86_64-linux-musl`. To build for a target different than the building
system, use `--target`. For example, to build a static executable for a Linux
server:

```console
$ wattle -p ~/.local build exe --release fast -t x86_64-linux-musl
```

See `man wattle-build` for more information.

## Installing

Move the `ecstatic` binary somewhere on your path and the man page to the
appropriate location. For example:

```console
# use sudo or doas depending on the permissions of the target directories
$ sudo cp zig-out/bin/ecstatic /usr/local/bin/
$ sudo cp man/man1/ecstatic.1 /usr/local/share/man/man1/
```

If you have Wattle installed, you can instead build and install `ecstatic`
and its man page under your `WATTLE_PREFIX` in one step:

```console
$ wattle apps install https://github.com/pyrmont/ecstatic
```

Run `wattle apps upgrade ecstatic` to reinstall it from the repository and
`wattle apps remove ecstatic` to remove it.

## Using

Run `ecstatic --help` for commands and options. See
[`ecstatic(1)`][ecstatic-man] for the full reference (`man ecstatic`).

[ecstatic-man]: man/man1/ecstatic.1.predoc

### Prerequisites

`git` is optional. If the source directory is in a Git repository, posts and
pages get the time of the last commit to their file as `:modified` and the
site gets the commit hash of `HEAD` as `:revision`. Without `git`, or outside
a repository, `:modified` is the file's modification time and `:revision` is
nil.

### Building a Site

Use `build` in the site's source directory:

```
Usage: ecstatic build [--source <dir>] [--destination <dir>] [--quiet]

Build a site.

Options:

 -s, --source <dir>         The directory of the site's source files. (Default: .)
 -d, --destination <dir>    The directory to write the site into. (Default: ../public)
 -q, --quiet                Suppress progress output.

 -h, --help                 Show this help message.
```

For a site whose source is in `src/` and whose pages are served from
`public/`:

```console
$ cd src
$ ecstatic build
```

Every build is a full rebuild. Ecstatic writes the site into a new directory
beside the destination and then replaces the destination with it, so a failed
build leaves the previous site in place. `.git`, `.gitkeep` and `.svn` in the
destination are carried over to the new site.

### Previewing a Site

Use `serve` to preview a built site in a browser:

```
Usage: ecstatic serve [--directory <dir>] [--host <host>] [--port <port>] [--quiet]

Serve a built site locally.

Options:

 -d, --directory <dir>    The directory to serve. (Default: ../public)
 -H, --host <host>        The address to listen on. (Default: 127.0.0.1)
 -p, --port <port>        The port to listen on. (Default: 4000)
 -q, --quiet              Suppress the log of requests.

 -h, --help               Show this help message.
```

The defaults match those of `build`, so running `ecstatic serve` in the same
directory serves the site at <http://127.0.0.1:4000/>. A path ending in `/`
gives the directory's `index.html`, and a path with no file gives the file
with `.html` added if there is one. It is not intended for production use.

### Writing a Theme

A site's theme is the file `_ecstatic.wattle` in its source directory. It is
compiled each time the site is built, so it can be changed without rebuilding
`ecstatic`, and it can import files beside it by relative path.

The theme defines `build`, a function that takes a map of the site and returns
a vector of pages. Each page is a map with `:path`, relative to the
destination directory, and `:body`. The site map has the site's posts (newest
first), pages and static files. Static files are copied after the theme's
pages are written.

```clojure
(def config {:title "Example" :offset "+0900"})

(defn build [site]
  [{:path "index.html"
    :body (hiccup/html5
            [:html
             [:body
              [:h1 (get-in site [:config :title])]
              [:ul (map #(do [:li [:a {:href ($ :url)} ($ :title)]])
                        (site :posts))]]])}])
```

The theme can also define `config`, a map that is passed to `build` as
`:config`, and `permalink`, a function that returns a post's URL. Ecstatic
reads `:offset`, `:include`, `:exclude`, `:future?`, `:markdown` and `:keep`
from `config`; see [`ecstatic(1)`][ecstatic-man].

Themes write pages with Hiccup and can use helpers for dates, pagination,
feeds and highlighting with TextMate grammars (`hiccup/`, `date/`,
`paginate/`, `feed/` and `highlight/`) without importing anything.

### Front Matter

Front matter is YAML, but only a subset of it is supported: plain and quoted
scalars, flow lists (`[a, b]`), block lists of scalars (one `- item` per
line), nested maps and literal block scalars (`|`). Other YAML, such as
folded scalars (`>`), anchors, tags and maps inside lists, is an error that
names the line.

### Markdown

Posts and pages have `:html`, converted from Markdown with cmark-gfm, and
`:excerpt`. The Markdown configuration sets cmark's options and lists
transforms, functions that edit the parsed document with the `cmark/`
functions before it is rendered:

```clojure
(defn wrap-footnote-refs [root]
  (each node (cmark/nodes root)
    (when (= :footnote-reference (cmark/type node))
      (cmark/insert-before! node (cmark/set-literal! (cmark/new root :html-inline) "<span>"))
      (cmark/insert-after! node (cmark/set-literal! (cmark/new root :html-inline) "</span>")))))

(def config {:markdown {:options [:footnotes :smart :unsafe]
                        :transforms [wrap-footnote-refs]}})
```

### Highlighting Code

Ecstatic does not include any grammars. Copy the `.tmLanguage.json` files for
the languages you use into a directory in the site, load them with
`highlight/load-grammars` and replace each code block in a Markdown transform
with the HTML from `highlight/lines`. Each token is a `<span>` with a class
such as `hl-keyword` or `hl-string`, which the site's stylesheet colours.

## Switching from Jekyll

Ecstatic reads `_posts/`, front matter, dates and categories as Jekyll does,
and gives posts Jekyll's default URLs, so posts can usually stay as they are.
The rest of a Jekyll site needs to be moved into the theme:

- Move the settings in `_config.yml` into the theme's `config`. Directories
  such as `_pages` that Jekyll was told to include go in `:include`.
- Rewrite layouts and includes as Wattle functions. Ecstatic does not read
  Liquid.
- Replace plug-ins with functions in the theme, Markdown transforms or
  Ecstatic's helpers (such as `paginate/pages` for jekyll-paginate).
- Compile Sass ahead of time and commit the CSS. Ecstatic does not compile
  Sass, and a `.scss` file with front matter is read as a page.
- If the destination is tracked by Git, as with a `.gitkeep`, make sure the
  tracked paths are in `:keep`.

## Testing

Build the executable and the native modules, then run the Wattle test files:

```console
$ wattle build exe
$ wattle build lib
$ wattle test
```

Run these commands from the project root. The tests need `git` and write
fixture sites in `tmp/test/`. The [test workflow][test-status] builds and
tests Ecstatic on Linux and macOS.

## Documentation

The man page is written in [Predoc][]. Edit `man/man1/ecstatic.1.predoc` and
regenerate the page with:

[Predoc]: https://github.com/pyrmont/predoc

```console
$ predoc man/man1/ecstatic.1.predoc -o man/man1/ecstatic.1
```

Commit both the source and the generated page.

## Releasing

Update the version in `info.edn` and the man page, regenerate the man page
and update `CHANGELOG.md`. For example, for version `0.1.0`:

```console
$ wattle res/tools/version.wattle 0.1.0
$ wattle build exe
$ wattle build lib
$ wattle test
```

The version script requires `predoc` on your path and can run from any
directory. It renames the Unreleased heading in `CHANGELOG.md` to the version
and the date, such as `## 0.1.0 (2026-11-15)`. Review and commit the changes, then tag the commit and push the
commit and tag:

```console
$ git tag v0.1.0
$ git push origin master
$ git push origin v0.1.0
```

After tagging the release, run `wattle res/tools/version.wattle DEVEL`, which
also adds an empty Unreleased section, and commit the result to return to development.

## Bugs

Report issues in [GitHub Issues][issues].

[issues]: https://github.com/pyrmont/ecstatic/issues

## Licence

Ecstatic is licensed under the MIT Licence. See [LICENSE][] for more details.
cmark-gfm and Oniguruma are included pursuant to their licences.

[LICENSE]: LICENSE
