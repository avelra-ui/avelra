#!/usr/bin/env python3
"""Assemble a Windows or macOS release tree and archive.

The build step is platform-native; this script only stages the already built
binaries, writes the release manifest/checksums and creates the portable
archive. NSIS/DMG packaging runs after this step.
"""

from __future__ import annotations

import argparse
import hashlib
import shutil
import subprocess
import sys
import tempfile
import tarfile
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
TARGETS = {
    "windows-x64": {"suffix": ".exe", "archive": "zip"},
    "macos-arm64": {"suffix": "", "archive": "tar.gz"},
    "macos-x64": {"suffix": "", "archive": "tar.gz"},
}


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def require(path: Path) -> None:
    if not path.is_file():
        raise SystemExit(f"missing built file: {path}")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--target", required=True, choices=sorted(TARGETS))
    parser.add_argument("--version", default=(ROOT / "VERSION").read_text().strip())
    parser.add_argument("--build-dir", type=Path, default=ROOT / "build")
    parser.add_argument("--releases-dir", type=Path, default=ROOT / "build/releases")
    parser.add_argument("--commit", default="unknown")
    parser.add_argument("--artifact-label")
    args = parser.parse_args()

    label = args.artifact_label or args.version
    spec = TARGETS[args.target]
    suffix = spec["suffix"]
    build = args.build_dir
    bin_dir = build / "bin"
    libexec = build / "libexec/avelra"
    share = build / "share/avelra"
    required = [
        bin_dir / f"avelra{suffix}",
        libexec / f"avelra-runtime{suffix}",
        libexec / f"avelra-pack{suffix}",
    ]
    for path in required:
        require(path)
    if not (share / "templates/app/client/index.html").is_file():
        raise SystemExit("missing app template")

    final = args.releases_dir / args.version / args.target
    if final.exists():
        raise SystemExit(f"release already exists: {final}")
    final.parent.mkdir(parents=True, exist_ok=True)
    stage = Path(tempfile.mkdtemp(prefix=".stage.", dir=final.parent))
    try:
        tree = stage / "tree"
        (tree / "bin").mkdir(parents=True)
        (tree / "libexec").mkdir()
        (tree / "share/doc/avelra").mkdir(parents=True)
        shutil.copy2(bin_dir / f"avelra{suffix}", tree / "bin" / f"avelra{suffix}")
        shutil.copytree(libexec, tree / "libexec/avelra")
        shutil.copytree(share, tree / "share/avelra")
        shutil.copy2(ROOT / "LICENSE", tree / "share/doc/avelra/LICENSE")
        for path in [
            tree / "bin" / f"avelra{suffix}",
            tree / "libexec/avelra" / f"avelra-runtime{suffix}",
            tree / "libexec/avelra" / f"avelra-pack{suffix}",
        ]:
            path.chmod(0o755)

        manifest = stage / "manifest.json"
        subprocess.run(
            [
                sys.executable, str(ROOT / "scripts/release/manifest.py"),
                "--tree", str(tree),
                "--version", args.version,
                "--target", args.target,
                "--commit", args.commit,
                "--output", str(manifest),
            ],
            check=True,
        )

        artifacts = stage / "artifacts"
        artifacts.mkdir()
        name = f"avelra-{label}-{args.target}"
        if spec["archive"] == "zip":
            with zipfile.ZipFile(artifacts / f"{name}.zip", "w", zipfile.ZIP_DEFLATED) as zf:
                for path in sorted(tree.rglob("*")):
                    if path.is_file():
                        zf.write(path, f"{name}/{path.relative_to(tree).as_posix()}")
        else:
            with tarfile.open(artifacts / f"{name}.tar.gz", "w:gz") as tf:
                tf.add(tree, arcname=name)

        sums = stage / "SHA256SUMS"
        entries = [manifest] + sorted(artifacts.iterdir())
        sums.write_text(
            "".join(f"{sha256(path)}  {path.name}\n" for path in entries),
            encoding="utf-8",
        )
        shutil.move(str(stage), final)
    except Exception:
        shutil.rmtree(stage, ignore_errors=True)
        raise
    print(final)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
