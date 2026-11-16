# Using Avelra

This page covers the application project, CLI, core API, health checks and
packaging for the **0.4.1 Linux x64 public preview**.

## Project layout

`avelra init my-app` creates a self-contained project:

```text
my-app/
  avelra.config.json
  client/
    index.html
    app.js
    styles.css
  icon.png
```

After `avelra build` or `avelra installer`, output is written under
`dist/<app>/`.

The client is served by a local HTTP server during `avelra run`. `avelra build`
embeds the client assets in the executable, so the built app runs from one file.

## Configuration

`avelra.config.json`:

```json
{
  "name": "my-app",
  "version": "0.1.0",
  "identifier": "com.example.my-app",
  "client": "client",
  "icon": "icon.png",
  "window": {
    "title": "my-app",
    "width": 960,
    "height": 600
  }
}
```

| Field | Required | Description |
|---|---|---|
| `name` | yes | Application name |
| `version` | no | Application version; defaults to `0.1.0` |
| `identifier` | no | Stable package identifier |
| `client` | no | Client directory; defaults to `client` |
| `icon` | no | Icon path |
| `window.title` | no | Window title |
| `window.width` / `height` | no | Initial window size; defaults to 600×400 |
| `linuxDebDepends` | no | Extra Debian dependencies |

Use relative URLs for CSS, JS and other assets:

```html
<link rel="stylesheet" href="styles.css">
<script src="app.js"></script>
```

The application URL contains a random path token, so relative assets resolve
correctly inside the app.

## CLI

```text
avelra init <dir>                 create a new project
avelra run                        run from the project directory
avelra build                      build a single executable
avelra installer --target <name>  build an app installer
avelra doctor                     check runtime dependencies
```

`installer` targets:

| Target | Requirement | Output |
|---|---|---|
| `tar` | tar | `.tar.gz` |
| `deb` | `dpkg-deb` | `.deb` |
| `appimage` | `appimagetool` | `.AppImage` |

`avelra run` uses the development server and reads `client/` from disk.
`avelra build` creates a single executable in `dist/<app>/`.
`avelra installer` packages that build for installation.

## Core API

The page gets one namespace:

```js
window.avelra
```

Available methods:

```js
await window.avelra.app.ping({ value: 42 });
await window.avelra.app.ready();
await window.avelra.app.healthCheck();
await window.avelra.app.exit();
await window.avelra.os.getEnv("HOME");
await window.avelra.os.openUrl("https://avelra.dev/");
```

| Method | Result |
|---|---|
| `app.ping(data)` | `{message, echo, runtime}` |
| `app.ready()` | resolves after the loading signal is sent |
| `app.healthCheck()` | health snapshot |
| `app.exit()` | resolves after the close request is sent |
| `os.getEnv(key)` | environment variable value |
| `os.openUrl(url)` | resolves after the browser handler completes |

All methods return a Promise. `ready` and `exit` are commands; callers may
ignore the Promise. The Promise confirms completion of the operation, so UI
updates should be driven by the page's own rendering flow.

`os.openUrl` supports `http` and `https`. The browser process runs outside the
GUI thread; the Promise resolves when its exit status is known.

## Health check

`window.avelra.app.healthCheck()` returns a snapshot without changing
application state:

```json
{
  "schema": 1,
  "status": "ok",
  "healthy": true,
  "checkedAt": "2026-11-15T08:00:00Z",
  "app": {
    "name": "my-app",
    "version": "0.1.0",
    "identifier": "com.example.my-app"
  },
  "runtime": {
    "version": "0.4.1",
    "protocol": 1,
    "startedAt": "2026-11-15T07:55:00Z",
    "uptimeMs": 300000
  },
  "platform": {
    "os": "linux",
    "arch": "amd64",
    "webview": "webkitgtk-4.1"
  },
  "checks": [
    { "id": "config", "status": "ok", "message": "" },
    { "id": "client-assets", "status": "ok", "message": "" },
    { "id": "static-server", "status": "ok", "message": "" },
    { "id": "extensions", "status": "ok", "message": "" }
  ],
  "extensions": []
}
```

Status values:

- `ok` — all critical checks are healthy;
- `degraded` — the app works while a component finishes starting;
- `failed` — a critical check needs attention: config, client assets or static
  server.

`healthy` is `true` when `status` is `ok`.

The `extensions` check is ready for the extension API planned for 0.5.

## Packaging

Build the app:

```bash
avelra build
```

Build a Debian package:

```bash
avelra installer --target deb
```

The `deb` includes the executable, desktop entry, icon and configured
dependencies, and adds the application to the system menu.

The `tar` target supports distributions without a native package format,
including Fedora/RHEL-compatible systems. Native RPM packaging is planned.

## How Avelra is designed

Avelra is a local desktop runtime:

- native calls use the WebView bridge;
- one window per process;
- core native methods are fixed and focused;
- the app uses the system WebView;
- JSON is the bridge contract.

Browser and cloud hosting are future product directions; the current runtime is
optimized for local desktop apps.

## Status and next

Linux x64 is the verified platform for the 0.4.1 preview. Windows and macOS
already build SDKs, runtime binaries and installers in CI; runtime/UI smoke and
signing are the remaining gates before public rollout. Fedora/RHEL native RPM
packaging and the extension API are in development. npm registry publishing
ships with the 0.4.1 release.

## Extensions

Extension support is in development for 0.5. The 0.4 public API focuses on the
core methods above; extension calls will use a dedicated `callExt` API in the
next milestone.
