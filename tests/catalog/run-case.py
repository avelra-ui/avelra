#!/usr/bin/env python3
"""Execute one catalog case and evaluate its assertions."""
from __future__ import annotations
import argparse
import json
import os
import re
import subprocess
import sys
from pathlib import Path
import yaml

ROOT = Path(__file__).resolve().parent
REPO = ROOT.parent.parent


def load(path: Path) -> dict:
    return yaml.safe_load(path.read_text()) or {}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--case", required=True)
    parser.add_argument("--run-plan", required=True)
    args = parser.parse_args()
    catalog = load(ROOT / "catalog.yaml")
    plan = load(Path(args.run_plan))
    case = next((c for c in catalog["cases"] if c["id"] == args.case), None)
    if case is None:
        raise SystemExit(f"unknown case: {args.case}")
    run = next((r for r in plan["runs"] if r["case"] == args.case), None)
    if run is None:
        raise SystemExit(f"no run for {args.case}")
    provider = load(ROOT / "providers" / f"{run['provider']}.yaml")
    platform = case["platforms"][0]
    if platform not in provider["platforms"]:
        print(json.dumps({"schema_version": 1, "case": args.case, "status": "skip",
                          "reason": f"provider lacks platform {platform}"}))
        return 0
    missing = sorted(set(case["requires"]) - set(provider["capabilities"]))
    if missing:
        print(json.dumps({"schema_version": 1, "case": args.case, "status": "skip",
                          "reason": "provider lacks capabilities: " + ", ".join(missing)}))
        return 0
    if case["condition"] != "normal":
        raise SystemExit(f"unsupported condition: {case['condition']}")
    runner = ROOT / "runners" / f"{case['runner']}.py"
    if not runner.is_file():
        raise SystemExit(f"missing runner: {runner}")
    env = os.environ.copy()
    env.setdefault("AVELRA_CLI", str(REPO / "build/bin/avelra"))
    proc = subprocess.run([sys.executable, str(runner)], cwd=REPO, env=env,
                          text=True, capture_output=True, timeout=case["timeout_s"])
    if proc.returncode != 0:
        raise SystemExit(f"runner failed: {proc.returncode}\n{proc.stderr}")
    try:
        obs = json.loads(proc.stdout)
    except json.JSONDecodeError as exc:
        raise SystemExit(f"runner did not return JSON: {exc}\n{proc.stdout}") from exc
    results = []
    for assertion in case["assertions"]:
        kind = assertion["type"]
        ok = False
        actual = None
        if kind == "exit_code":
            actual = obs.get("exit_code")
            ok = actual == assertion["equals"]
        elif kind in ("stdout", "stderr"):
            actual = obs.get(kind, "")
            if "equals" in assertion:
                ok = actual == assertion["equals"]
            elif "contains" in assertion:
                ok = assertion["contains"] in actual
            elif "matches" in assertion:
                value = actual[:-1] if actual.endswith("\n") else actual
                ok = re.search(assertion["matches"], value) is not None
        results.append({"id": assertion["id"], "type": kind,
                        "status": "pass" if ok else "fail", "actual": actual})
    status = "pass" if all(r["status"] == "pass" for r in results) else "fail"
    result = {"schema_version": 1, "case": args.case, "status": status,
              "reason": None if status == "pass" else "assertion failed",
              "provider": run["provider"], "platform": platform,
              "assertions": results}
    print(json.dumps(result, ensure_ascii=False, indent=2))
    return 0 if status == "pass" else 1


if __name__ == "__main__":
    raise SystemExit(main())
