# Getting started

This guide takes you from a clean Linux system to a running Avelra application.
It targets the **0.4.2 public preview**.

Avelra applications build with the prebuilt SDK. Nim is only needed when
working on the runtime itself.

## Requirements

- Linux x86_64;
- GTK 3.24 or newer;
- WebKitGTK 4.1;
- glibc 2.35 or newer for the release binaries.

Verified distributions:

- Ubuntu 22.04, 24.04, 26.04;
- Debian 12, 13.

Other glibc-based x64 distributions can use the portable tar artifact; their
compatibility validation continues alongside the verified targets. Native RPM
packaging for Fedora/RHEL is planned.

On Debian/Ubuntu, install the runtime libraries if they are missing:

```bash
sudo apt update
sudo apt install libgtk-3-0t64 libwebkit2gtk-4.1-0
```

Older Debian/Ubuntu releases may use the package name `libgtk-3-0` instead of
`libgtk-3-0t64`.

## Install the SDK

Choose one of the release artifacts. All examples use version `0.4.2`; replace
it with the version you downloaded.

### deb

```bash
sudo apt install ./avelra_0.4.2_amd64.deb
avelra --version
```

`apt` resolves GTK and WebKitGTK dependencies.

### Portable tar

```bash
tar -xzf avelra-sdk-0.4.2-linux-x64.tar.gz
export PATH="$PWD/avelra-sdk-0.4.2-linux-x64/bin:$PATH"
avelra --version
```

The tar layout is:

```text
avelra-sdk-0.4.2-linux-x64/
  bin/avelra
  libexec/avelra/avelra-runtime
  libexec/avelra/avelra-pack
  libexec/avelra/avelra-installer
  share/avelra/templates/app/
```

You run `avelra`; the `libexec` tools are internal.

### npm tarball

The npm package is published with the 0.4.2 release. Install it from the release
tarball until the registry package is available, then use the registry package.

Requirements: **Node.js 22 or newer**.

```bash
npm install ./avelra-0.4.2.tgz
npx avelra --version
```


## Windows SDK preview

The Windows SDK is distributed as a per-user NSIS installer for Windows 10
22H2 and Windows 11. It does not require administrator rights.

1. Download `avelra-sdk-<version>-windows-x64-setup.exe`.
2. Run the installer and keep the default location:
   ```text
   %LOCALAPPDATA%\Avelra
   ```
3. Verify the CLI:
   ```powershell
   & "$env:LOCALAPPDATA\Avelra\bin\avelra.exe" --version
   & "$env:LOCALAPPDATA\Avelra\bin\avelra.exe" doctor
   ```

The installer adds an **Avelra SDK** entry to Windows Settings → Apps. Use that
entry, or `%LOCALAPPDATA%\Avelra\uninstall.exe`, to uninstall. Uninstall
removes the SDK payload, the Start Menu shortcut, the Apps entry and the install
directory.

> The 0.4.2 public Windows build predates the Apps entry and full install-root
> cleanup. This behavior is part of the next Windows SDK build.

## Verify the installation

```bash
avelra doctor
```

Expected output on a complete Linux system:

```text
Avelra runtime dependencies (Linux)
  GTK 3: OK
  WebKitGTK 4.1: OK
status: OK
```

If WebKit is missing, `doctor` prints the package hint and exits non-zero.

## Create your first application

```bash
avelra init my-app
cd my-app
```

`init` creates:

```text
my-app/
  avelra.config.json
  client/
    index.html
    app.js
    styles.css
  icon.png
```

Start the development runtime:

```bash
avelra run
```

The starter window contains a working health card. It should report `ok` for
`config`, `client-assets`, `static-server` and `extensions`.

## Build and install the application

Build a single executable:

```bash
avelra build
```

The output is written under `dist/<app>/`. The executable embeds the client
assets, configuration and icon, so the built app runs from one file.

Build an application installer:

```bash
avelra installer --target deb
```

Supported targets are `tar`, `deb` and `appimage`. The `deb` target requires
`dpkg-deb` and a `maintainer` value in `avelra.config.json`; AppImage requires
`appimagetool`.

Install the generated application deb:

```bash
sudo apt install ./dist/my-app/my-app_0.1.0_amd64.deb
```

The application then appears in the desktop menu and can be launched from there.

## GPU rendering

By default, the runtime disables the WebKit DMA-BUF renderer to avoid hangs on
systems without a working DRM/EGL device:

```text
WEBKIT_DISABLE_DMABUF_RENDERER=1
```

If your GPU path is healthy, you can test hardware rendering:

```bash
AVELRA_USE_GPU=1 avelra run
```

On some VMs, remote sessions and containers this can hang before the first
frame. Use the default mode there.

## Local server

The runtime starts one local HTTP server on `127.0.0.1` with a random port and a
random path token. It serves the `client/` assets only. Native calls use the
WebView bridge, not HTTP or WebSocket.

To confirm the listener while the app is running:

```bash
ss -ltnp | grep avelra-runtime
```

The listener disappears when the window closes.

## Next steps

- [Using Avelra](usage.md) — project configuration, CLI, native API and
  packaging.
- [Troubleshooting](troubleshooting.md) — dependency, display and port issues.
