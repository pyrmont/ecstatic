# Ecstatic

[![Build Status](https://github.com/pyrmont/ecstatic/workflows/build/badge.svg)](https://github.com/pyrmont/ecstatic/actions?query=workflow%3Abuild)

Ecstatic is a no-frills static site generator written in Janet. It is in
development.

Ecstatic takes inspiration from [Jekyll][]. It uses [Temple][] for its
templating language.

[Jekyll]: https://jekyllrb.com/
[Temple]: https://git.sr.ht/~bakpakin/temple/

## Requirements

Ecstatic requires Janet 1.12.0 or higher.

It expects a user to provide a `_layouts` directory, a `_posts` directory for
Markdown-formatted posts and a `_config.jdn` configuration file.

## Building

Clone the repository and then run:

```console
$ jpm deps
$ jpm build
```

The `ecstatic` binary is in the `build` directory.

## Usage

If you have your code in a directory `src`, you can run Ecstatic from that
directory like so:

```console
$ /path/to/ecstatic
```

Your compiled website will be in the `_site` directory.

## Bugs

Found a bug? I'd love to know about it. The best way is to report your bug in
the [Issues][] section on GitHub.

[Issues]: https://github.com/pyrmont/ecstatic/issues

## Licence

Ecstatic is licensed under the MIT Licence. See [LICENSE][] for more
details.

[LICENSE]: https://github.com/pyrmont/ecstatic/blob/master/LICENSE
