#!/usr/bin/env python3
"""Select catalog cases by suite criteria and execute them."""
from __future__ import annotations
import argparse, json, subprocess, sys
from pathlib import Path
import yaml

ROOT = Path(__file__).resolve().parent
REPO = ROOT.parent.parent


def load(path: Path) -> dict:
    return yaml.safe_load(path.read_text()) or {}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--suite", required=True)
    parser.add_argument("--provider", required=True)
    args = parser.parse_args()
    suite = load(Path(args.suite))
    catalog = load(ROOT / "catalog.yaml")
    provider = load(ROOT / "providers" / f"{args.provider}.yaml")
    platform = provider["platforms"][0]
    techniques = suite.get("techniques")
    cases = [
        c for c in catalog["cases"]
        if c["level"] in suite["levels"]
        and c["target"] in suite["targets"]
        and platform in c["platforms"]
        and (techniques is None or c["technique"] in techniques)
    ]
    if not cases:
        print(f"no cases for suite {suite['id']} on {platform}")
        return 0
    failed = 0
    for case in cases:
        file = REPO / "build" / "test-results" / f"{args.provider}__{case['id']}.json"
        proc = subprocess.run(
            [sys.executable, str(ROOT / "run-case.py"), "--case", case["id"],
             "--provider", args.provider],
            cwd=REPO, text=True, capture_output=True,
        )
        print(proc.stdout, end="")
        if proc.returncode != 0:
            failed += 1
        file.parent.mkdir(parents=True, exist_ok=True)
        file.write_text(proc.stdout)
    print(f"SUITE {suite['id']} platform={platform} cases={len(cases)} failed={failed}")
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
