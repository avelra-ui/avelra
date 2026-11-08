#!/usr/bin/env bash
# Prepare a release, atomically push main + tag, then watch CI.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

VERSION=""
DRY_RUN=1
WAIT=1

usage() {
  cat >&2 <<'USAGE'
usage: scripts/release/release.sh X.Y.Z [--yes] [--no-wait]

Without --yes this is a dry-run: all checks and the plan are shown, but no
files are changed, no commit/tag is created, and nothing is pushed.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --yes) DRY_RUN=0 ;;
    --dry-run) DRY_RUN=1 ;;
    --no-wait) WAIT=0 ;;
    --help|-h) usage; exit 0 ;;
    --*) echo "unknown option: $1" >&2; usage; exit 2 ;;
    *)
      [[ -z "$VERSION" ]] || { echo "version already given" >&2; usage; exit 2; }
      VERSION="$1"
      ;;
  esac
  shift
done

[[ -n "$VERSION" ]] || { usage; exit 2; }
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || {
  echo "version must be semver X.Y.Z: $VERSION" >&2
  exit 2
}

CURRENT="$(cat VERSION)"
if [[ "$(printf '%s\n%s\n' "$CURRENT" "$VERSION" | sort -V | tail -1)" != "$VERSION" ]]; then
  echo "version must not be lower than current VERSION ($CURRENT)" >&2
  exit 1
fi
if [[ ! -f CHANGELOG.md ]]; then
  echo "CHANGELOG.md is missing" >&2
  exit 1
fi
if ! grep -Eq "^## \\[$VERSION\\]" CHANGELOG.md; then
  echo "CHANGELOG.md has no section for $VERSION" >&2
  exit 1
fi

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "not inside a git repository" >&2
  exit 1
fi
BRANCH="$(git branch --show-current)"
if [[ "$BRANCH" != "main" ]]; then
  echo "release must run from main; current branch: $BRANCH" >&2
  exit 1
fi
if [[ -n "$(git status --porcelain)" ]]; then
  echo "working tree is not clean" >&2
  git status --short >&2
  exit 1
fi

TAG="v$VERSION"
if git rev-parse -q --verify "refs/tags/$TAG" >/dev/null; then
  echo "tag already exists locally: $TAG" >&2
  exit 1
fi

git fetch --quiet origin main
if [[ "$(git rev-parse HEAD)" != "$(git rev-parse origin/main)" ]]; then
  echo "local main is not equal to origin/main; push/rebase before release" >&2
  exit 1
fi
if git ls-remote --exit-code --tags origin "refs/tags/$TAG" >/dev/null 2>&1; then
  echo "tag already exists on origin: $TAG" >&2
  exit 1
fi

if command -v gh >/dev/null 2>&1; then
  gh auth status >/dev/null 2>&1 || {
    echo "gh is not authenticated" >&2
    exit 1
  }
  if gh release view "$TAG" >/dev/null 2>&1; then
    echo "GitHub Release already exists: $TAG" >&2
    exit 1
  fi
  BLOCKERS="$(gh issue list --label release-blocker --state open \
    --json number,title --jq '.[] | "#\(.number) \(.title)"')"
  if [[ -n "$BLOCKERS" ]]; then
    echo "open release blockers:" >&2
    printf '%s\n' "$BLOCKERS" >&2
    exit 1
  fi
elif [[ "$DRY_RUN" == 0 ]]; then
  echo "gh is required for --yes" >&2
  exit 1
else
  echo "warning: gh is unavailable; remote tag/release/blocker checks were skipped" >&2
fi

# Run the same local gates as CI before changing anything.
./scripts/build/linux.sh
./tests/run_tests.sh
./scripts/checks/platforms.sh
./scripts/checks/docs.py

cat <<PLAN
release plan
  version:  $VERSION (current $CURRENT)
  tag:      $TAG
  branch:   main
  commit:   $(git rev-parse HEAD)
  mode:     $([[ "$DRY_RUN" == 1 ]] && echo dry-run || echo execute)
  push:     git push --atomic origin main refs/tags/$TAG
PLAN

if [[ "$DRY_RUN" == 1 ]]; then
  echo "dry-run complete; re-run with --yes to execute" >&2
  exit 0
fi

if [[ "$VERSION" != "$CURRENT" ]]; then
  printf '%s\n' "$VERSION" > VERSION
  git add VERSION
  git commit -m "chore(release): $VERSION"
else
  echo "VERSION already equals $VERSION; tagging the current commit"
fi

git tag -a "$TAG" -m "Avelra $VERSION"
git push --atomic origin main "refs/tags/$TAG"

if [[ "$WAIT" == 0 ]]; then
  echo "pushed $TAG; CI continues in GitHub Actions"
  exit 0
fi

if ! command -v gh >/dev/null 2>&1; then
  echo "pushed $TAG; gh is unavailable, check GitHub Actions manually" >&2
  exit 1
fi

# The release workflow is triggered by the tag; find its run by commit.
RUN_ID=""
for _ in $(seq 1 30); do
  RUN_ID="$(gh run list --workflow release.yml --limit 20 \
    --json databaseId,headSha,event \
    --jq ".[] | select(.event == \"push\" and .headSha == \"$(git rev-parse HEAD)\") | .databaseId" \
    | head -1)"
  [[ -n "$RUN_ID" ]] && break
  sleep 3
done
if [[ -z "$RUN_ID" ]]; then
  echo "release workflow run not found; check GitHub Actions" >&2
  exit 1
fi
gh run watch "$RUN_ID" --exit-status
gh release view "$TAG" --json url,assets \
  --jq '"release: \(.url)\nassets: \([.assets[].name] | join(", "))"'
