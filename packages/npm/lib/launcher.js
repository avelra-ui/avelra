"use strict";

const { spawnSync } = require("node:child_process");
const fs = require("node:fs");
const path = require("node:path");

const PLATFORMS = {
  "linux-x64": "linux-x64",
  "win32-x64": "win32-x64",
  "darwin-arm64": "darwin-arm64",
  "darwin-x64": "darwin-x64",
};

function platformKey() {
  const key = `${process.platform}-${process.arch}`;
  return PLATFORMS[key] || null;
}

function run(args) {
  const key = platformKey();
  if (!key) {
    console.error(
      `avelra: unsupported platform ${process.platform}/${process.arch}; ` +
        "supported: linux-x64, win32-x64, darwin-x64, darwin-arm64"
    );
    return 1;
  }

  const root = path.resolve(__dirname, "..", "platform", key);
  const binary = path.join(root, "bin", process.platform === "win32" ? "avelra.exe" : "avelra");
  if (!fs.existsSync(binary)) {
    console.error(`avelra: platform payload is missing: ${binary}`);
    return 1;
  }

  const result = spawnSync(binary, args, {
    stdio: "inherit",
    env: process.env,
  });
  if (result.error) {
    console.error(`avelra: failed to start native CLI: ${result.error.message}`);
    return 1;
  }
  return result.status === null ? 1 : result.status;
}

module.exports = { run, platformKey };
