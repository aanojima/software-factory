#!/usr/bin/env bash
set -euo pipefail
: "${SOFTWARE_FACTORY_HOME:=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
: "${AGENTIC_TARGET:=$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
export SOFTWARE_FACTORY_HOME AGENTIC_TARGET
source "$SOFTWARE_FACTORY_HOME/harness/loops.env"
[[ -f "$AGENTIC_TARGET/.software-factory.env" ]] && source "$AGENTIC_TARGET/.software-factory.env"
cd "$AGENTIC_TARGET"

TASK="${1:?usage: dispatch.sh <task>}"
J="$("$SOFTWARE_FACTORY_HOME/harness/triage.sh" "$TASK")"
echo "$J" | jq .
route=$(jq -r .route <<<"$J"); tier=$(jq -r .tier <<<"$J"); risk=$(jq -r .risk <<<"$J")
mkdir -p .claude
printf '%s | %.60s | %s | %s/%s | - | - | - | - | pending\n' \
  "$(date +%F)" "$TASK" "$route" "$tier" "$risk" >> .claude/routing-log.md
case "$route" in
  DIRECT)   echo "→ run: claude -p \"$TASK — implement, run tests, commit to a branch\" --model $TRIAGE_MODEL" ;;
  STANDARD) echo "→ open Claude Code: plan mode (T2) or one-line plan (T1); implement on $EXEC_MODEL; then harness/review.sh <plan>" ;;
  HEAVY)    echo "→ HEAVY — human gates in force: /grill-me → plan (fable/sol, effort high) → HUMAN APPROVES → implement on $EXEC_MODEL → review.sh ×$REVIEW_LOOP_CAP, both families → human signs the diff" ;;
  RALPH)    echo "→ write tasks/prd.md + one spec per file in tasks/todo/, then: harness/ralph.sh" ;;
  SWARM)    echo "→ decompose to ≤5 scopes, then: claude --worktree <scope> per scope" ;;
  CRON)     echo "→ draft a Routine/Action with done-criteria. No self-looping." ;;
  SPEC)     echo "→ /grill-me until measurable, then re-run dispatch on the PRD" ;;
esac
[[ "$risk" == "high" ]] && echo "⚠ risk=high: human plan approval + cross-model review are mandatory regardless of route."
