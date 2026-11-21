#!/usr/bin/env python3
"""Run CI catalog cases through the canonical runner adapters."""
from __future__ import annotations
import argparse, json, os, subprocess, sys
from pathlib import Path
import yaml

ROOT = Path(__file__).resolve().parent
REPO = ROOT.parent.parent


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--level", default="component")
    parser.add_argument("--all-inventory", action="store_true")
    args = parser.parse_args()
    catalog = yaml.safe_load((ROOT / "catalog.yaml").read_text())["cases"]
    cases = {c["id"]: c for c in catalog}
    profile = yaml.safe_load((ROOT / "profiles/ci-linux.yaml").read_text())
    runners = profile["runner"]["runners"]
    results = []
    if args.all_inventory:
        inventory = yaml.safe_load((ROOT / "ci-inventory.yaml").read_text())["tests"]
        items = []
        for item in inventory:
            case = cases.get(item.get("case", ""))
            if not case:
                results.append({"id": item["test"], "status": "fail", "reason": "inventory case missing"})
                continue
            if item["test"].endswith(".sh"):
                results.append({"id": case["id"], "status": "skip", "reason": "shell release test is release workflow"})
                continue
            items.append((case, item["test"].removesuffix(".nim")))
    else:
        items = [(c, c.get("test", "").removesuffix(".nim")) for c in catalog
                 if c.get("environment") == "ci" and c.get("level") == args.level]
    for case, ntest in items:
        action = "ci.nimtest" if args.all_inventory else case.get("runner")
        script = ROOT / runners.get(action, "")
        if not script.is_file():
            results.append({"id": case["id"], "status": "fail", "reason": f"runner missing: {action}"})
            continue
        env = os.environ.copy()
        env["AVELRA_CASE"] = case["id"]
        if ntest:
            env["AVELRA_NIMTEST"] = ntest
        env.setdefault("AVELRA_TEST_BIN_DIR", str(REPO / "build/tests/bin"))
        env.setdefault("AVELRA_TEST_BIN", str(REPO / "build/tests/bin"))
        env.setdefault("AVELRA_CLI", str(REPO / "build/bin/avelra"))
        env.setdefault("AVELRA_PACK", str(REPO / "build/libexec/avelra/avelra-pack"))
        env.setdefault("TMPDIR", str(REPO / "build/tests/tmp"))
        proc = subprocess.run([str(script)], cwd=REPO, env=env, text=True, capture_output=True)
        status = "pass" if proc.returncode == 0 else "fail"
        results.append({"id": case["id"], "status": status, "reason": None if status == "pass" else f"exit {proc.returncode}",
                        "output": "\n".join(((proc.stdout or "") + (proc.stderr or "")).splitlines()[-8:])})
    for item in results:
        print(f"{item['id']}: {item['status']}")
        if item.get("reason"):
            print("  " + item["reason"])
            print("  " + item.get("output", "").replace("\n", "\n  "))
    failed = [x for x in results if x["status"] == "fail"]
    skipped = [x for x in results if x["status"] == "skip"]
    print(f"CI_CATALOG cases={len(results)} failed={len(failed)} skipped={len(skipped)}")
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
