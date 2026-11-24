# Avelra

Avelra is a desktop app framework for web developers. Use the frontend stack
you already use — React, Vue, Svelte or vanilla — and run the built static
output in the system WebView. A small native runtime provides the window, native
calls and packaging.

## Status

**0.4.2 public preview — Linux x64.**

This is the first public preview of the Avelra core.

## What this package contains

- the `avelra` CLI: `init`, `run`, `build`, `installer`;
- the native runtime, packer and installer;
- the native SDK payload for the current platform.

Node.js **22 or newer** is required by the launcher.

## Install

From npm:

```bash
npm install -g avelra@0.4.2
avelra init my-app
cd my-app
avelra run
```

Or from the release tarball:

```bash
npm install ./avelra-0.4.2.tgz
npx avelra --version
```

## Core API

```js
await window.avelra.app.healthCheck();
await window.avelra.os.openUrl("https://avelra.dev/docs/");
```

The 0.4 public API focuses on core lifecycle, health and OS helpers.
Extensions and `callExt` are planned for 0.5.

## Platform status

macOS arm64 is an **unverified technical preview**. CI builds the artifact, but
runtime and UI behavior have not been validated.

The 0.4.2 package remains Linux x64 only. The launcher prints a warning when it
starts on macOS arm64.

## Requirements

- Linux x64;
- GTK 3.24+ and WebKitGTK 4.1;
- Node.js 22+ for this launcher.

Ubuntu 22.04/24.04/26.04 and Debian 12/13 are the verified Linux targets.
Fedora/RHEL-compatible systems can use the SDK tar; native RPM packaging is
planned.

## Verification

The install, CLI, sample-app, UI and npm checks are published on the quality
page:

https://avelra.dev/quality/

Release status: https://avelra.dev/releases/
Documentation: https://avelra.dev/docs/
Website: https://avelra.dev/

## License

MIT.
