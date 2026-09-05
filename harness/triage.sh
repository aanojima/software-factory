#!/usr/bin/env bash
set -euo pipefail
# resolve engine home + target repo (works via bin or when run directly)
: "${SOFTWARE_FACTORY_HOME:=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
: "${AGENTIC_TARGET:=$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
export SOFTWARE_FACTORY_HOME AGENTIC_TARGET
source "$SOFTWARE_FACTORY_HOME/harness/loops.env"
[[ -f "$AGENTIC_TARGET/.software-factory.env" ]] && source "$AGENTIC_TARGET/.software-factory.env"

# prefer the target repo's vendored (version-pinned) asset; fall back to engine
harness_asset() { local p="$AGENTIC_TARGET/$1"; [[ -f "$p" ]] && printf '%s' "$p" || printf '%s' "$SOFTWARE_FACTORY_HOME/$1"; }

IN="${1:?usage: triage.sh <task-string | task-file>}"
[[ -f "$IN" ]] && TASK="$(cat "$IN")" || TASK="$IN"
claude -p "$TASK" \
  --model "$TRIAGE_MODEL" \
  --append-system-prompt "$(cat "$(harness_asset skills/route/classifier.md)")"   # VERIFY flag name
