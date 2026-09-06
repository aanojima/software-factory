#!/usr/bin/env bash
# status.sh — show a repo's pinned harness version vs the engine, and drift.
set -euo pipefail
: "${SOFTWARE_FACTORY_HOME:=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
: "${AGENTIC_TARGET:=$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
TARGET="${1:-$AGENTIC_TARGET}"; TARGET="$(cd "$TARGET" && pwd)"

ENGINE_VER="$(cat "$SOFTWARE_FACTORY_HOME/VERSION")"
MARKER="$TARGET/.claude/.software-factory-version"
SETTINGS="$TARGET/.claude/settings.json"

echo "engine (this checkout): v$ENGINE_VER  @ $SOFTWARE_FACTORY_HOME"
echo "target repo:            $TARGET"

if [[ ! -f "$MARKER" ]]; then
  echo "status:                NOT INITIALIZED — run the factory-setup skill with 'init'"
  exit 0
fi

REPO_VER="$(head -1 "$MARKER" 2>/dev/null || echo '?')"
REPO_REF="$(awk -F': *' '/^ref:/{print $2; exit}' "$MARKER" 2>/dev/null || echo '?')"
ENABLED="no"
if [[ -f "$SETTINGS" ]] && jq -e '.enabledPlugins["software-factory@software-factory"] == true' "$SETTINGS" >/dev/null 2>&1; then
  ENABLED="yes"
fi

echo "pinned version:         v$REPO_VER   ref: $REPO_REF"
echo "plugin enabled:         $ENABLED (.claude/settings.json)"
if [[ "$REPO_VER" == "$ENGINE_VER" ]]; then
  echo "status:                 up to date"
else
  echo "status:                 BEHIND — engine is v$ENGINE_VER; run the factory-setup skill with 'update' (add --to <ref> to target a release)"
fi
