#!/usr/bin/env python3
"""Check that ELF binaries do not require a GLIBC newer than allowed."""

from __future__ import annotations

import argparse
import re
import subprocess
import sys
from pathlib import Path

VERSION_RE = re.compile(r"GLIBC_([0-9]+(?:\.[0-9]+)+)")


def parse_version(value: str) -> tuple[int, ...]:
    return tuple(int(part) for part in value.split("."))


def required_versions(path: Path) -> list[str]:
    result = subprocess.run(
        ["readelf", "--version-info", str(path)],
        check=True,
        capture_output=True,
        text=True,
    )
    return sorted(set(VERSION_RE.findall(result.stdout)), key=parse_version)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--max", required=True, help="maximum allowed GLIBC version")
    parser.add_argument("binaries", nargs="+", type=Path)
    args = parser.parse_args()

    allowed = parse_version(args.max)
    failed = False
    for binary in args.binaries:
        if not binary.is_file():
            print(f"missing: {binary}", file=sys.stderr)
            failed = True
            continue
        versions = required_versions(binary)
        maximum = versions[-1] if versions else None
        print(f"{binary}: {maximum or 'no GLIBC symbols'}")
        if maximum is not None and parse_version(maximum) > allowed:
            print(
                f"error: {binary} requires GLIBC_{maximum}, allowed {args.max}",
                file=sys.stderr,
            )
            failed = True
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
