# Using Avelra

This page covers the application project, CLI, core native API, health checks
and packaging for the **0.4.0 Linux x64 public preview**.

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

The `client/` directory is served by a local HTTP server. It is not compiled
into the runtime, so HTML/CSS/JS changes do not require rebuilding Avelra.

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

The `client/` directory must exist when the app is run. The executable built by
`avelra build` embeds the client assets and does not need the directory at
runtime.

Use relative URLs for CSS, JS and other assets:

```html
<link rel="stylesheet" href="styles.css">
<script src="app.js"></script>
```

The application URL contains a random path token; absolute paths such as
`/app.js` bypass it and return 404.

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
ignore the Promise. A resolved Promise does not mean the page has repainted.

`os.openUrl` accepts only `http` and `https`. The browser process runs outside
the GUI thread; the Promise resolves when its exit status is known.

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
    "version": "0.4.0",
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
- `degraded` — the app works, but a component is still starting;
- `failed` — a critical check failed: config, client assets or static server.

`healthy` is `true` only when `status` is `ok`.

The `extensions` check is present in the runtime snapshot but extension support
is not part of the 0.4 public API.

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
dependencies. It installs the application into the system menu.

The `tar` target is useful for distributions without a native package format;
Fedora/RHEL-compatible systems can use it. Native RPM packaging is planned.

## Design choices

Avelra is a local desktop runtime:

- native calls use the WebView bridge, not HTTP or WebSocket;
- one window per process;
- core native methods are fixed;
- the app uses the system WebView rather than a bundled browser;
- JSON is the bridge contract.

Browser/cloud mode is intentionally out of scope. The app does not expose a
network control API for its native methods.

## Limitations

- Core calls carry JSON. Binary data must be encoded (for example as base64),
  which adds copies and can block the UI thread.
- Linux x64 is the only public platform.
- Windows and macOS builds remain private until their runtime and signing gates
  pass.
- Extensions and `window.avelra.callExt` are not part of 0.4.

## Not in 0.4

The extension API is planned for 0.5:

- no `window.avelra.callExt`;
- no public sidecar extension support;
- no application-defined native methods.
