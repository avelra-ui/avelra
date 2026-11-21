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
    args = parser.parse_args()
    catalog = yaml.safe_load((ROOT / "catalog.yaml").read_text())["cases"]
    profile = yaml.safe_load((ROOT / "profiles/ci-linux.yaml").read_text())
    runners = profile["runner"]["runners"]
    results = []
    for case in catalog:
        if case.get("environment") != "ci" or case.get("level") != args.level:
            continue
        action = case.get("runner")
        script = ROOT / runners.get(action, "")
        if not script.is_file():
            results.append({"id": case["id"], "status": "fail", "reason": f"runner missing: {action}"})
            continue
        env = os.environ.copy()
        env["AVELRA_CASE"] = case["id"]
        if case.get("test"):
            env["AVELRA_NIMTEST"] = case["test"].removesuffix(".nim")
        env.setdefault("AVELRA_TEST_BIN_DIR", str(REPO / "build/tests/bin"))
        env.setdefault("AVELRA_CLI", str(REPO / "build/bin/avelra"))
        env.setdefault("AVELRA_PACK", str(REPO / "build/libexec/avelra/avelra-pack"))
        proc = subprocess.run([str(script)], cwd=ROOT, env=env, text=True, capture_output=True)
        status = "pass" if proc.returncode == 0 else "fail"
        results.append({"id": case["id"], "status": status, "reason": None if status == "pass" else f"exit {proc.returncode}",
                        "output": "\n".join(((proc.stdout or "") + (proc.stderr or "")).splitlines()[-8:])})
    for item in results:
        print(f"{item['id']}: {item['status']}")
        if item.get("reason"):
            print("  " + item["reason"])
            print("  " + item.get("output", "").replace("\n", "\n  "))
    failed = [x for x in results if x["status"] != "pass"]
    print(f"CI_CATALOG cases={len(results)} failed={len(failed)}")
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
