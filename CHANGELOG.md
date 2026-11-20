# Changelog

Each release lists what changed since the release before it. The changes made
since the most recent release are under Unreleased.

## Unreleased

The first release of Ecstatic written in Wattle.

- `ecstatic build` loads the theme `_ecstatic.wattle` from the source
  directory, calls its `build` function and writes the pages it returns to
  the destination directory.
- `ecstatic build` reads the site's posts, pages and static files as Jekyll
  does, parses their YAML front matter and dates, gives posts URLs, passes
  them to the theme and copies the static files to the destination. A theme
  can set the URLs of posts by defining `permalink`.
- Posts and pages are converted from Markdown with cmark-gfm 0.29.0.gfm.13,
  which is compiled into `ecstatic`. A theme sets cmark's options and can
  edit each parsed document with transforms, using the `cmark/` functions.
  Posts and pages have `:html` and `:excerpt`, and themes can call
  `markdown/render` and `markdown/inline`.
- Builds write into a new directory beside the destination, which then
  replaces it, keeping `.git`, `.gitkeep` and `.svn` (or the paths in the
  configuration's `:keep`). A failed build leaves the previous site in place.
- Themes can write HTML and XML with Hiccup and use helpers for dates
  (strftime-style formatting, RFC 3339 and RFC 822), pagination, and Atom,
  RSS and JSON feeds. Hiccup tags can carry an ID and classes, as in
  `:div#main.post`, and Atom feeds can give the language of their content.
- Themes can highlight code with TextMate grammars, using a copy of Augite's
  highlighter (with Oniguruma), extended with begin/while rules.
- Posts and pages have `:modified`, the time of the last commit to the file,
  and the site has `:revision` and `:time`.
- `ecstatic serve` serves a built site over HTTP for previewing it.
- Front matter can use block lists of scalars, one `- item` per line.
