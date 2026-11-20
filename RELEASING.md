# Releasing Ecstatic

Ecstatic releases are prepared locally, built by GitHub Actions and then
published from the draft GitHub release created by the release workflow. `fledge
<version>` runs these steps in order, checking each one, and can be run again
to continue after a failure.

The commands below use `0.2.0` as an example Ecstatic version. Substitute the
version required for the release being prepared.

## 1. Check the Development Branch

Ensure all intended changes have been committed and push `master`:

```console
$ git status
$ git push origin master
```

Wait for the test workflow on GitHub Actions to pass before preparing the
release commit.

## 2. Prepare the Release Commit

Read the Unreleased section of `CHANGELOG.md` and choose the version from the
changes it lists: a patch-level version such as 0.2.1 for fixes and a
minor-level version such as 0.3.0 for new behaviour. Edit the section until it
describes the release.

Pass the Ecstatic version without its `v` prefix to the version script:

```console
$ wattle res/tools/version.wattle 0.2.0
```

The script updates `info.edn` and the Predoc manpage source, regenerates the
mdoc manpage with `predoc`, and replaces the Unreleased heading of
`CHANGELOG.md` with the version and the date. It stops before writing anything
if `CHANGELOG.md` has no Unreleased section. Review and test the result:

```console
$ git diff
$ git diff --check
$ wattle build lib
$ wattle build exe
$ wattle test
```

Stage only the version-related files. Do not accidentally include a locally
built `ecstatic` executable or other unrelated files:

```console
$ git add info.edn CHANGELOG.md man/man1/ecstatic.1 man/man1/ecstatic.1.predoc
$ git commit -m "Prepare for v0.2.0 release"
$ git push origin master
```

Wait for the test workflow to pass again.

## 3. Tag the Release

Ecstatic uses lightweight Git tags. Add the `v` prefix when creating the tag:

```console
$ git tag v0.2.0
$ git push origin v0.2.0
```

## 4. Build the Release Archives

Run the `release` workflow with the tag as its version input:

```console
$ gh workflow run release.yml -f version=v0.2.0
```

Alternatively, open GitHub Actions, select the `release` workflow, choose
**Run workflow**, and enter `v0.2.0`.

The workflow checks out the tag, runs the tests, builds archives for Linux
(x86-64 and aarch64, statically linked with musl) and macOS (aarch64), and
creates a draft GitHub release containing those archives, with the release's
section of `CHANGELOG.md` as its notes. Each paragraph and entry is joined onto
one line, because GitHub keeps the line breaks of a release's notes and
`CHANGELOG.md` is wrapped to 80 columns. The workflow fails if `CHANGELOG.md`
has no section for the version. When the workflow succeeds, review the draft
release and publish it.

## 5. Return to Development

Reset the source version to `DEVEL`:

```console
$ wattle res/tools/version.wattle DEVEL
```

This updates `info.edn`, the manpage source and the generated manpage again,
and adds an empty Unreleased section to `CHANGELOG.md`.

Commit the reset and push `master`:

```console
$ git add info.edn CHANGELOG.md man/man1/ecstatic.1 man/man1/ecstatic.1.predoc
$ git commit -m "Reset version to DEVEL"
$ git push origin master
```

From then on, each change worth recording adds an entry to the Unreleased
section of `CHANGELOG.md`.
