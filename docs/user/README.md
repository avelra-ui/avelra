# Avelra user documentation

This documentation describes the **0.4.0 Linux x64 public preview**.

Avelra is a desktop application framework for web developers. Use the frontend
stack you already know — React, Vue, Svelte or vanilla. Avelra runs the built
static output in the operating system's WebView; a small native runtime provides
the window, native calls and packaging without bundling a browser engine into
every app. Your frontend toolchain stays yours; Avelra does
not bundle or manage it.

## Start here

1. [Getting started](getting-started.md) — requirements, installation, first
   project, run and build.
2. [Using Avelra](usage.md) — project structure, CLI, native API, health checks
   and packaging.
3. [Troubleshooting](troubleshooting.md) — common dependency, display, port and
   packaging errors.

## Platform support

| Platform | Status | Install |
|---|---|---|
| Ubuntu 22.04 / 24.04 / 26.04 x64 | verified | deb, tar |
| Debian 12 / 13 x64 | verified | deb, tar |
| Other glibc-based x64 | best-effort; not in verified matrix | tar |
| Windows x64 | private/experimental | not public |
| macOS arm64 | private/experimental | not public |

The Linux runtime requires:

- x86_64 Linux;
- GTK 3.24 or newer;
- WebKitGTK 4.1;
- glibc 2.35 or newer for the release binaries.

The npm launcher requires Node.js 22 or newer.

## What this preview includes

- `avelra init`, `run`, `build`, `installer` and `doctor`;
- a single executable for each application;
- app installers for tar, deb and AppImage;
- the `window.avelra` core namespace;
- `window.avelra.app.healthCheck()` with runtime and platform status;
- a starter application with a working health card.

## Design choices

- **Local-first by construction.** Native calls use the WebView bridge, not an
  HTTP or WebSocket control API, so the app does not expose its privileged API
  on the network.
- **One window per process.** The runtime stays small and the life cycle stays
  predictable.
- **Fixed core native methods.** Core APIs are small and explicit; the public
  preview does not expose application-defined native methods.
- **System WebView.** The app does not bundle a second browser engine.
- **JSON at the bridge boundary.** Calls and results have one explicit,
  debuggable contract.

Browser/cloud mode is not a goal for this runtime: Avelra is a local desktop
runtime, not a remote application host.

## Current limitations

- Core calls carry JSON, not binary or streaming data. Large blobs must be
  encoded (for example as base64), which adds memory copies and can block the UI
  thread.

## Not included in 0.4

The extension API is not part of the 0.4 public preview:

- `window.avelra.callExt` is absent;
- sidecar extensions are not documented or supported publicly;
- extensions are planned for 0.5.

## Verify your installation

```bash
avelra --version
avelra doctor
```

`doctor` reports GTK, WebKitGTK and platform readiness. A failed check includes
an actionable hint.

For the release verification matrix, see
[avelra.dev/quality](https://avelra.dev/quality/).
