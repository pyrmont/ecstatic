# Ecstatic

Ecstatic provides `ecstatic`, a static site generator written in
[Wattle][]. It is intended to replace Jekyll for articles.inqk.net and
updates.inqk.net.

[Wattle]: https://github.com/pyrmont/wattle

> [!WARNING]
> Ecstatic is at an early stage of development. It reads posts, pages and
> static files, converts Markdown, runs the theme and replaces the
> destination with the pages it returns. Neither site has a theme yet, and
> code is not highlighted.

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

`ecstatic serve` is for previewing a built site. A path ending in `/` gives
the directory's `index.html`, and a path with no file gives the file with
`.html` added if there is one.

```
Usage: ecstatic build [--source <dir>] [--destination <dir>] [--quiet]

Build a site.

Options:

 -s, --source <dir>         The directory of the site's source files. (Default: .)
 -d, --destination <dir>    The directory to write the site into. (Default: ../public)
 -q, --quiet                Suppress progress output.

 -h, --help                 Show this help message.
```

## Building

To build the `ecstatic` binary from source, you need Zig 0.17.1 and Wattle,
installed with its `<prefix>/share/wattle` package (for example, by running
`zig build -p ~/.local` in a Wattle checkout). `-p` gives the Wattle install
prefix, or set `WATTLE_PREFIX` instead:

```shell
$ git clone https://github.com/pyrmont/ecstatic
$ cd ecstatic
$ wattle -p ~/.local build exe --release fast
```

The executable is `zig-out/bin/ecstatic`. It includes the Wattle runtime and
[cmark-gfm][] (vendored in `deps/cmark-gfm`) and does not require Wattle or
any other program at runtime.

[cmark-gfm]: https://github.com/github/cmark-gfm

To build a static executable for a Linux server, pass a target:

```shell
$ wattle -p ~/.local build exe --release fast -t x86_64-linux-musl
```

## Themes

A site's theme is the file `_ecstatic.wattle` in its source directory. It is
compiled each time the site is built, so it can be changed without rebuilding
`ecstatic`, and it can import files beside it by relative path.

The theme defines `build`, a function that takes a map of the site and returns
a vector of pages. Each page is a map with `:path`, relative to the
destination directory, and `:body`. The site map has the site's posts (newest
first), pages and static files, which are read as Jekyll reads them. Static
files are copied after the theme's pages are written.

The theme can also define `config`, a map that is passed to `build` as
`:config`, and `permalink`, a function that returns a post's URL. Ecstatic
reads `:offset`, `:include`, `:exclude`, `:future?` and `:markdown` from
`config`; see ecstatic(1).

Themes write pages with Hiccup and can use helpers for dates, pagination,
feeds and highlighting with TextMate grammars (`hiccup/`, `date/`,
`paginate/`, `feed/` and `highlight/`) without importing anything. Posts and
pages have `:html`, converted from Markdown with cmark-gfm, `:excerpt` and
`:modified`, the time of the last commit to the file. The Markdown
configuration sets cmark's options and lists transforms, functions that edit
the parsed document with the `cmark/` functions before it is rendered:

```clojure
(defn wrap-footnote-refs [root]
  (each node (cmark/nodes root)
    (when (= :footnote-reference (cmark/type node))
      (cmark/insert-before! node (cmark/set-literal! (cmark/new root :html-inline) "<span>"))
      (cmark/insert-after! node (cmark/set-literal! (cmark/new root :html-inline) "</span>")))))

(def config {:markdown {:options [:footnotes :smart :unsafe]
                        :transforms [wrap-footnote-refs]}})
```

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

Each build writes into a new directory beside the destination and then
replaces the destination with it, so a failed build leaves the previous site
in place. `.git`, `.gitkeep` and `.svn` in the destination are kept.

## Testing

```shell
$ wattle build exe
$ wattle build lib
$ wattle test
```

## Licence

Ecstatic is licensed under the MIT Licence. See [LICENSE](LICENSE) for more
details.
