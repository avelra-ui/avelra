#!/usr/bin/env python3
"""Collect output of a CLI command; assertions are evaluated by the executor."""
from __future__ import annotations
import json
import os
import subprocess
import sys

def main() -> int:
    cli = os.environ.get("AVELRA_CLI", "build/bin/avelra")
    proc = subprocess.run([cli, "--version"], text=True, capture_output=True)
    print(json.dumps({
        "exit_code": proc.returncode,
        "stdout": proc.stdout,
        "stderr": proc.stderr,
    }))
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
