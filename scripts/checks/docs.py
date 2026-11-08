#!/usr/bin/env python3
"""Validate Markdown documentation in this repository.

Checks:
- every relative link and image target exists;
- code fences are balanced.

External URLs are ignored. The script has no third-party dependencies.
"""

from __future__ import annotations

import os
import re
import sys

ROOT = os.path.dirname(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
)
SKIP_DIRS = {
    ".git", ".nim_runtime", "build", "dist", "vendor",
    "nimcache", "nimcache-tests", "tasks",
}
LINK_RE = re.compile(r"!?\[[^\]]*\]\(([^)]+)\)")


def markdown_files() -> list[str]:
    found: list[str] = []
    for base, dirs, names in os.walk(ROOT):
        dirs[:] = [d for d in dirs if d not in SKIP_DIRS]
        for name in names:
            if name.endswith(".md"):
                found.append(os.path.join(base, name))
    return sorted(found)


def relative(path: str) -> str:
    return os.path.relpath(path, ROOT)


def main() -> int:
    files = markdown_files()
    errors: list[str] = []

    for path in files:
        in_fence = False
        fences = 0
        with open(path, encoding="utf-8") as handle:
            for lineno, line in enumerate(handle, 1):
                if line.lstrip().startswith("```"):
                    fences += 1
                    in_fence = not in_fence
                    continue
                if in_fence:
                    continue
                for raw_target in LINK_RE.findall(line):
                    target = raw_target.strip().split("#", 1)[0]
                    if not target or target.startswith(
                        ("http://", "https://", "mailto:")
                    ):
                        continue
                    resolved = os.path.normpath(
                        os.path.join(os.path.dirname(path), target)
                    )
                    if not os.path.exists(resolved):
                        errors.append(
                            f"{relative(path)}:{lineno}: missing target {target!r}"
                        )
        if fences % 2:
            errors.append(f"{relative(path)}: unbalanced code fences ({fences})")

    if errors:
        print("Documentation check failed:")
        for error in errors:
            print(f"  {error}")
        return 1

    print(f"Documentation check passed: {len(files)} Markdown files, all links resolve.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
