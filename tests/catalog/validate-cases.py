#!/usr/bin/env python3
"""Validate the canonical test-case catalog and profile capabilities.

The catalog is the single source of truth for CI and VM adapters. This checker
enforces the model from ADR-0042 without changing test execution.
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

import yaml

LEVELS = {"component", "contract", "integration", "e2e", "acceptance"}
TARGETS = {"sdk", "runtime", "app", "installer", "supply"}
ASPECTS = {"behavior", "presentation", "diagnostics", "security",
           "performance", "compatibility"}
TECHNIQUES = {"functional", "negative", "boundary", "regression"}
CONDITIONS = {"normal", "missing-webkit", "missing-webview2", "missing-vcpp",
              "no-display", "port-busy", "readonly-client"}
ENVIRONMENTS = {"ci", "vm", "both"}
PLATFORMS = {"linux", "windows", "macos"}


def load(path: Path) -> dict:
    if not path.is_file():
        raise SystemExit(f"missing: {path}")
    return yaml.safe_load(path.read_text()) or {}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--catalog", default="tests/cases/catalog.yaml")
    parser.add_argument("--profiles", default="tests/cases/profiles")
    parser.add_argument("--strict", action="store_true",
                        help="treat missing runners/fixtures as errors")
    args = parser.parse_args()
    catalog = load(Path(args.catalog))
    cases = catalog.get("cases", [])
    errors: list[str] = []
    warnings: list[str] = []
    if not isinstance(cases, list):
        errors.append("catalog.cases must be a list")
        cases = []
    seen: set[str] = set()
    for case in cases:
        cid = case.get("id", "<missing>")
        if cid in seen:
            errors.append(f"{cid}: duplicate id")
        if "layer" in case:
            errors.append(f"{cid}: legacy layer field is forbidden; use level/target")
        seen.add(cid)
        for field, allowed in (
            ("level", LEVELS), ("target", TARGETS), ("aspect", ASPECTS),
            ("technique", TECHNIQUES), ("condition", CONDITIONS),
            ("environment", ENVIRONMENTS),
        ):
            value = case.get(field)
            if value not in allowed:
                errors.append(f"{cid}: invalid {field}={value!r}")
        for field in ("title", "runner", "platforms", "requires"):
            if field not in case:
                errors.append(f"{cid}: missing {field}")
        if not isinstance(case.get("platforms"), list) or not case.get("platforms"):
            errors.append(f"{cid}: platforms must be a non-empty list")
        elif not set(case["platforms"]).issubset(PLATFORMS):
            errors.append(f"{cid}: unknown platform(s) {case['platforms']}")
        if not isinstance(case.get("requires"), list):
            errors.append(f"{cid}: requires must be a list")
        if case.get("fixture") and not case.get("runner"):
            warnings.append(f"{cid}: fixture without runner action")

    profiles = {}
    for path in sorted(Path(args.profiles).glob("*.yaml")):
        profile = load(path)
        pid = profile.get("id", path.stem)
        profiles[pid] = profile
        caps = profile.get("capabilities")
        if not isinstance(caps, list) or not caps:
            errors.append(f"profile {pid}: capabilities must be a non-empty list")
            caps = []
        if profile.get("environment") not in (None, "ci", "vm"):
            errors.append(f"profile {pid}: invalid environment")
        for fixture_name, fixture_path in ((profile.get("runner") or {}).get("fixtures") or {}).items():
            fixture_file = Path(__file__).resolve().parent / fixture_path
            if not fixture_file.is_file():
                errors.append(f"profile {pid}: fixture {fixture_name} missing: {fixture_path}")
        runners = (profile.get("runner") or {}).get("runners", {})
        fixtures = (profile.get("runner") or {}).get("fixtures", {})
        exclusions = profile.get("exclusions", {})
        for case in cases:
            if profile.get("environment") != "vm":
                continue
            if case.get("environment") not in (None, "vm", "both"):
                continue
            if profile.get("os") not in case.get("platforms", []):
                continue
            missing_caps = sorted(set(case.get("requires", [])) - set(caps))
            if missing_caps:
                warnings.append(f"{case.get('id')}: profile {pid} lacks {missing_caps}")
            if case.get("id") in exclusions:
                continue
            if case.get("fixture"):
                if case["fixture"] not in fixtures:
                    msg = f"{case.get('id')}: profile {pid} has no fixture {case['fixture']}"
                    (errors if args.strict else warnings).append(msg)
            elif case.get("runner") not in runners:
                msg = f"{case.get('id')}: profile {pid} has no runner {case.get('runner')}"
                (errors if args.strict else warnings).append(msg)

    for item in warnings:
        print(f"WARN {item}")
    for item in errors:
        print(f"ERROR {item}")
    print(f"cases={len(cases)} profiles={len(profiles)} errors={len(errors)} warnings={len(warnings)}")
    return 1 if errors else 0


if __name__ == "__main__":
    raise SystemExit(main())
