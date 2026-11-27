# Troubleshooting

This page covers common problems in the **Avelra 0.5.0**. Run
`avelra doctor` first: it checks GTK, WebKitGTK and the runtime dependencies.

## Installation

### `avelra: command not found`

The SDK `bin/` directory is not on `PATH`.

For the portable tar:

```bash
export PATH="$PWD/avelra-0.5.0-linux-x64/bin:$PATH"
avelra --version
```

For the deb, check that the package is installed:

```bash
dpkg -l | grep avelra
```

### Missing GTK or WebKitGTK

`avelra doctor`:

```text
GTK 3: OK
WebKitGTK 4.1: MISSING
  hint: sudo apt install libwebkit2gtk-4.1-0
status: FAILED
```

Install the runtime libraries:

```bash
sudo apt update
sudo apt install libgtk-3-0t64 libwebkit2gtk-4.1-0
```

On older releases use `libgtk-3-0` instead of `libgtk-3-0t64`.

### `error while loading shared libraries: libwebkit2gtk-4.1.so.0`

WebKitGTK is not installed:

```bash
sudo apt install libwebkit2gtk-4.1-0
```

The loader reports the missing library before the app starts. Install it, then
run `avelra doctor` again.

### Node version is too old

The npm launcher requires Node.js 22 or newer:

```bash
node --version
```

Install Node 22 or 24, then retry:

```bash
npm install ./avelra-0.5.0.tgz
npx avelra --version
```

## Running an application

### `GTK initialization failed (is DISPLAY set?)`

Start the app from a graphical session. Check:

```bash
echo "$DISPLAY"
```

On Wayland, a working XWayland session or `GDK_BACKEND=x11` is usually needed.

### The window is missing or white

First check whether the process is alive and the window exists:

```bash
wmctrl -l | grep my-app
```

If the window exists but the content is blank, the likely cause is WebKit's
DMA-BUF/EGL path. The runtime disables DMA-BUF by default. Try:

1. a normal `avelra run`;
2. then `AVELRA_USE_GPU=1 avelra run`.

If both hang, check the VM/remote-session GPU path. Messages such as
`MESA: error: Failed to query drm device` and
`libEGL warning: egl: failed to create dri2 screen` can appear in software mode
without the app failing.

### Loading overlay does not disappear

The overlay hides when the page calls `window.avelra.app.ready()`. If JavaScript fails before
that call, a native fallback hides it after a short timeout.

Check that:

- `client/index.html` and `client/app.js` are present;
- the browser console has no syntax error;
- the app was started from the directory containing `avelra.config.json` and
  `client/`.

Restart `avelra run` after editing client files; no rebuild is needed.

### `static root does not exist: client`

Start the app from its project directory, or pass `--config` pointing to the
configuration:

```bash
avelra --config /path/to/my-app/avelra.config.json run
```

### `cannot start static server on 127.0.0.1: ...`

The runtime could not bind a loopback port. The message after the colon reports
`Address already in use`, `Permission denied` or a resource error. Check open
file descriptors and loopback availability, then retry.

### Page returns 404 or is empty

Check that the requested file exists under `client/` and that the filename case
matches. The client uses a random path token; use relative asset URLs:

```html
<link rel="stylesheet" href="styles.css">
<script src="app.js"></script>
```

An absolute `/app.js` loses the token and returns 404.

### The process stays alive after closing the window

Close the window normally first. If the process remains:

```bash
pkill -f '/avelra$'
```

If it happens repeatedly, report the window manager/session, GPU mode and exact
steps.

## Building and packaging

### `installer --target deb` fails

Install `dpkg-deb`:

```bash
sudo apt install dpkg
```

For AppImage, install `appimagetool` and make sure it is on `PATH`.

### The built app cannot find its client

`avelra build` embeds the client assets. If a hand-built distribution still
expects `client/`, rebuild from the project root:

```bash
avelra build
```

### The application deb does not install

Check dependencies and the package path:

```bash
sudo apt install ./dist/my-app/my-app_0.1.0_amd64.deb
sudo apt --fix-broken install
```

Do not use `dpkg -i` unless you intend to resolve dependencies manually.


## Windows and macOS prerequisites

### Windows: window does not start

Install the Microsoft WebView2 Evergreen Runtime and the Visual C++ 2015–2022
x64 runtime. Run `avelra doctor` from the installed SDK; it reports missing
prerequisites before the GUI starts. The Windows build is unsigned.

### macOS: architecture or version rejected

Avelra 0.5.0 ships x86_64 artifacts only. macOS arm64 is not supported.
`avelra doctor` checks the macOS version, architecture and system WebKit
framework.

## Reporting a problem

Include:

- Avelra version: `avelra --version`;
- `avelra doctor` output;
- distribution and version;
- X11/Wayland/XWayland session;
- GPU mode (`AVELRA_USE_GPU`);
- exact steps and the full error text.

If the problem is specific to the app, include its `avelra.config.json` with
secrets removed and the relevant `client/` files.
