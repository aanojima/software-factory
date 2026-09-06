#!/usr/bin/env bash
set -euo pipefail
: "${SOFTWARE_FACTORY_HOME:=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
: "${AGENTIC_TARGET:=$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
export SOFTWARE_FACTORY_HOME AGENTIC_TARGET
source "$SOFTWARE_FACTORY_HOME/harness/loops.env"
CALLER_EXECUTOR="${AGENTIC_EXECUTOR:-}"
[[ -f "$AGENTIC_TARGET/.software-factory.env" ]] && source "$AGENTIC_TARGET/.software-factory.env"
[[ -z "$CALLER_EXECUTOR" ]] || AGENTIC_EXECUTOR="$CALLER_EXECUTOR"
cd "$AGENTIC_TARGET"

TASK="${1:?usage: dispatch.sh <task>}"
J="$("$SOFTWARE_FACTORY_HOME/harness/triage.sh" "$TASK")"
echo "$J" | jq .
route=$(jq -r .route <<<"$J"); tier=$(jq -r .tier <<<"$J"); risk=$(jq -r .risk <<<"$J")
HOST_RUNTIME="${AGENTIC_EXECUTOR:-claude}"
mkdir -p .claude
printf '%s | %.60s | %s | %s/%s | - | - | - | - | pending\n' \
  "$(date +%F)" "$TASK" "$route" "$tier" "$risk" >> .claude/routing-log.md
if [[ "$risk" == "high" ]]; then
  echo "⚠ risk=high: human plan approval + independent review are mandatory."
  if [[ "$HOST_RUNTIME" == "codex" ]]; then
    echo "→ open Codex and use \$route for the task: explore → plan → fresh native GPT-6 Astra critic at high effort → HUMAN APPROVES; do not run the route before approval"
  else
    echo "→ open Claude and /software-factory:execute the task: explore → plan → native high-effort critic → HUMAN APPROVES; do not run the route before approval"
  fi
  exit 10
fi
case "$route" in
  DIRECT)
    if [[ "$HOST_RUNTIME" == "codex" ]]; then
      echo "→ run in Codex: \$route $TASK"
    else
      echo "→ run in Claude: /software-factory:execute $TASK"
    fi
    ;;
  STANDARD) echo "→ open $HOST_RUNTIME: short plan → implement → native conformance review" ;;
  HEAVY)
    if [[ "$HOST_RUNTIME" == "codex" ]]; then
      echo "→ HEAVY in Codex — use \$route for the task: explore → plan → fresh native GPT-6 Astra critic at high effort → HUMAN APPROVES → implement → native review panel → human signs the diff"
    else
      echo "→ HEAVY in Claude — /software-factory:execute the task: explore → plan → native high-effort critic → HUMAN APPROVES → implement → native review panel → human signs the diff"
    fi
    ;;
  RALPH)    printf '→ write tasks/prd.md + one spec per file in tasks/todo/, then: AGENTIC_EXECUTOR=%q software-factory ralph\n' "$HOST_RUNTIME" ;;
  SWARM)
    if [[ "$HOST_RUNTIME" == "codex" ]]; then
      echo "→ SWARM in Codex requires native agents with separate worktrees; stop if this runtime cannot provide worktree isolation"
    else
      echo "→ decompose to ≤5 scopes, then: claude --worktree <scope> per scope"
    fi
    ;;
  CRON)     echo "→ draft a Routine/Action with done-criteria. No self-looping." ;;
  SPEC)     echo "→ /grill-me until measurable, then re-run dispatch on the PRD" ;;
esac
