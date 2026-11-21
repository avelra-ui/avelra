#!/usr/bin/env python3
"""Report case availability across VM/CI profiles from the canonical catalog."""
from __future__ import annotations
import argparse
import json
from collections import Counter
from pathlib import Path
import yaml

ROOT = Path(__file__).resolve().parent.parent.parent


def load(path: Path) -> dict:
    return yaml.safe_load(path.read_text()) or {}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--catalog", default=ROOT / "tests/cases/catalog.yaml")
    parser.add_argument("--profiles", default=ROOT / "tests/cases/profiles")
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args()
    cases = load(Path(args.catalog)).get("cases", [])
    profiles = {p.stem: load(p) for p in sorted(Path(args.profiles).glob("*.yaml"))}
    rows = []
    no_path = []
    for case in cases:
        cid = case.get("id")
        entries = []
        for pid, profile in profiles.items():
            if profile.get("os") not in case.get("platforms", []):
                continue
            env = profile.get("environment")
            if env == "ci" and case.get("environment") not in (None, "ci", "both"):
                continue
            if env == "vm" and case.get("environment") not in (None, "vm", "both"):
                continue
            ex = profile.get("exclusions", {}).get(cid)
            if ex:
                entries.append({"profile": pid, "status": "excluded", "detail": ex})
                continue
            runners = (profile.get("runner") or {}).get("runners", {})
            fixtures = (profile.get("runner") or {}).get("fixtures", {})
            if case.get("fixture"):
                status = "runner" if case["fixture"] in fixtures else "missing"
                detail = case["fixture"]
            elif case.get("runner") in runners:
                status = "runner"
                detail = case["runner"]
            else:
                status = "missing"
                detail = case.get("runner")
            entries.append({"profile": pid, "status": status, "detail": detail})
        if not entries:
            no_path.append(cid)
        rows.append({"id": cid, "level": case.get("level"), "target": case.get("target"),
                     "environment": case.get("environment"), "profiles": entries})
    if args.json:
        print(json.dumps({"cases": rows, "no_profile_path": no_path}, indent=2, ensure_ascii=False))
    else:
        print("id | level | target | env | profiles")
        print("---|---|---|---|---")
        for row in rows:
            p = ", ".join(f"{e['profile']}:{e['status']}" for e in row["profiles"]) or "NONE"
            print(f"{row['id']} | {row['level']} | {row['target']} | {row['environment']} | {p}")
        print("\nby environment:", dict(Counter(x['environment'] for x in rows)))
        print("cases without profile path:", no_path or "none")
    return 1 if no_path else 0


if __name__ == "__main__":
    raise SystemExit(main())
