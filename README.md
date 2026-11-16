# Avelra

Avelra turns a web UI into a native desktop app.

Bring the frontend you already have — React, Vue, Svelte or vanilla — and
Avelra gives it a native window, a small local API and a single-file
distribution path. The app runs in the system WebView; Avelra does not bundle a
second browser engine.

The **0.4.2 Linux x64 public preview** is the current focus.

## What Avelra gives you

- **Your existing web UI, as a desktop app.** Build the frontend with the tools
  you already use; Avelra runs the built static output.
- **A small native shell.** The runtime owns the window, lifecycle and local
  native calls, so the app stays small.
- **One executable.** `avelra build` embeds the client assets and produces a
  single file that runs without a separate client directory.
- **Linux distribution formats.** Ship tar, deb or AppImage installers.
- **Direct native access.** Call window, OS and app capabilities from the page
  through a small JavaScript API, without a separate service to run.

## How it fits together

```text
your web UI (client/)
        +
avelra.config.json
        │
        ▼
avelra build
        │
        ▼
single executable
        │
        ▼
the system WebView + the Avelra native shell
```

Avelra applications use HTML, CSS and JavaScript at runtime. The frontend
toolchain stays yours.

## Start here

1. [Getting started](docs/user/getting-started.md) — install the SDK, create an app and
   run it.
2. [Using Avelra](docs/user/usage.md) — project structure, CLI, core API and packaging.
3. [Troubleshooting](docs/user/troubleshooting.md) — dependency, display, port and
   packaging issues.

## Platform status

| Platform | What exists today | Next gate |
|---|---|---|
| Ubuntu 22.04 / 24.04 / 26.04 x64 | Verified SDK, runtime, loading overlay, deb and tar | 0.4 public preview |
| Debian 12 / 13 x64 | Verified SDK, runtime, loading overlay, deb and tar | 0.4 public preview |
| Windows x64 | SDK, runtime, NSIS installer and doctor checks build in CI | UI/runtime smoke, signing and public rollout |
| macOS arm64 | SDK, runtime, DMG and doctor checks build in CI | Runtime smoke, app bundle, signing/notarization |
| Fedora/RHEL-compatible x64 | Portable tar support | Native RPM packaging |
| Other glibc-based x64 | Portable tar support | Compatibility validation continues |

Windows and macOS already have code paths, CI builds, installers and dependency
checks. Their remaining gates are runtime/UI validation and signing.

The Linux runtime uses:

- x86_64 Linux;
- GTK 3.24 or newer;
- WebKitGTK 4.1;
- glibc 2.35 or newer for the release binaries.

The npm launcher uses Node.js 22 or newer.

## Status and next

The 0.4.2 preview focuses on the Linux x64 core and the `window.avelra` API.

- **Available now:** SDK installation, `init`/`run`/`build`, core native calls,
  single executable and app installers on the verified Linux targets.
- **Shipping with 0.4.2:** npm registry publishing alongside the release
  artifacts.
- **In development:** extension API for 0.5, Windows and macOS public rollout,
  native RPM packaging.

## Verify your installation

```bash
avelra --version
avelra doctor
```

`doctor` reports GTK, WebKitGTK and platform readiness, with an actionable hint
when a dependency needs attention.

For the release verification matrix, see
[avelra.dev/quality](https://avelra.dev/quality/).
