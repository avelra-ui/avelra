#!/usr/bin/env python3
"""Generate a deterministic release manifest for a staged SDK tree."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import stat
from datetime import datetime, timezone
from pathlib import Path


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--tree", required=True, type=Path)
    parser.add_argument("--version", required=True)
    parser.add_argument("--target", required=True)
    parser.add_argument("--commit", required=True)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()

    files = []
    for path in sorted(args.tree.rglob("*")):
        if path.is_dir():
            continue
        rel = path.relative_to(args.tree).as_posix()
        files.append({
            "path": rel,
            "sha256": sha256(path),
            "size": path.stat().st_size,
            "mode": format(stat.S_IMODE(path.stat().st_mode), "04o"),
        })

    epoch = os.environ.get("SOURCE_DATE_EPOCH")
    built_at = datetime.fromtimestamp(
        int(epoch), tz=timezone.utc
    ) if epoch else datetime.now(timezone.utc)
    manifest = {
        "name": "avelra",
        "version": args.version,
        "target": args.target,
        "commit": args.commit,
        "builtAt": built_at.isoformat().replace("+00:00", "Z"),
        "provenance": {
            "runId": os.environ.get("GITHUB_RUN_ID"),
            "runNumber": os.environ.get("GITHUB_RUN_NUMBER"),
            "workflow": os.environ.get("GITHUB_WORKFLOW"),
            "artifactLabel": os.environ.get("AVELRA_ARTIFACT_LABEL", args.version),
        },
        "protocols": {"native": 1, "extensions": 1},
        "files": files,
    }
    args.output.write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
