# cmark-gfm

This is the core library of [cmark-gfm][] 0.29.0.gfm.13, the latest release,
for Ecstatic's Markdown module (`src/cmark.zig`).

[cmark-gfm]: https://github.com/github/cmark-gfm

- `src/` is the release's `src/` directory without `main.c` (the command-line
  program) and the CMake files. `scanners.c` is the pre-generated output of
  `scanners.re`, so re2c is not needed.
- `config/` holds the headers that CMake would generate, written by hand:
  `config.h`, `cmark-gfm_version.h` and `cmark-gfm_export.h`.
- The GFM extensions (tables, strikethrough and so on) are not included.
  Footnotes are part of the core library.
- `COPYING` is the release's licence file.
