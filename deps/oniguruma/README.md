# Oniguruma

This is the regular expression library [Oniguruma][] 6.9.10, for the
highlighter's native module (`src/onig.zig`). It was copied from Augite, which
vendors the same files.

[Oniguruma]: https://github.com/kkos/oniguruma

- `src/` holds the library's sources and headers that the module needs.
- `config/config.h` is the header that the configure script would generate,
  written by hand.
- `LICENSE` is the library's licence file.
