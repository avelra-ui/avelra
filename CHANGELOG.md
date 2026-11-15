# Changelog

## [0.4.0] - 2026-11-15

First public preview of the Avelra core on Linux x64.

### Added

- Public `window.avelra` namespace with `app.ping`, `app.ready`,
  `app.healthCheck`, `app.exit`, `os.getEnv` and `os.openUrl`.
- npm package publishing alongside the release artifacts.
- Canonical user documentation in `docs/user/`.
- Non-blocking `os.openUrl` path outside the GUI thread.

### Changed

- `window.nativeCall` is no longer part of the public API. The internal
  transport remains for the future `callExt` implementation.
- Starter app and examples use `window.avelra`.
- Linux x64 is the public preview target; Windows and macOS SDKs/installers
  continue building in CI for validation.

### Scope

- Extensions and `window.avelra.callExt` are planned for 0.5.
- Windows and macOS public rollout follows their runtime and signing gates.

## [0.3.1] - 2026-11-14

### Fixed

- npm tarball version is derived from `VERSION`; 0.3.0 accidentally shipped
  `avelra-0.2.0.tgz`. 0.3.1 ships `avelra-0.3.1.tgz`.

## [0.3.0] - 2026-11-14 — private alpha candidate

Private alpha candidate. Not a public release; Linux remains the verified
platform.

### Added

- `app.healthCheck` native method with schema 1, status, checks, extensions,
  uptime and platform/runtime metadata.
- Health card in the starter application with `ok/degraded/failed` status,
  check rows and an explicit `app.healthCheck` call example.
- Debian 13 support in the Linux matrix alongside Debian 12.

### Changed

- Starter uses `app.healthCheck` instead of `app.ping`; `app.ping` remains in
  the runtime for smoke tests.
- Linux release artifacts are built on Ubuntu 22.04 with a GLIBC 2.35 baseline
  check.
- WebKit developer extras are available through an opt-in debug build;
  production runtime keeps them disabled.

### Known limitations

- Private alpha: no public downloads.
- Windows/macOS remain experimental and are not part of the public alpha.
- Release gates for branch protection, pinned actions and public links are
  still open.

## [0.2.0] - 2026-11-10

Technical release with npm distribution.

### Added

- Universal `avelra-0.2.0.tgz` npm package built in GitHub Actions from the
  tagged source and platform release artifacts.
- Node launcher and Linux/Windows/macOS SDK payloads in one package.
- npm tarball and `SHA256SUMS-npm` are release assets; npm registry is not
  modified.

### Changed

- Release artifacts now include the npm package for technical testing.

## [0.1.0] - 2026-11-10

First technical release of the Avelra SDK. This is an early preview, not a
production-stable release.

### Added

- Linux x64, Windows x64 and macOS arm64 SDK artifacts built from the tagged
  commit.
- Linux tar.gz/deb, Windows zip/NSIS and macOS tar.gz/DMG packaging.
- One GitHub Release containing the artifacts, per-platform manifests and
  `SHA256SUMS`.
- `avelra init`, `run`, `build` and the internal runtime/pack tools.
- The Pulse wordmark and the pre-Pulse starter application.

### Known limitations

- Windows and macOS support is experimental and not yet verified on real
  machines.
- No code signing or notarization.
- No user-application installers for Windows/macOS in this release.
- Linux is the verified platform.

[0.1.0]: https://github.com/avelra-ui/avelra/releases/tag/v0.1.0

[0.3.0]: https://github.com/avelra-ui/avelra/releases/tag/v0.3.0

[0.3.1]: https://github.com/avelra-ui/avelra/releases/tag/v0.3.1
