# Avelra

Avelra turns web UI into a small native desktop app: your HTML, CSS and
JavaScript run in the system WebView, while a tiny native runtime handles the
window, native calls and packaging.

## Status

**0.3.1 private alpha — Linux x64.**

There are no public downloads and the package is not yet published to the npm
registry. The tarball is distributed as a GitHub Release asset while the public
preview is being prepared.

## What this package contains

- the `avelra` CLI: `init`, `run`, `build`, `installer`;
- the native runtime, packer and installer;
- the native SDK payload for the current platform.

Node.js **22 or newer** is required by the launcher.

## Install from the release tarball

Download `avelra-0.3.1.tgz` from the release page, then install it locally:

```bash
npm install ./avelra-0.3.1.tgz
npx avelra --version
npx avelra init my-app
cd my-app
npx avelra run
```

Do not expect `npm install avelra` from the registry until the public preview
opens. Registry publishing needs the public repository and trusted publishing.

## Requirements

- Linux x64;
- GTK 3.24+ and WebKitGTK 4.1;
- Node.js 22+ for this launcher.

Ubuntu 22.04/24.04/26.04 and Debian 12/13 are the verified Linux targets.
Fedora/RHEL-compatible systems can use the SDK tar; native RPM packaging is
planned.

## Verification

The install, CLI, sample-app and UI checks are published on the quality page:

https://avelra.dev/quality/

Release status: https://avelra.dev/releases/
Documentation: https://avelra.dev/docs/
Website: https://avelra.dev/

## License

MIT.
