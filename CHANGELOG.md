# Changelog

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
