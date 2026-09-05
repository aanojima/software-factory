#!/usr/bin/env bash
# execute.sh — classify a task, log it, and carry out the matching workstream.
# Auto-runs the safe routes (DIRECT, STANDARD); stops and prints guidance for
# gated / multi-step routes (HEAVY, RALPH, SWARM, CRON, SPEC, or risk=high),
# preserving the doc's "human at the gate" boundary for headless runs.
set -euo pipefail
: "${SOFTWARE_FACTORY_HOME:=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
: "${AGENTIC_TARGET:=$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
export SOFTWARE_FACTORY_HOME AGENTIC_TARGET
source "$SOFTWARE_FACTORY_HOME/harness/loops.env"
[[ -f "$AGENTIC_TARGET/.software-factory.env" ]] && source "$AGENTIC_TARGET/.software-factory.env"
cd "$AGENTIC_TARGET"   # run the executor inside the target repo; state is repo-relative

TASK="${1:?usage: execute.sh <task-string | task-file>}"
[[ -f "$TASK" ]] && TASK="$(cat "$TASK")"
EXECUTOR="${AGENTIC_EXECUTOR:-claude}"   # claude | codex  (override per run)

# 1 · classify (Stage 1, Haiku-priced)
J="$("$SOFTWARE_FACTORY_HOME/harness/triage.sh" "$TASK")"
echo "$J" | jq . >&2
route=$(jq -r .route <<<"$J"); tier=$(jq -r .tier <<<"$J"); risk=$(jq -r .risk <<<"$J")

# 2 · log (v2 schema; fields we can't know yet stay '-')
mkdir -p .claude
printf '%s | %.60s | %s | %s/%s | - | - | - | - | pending\n' \
  "$(date +%F)" "$TASK" "$route" "$tier" "$risk" >> .claude/routing-log.md

# 3 · gate: high risk never auto-runs, regardless of route
if [[ "$risk" == "high" ]]; then
  echo "⚠ risk=high → gated. Human plan approval + cross-model review are mandatory." >&2
  echo "→ run 'software-factory dispatch \"$TASK\"' and follow Mode C by hand." >&2
  exit 10
fi

# 4 · shared instruction: the executor follows the route methodology + hard rules
read -r -d '' PROMPT <<EOF || true
Execute this task through the harness. Classifier decided: route=$route tier=$tier risk=$risk.
Follow the harness routing methodology (the \`route\` skill from the software-factory plugin) for the matching workstream.
Hard rules (CLAUDE.md): never push to main; all merges via PR + CI; never modify
tests to make them pass; when a loop hits its cap, stop and report; for HEAVY or
risk=high, produce the plan and STOP for human approval — do not implement.
Task: $TASK
EOF

run_executor() {  # $1 = model
  case "$EXECUTOR" in
    claude) claude -p "$PROMPT" --model "$1" ;;          # VERIFY flags
    codex)  codex exec "$PROMPT" ;;                       # VERIFY: exec syntax + model flag
    *) echo "unknown AGENTIC_EXECUTOR=$EXECUTOR (want claude|codex)" >&2; exit 64 ;;
  esac
}

# 5 · follow the route
case "$route" in
  DIRECT)   run_executor "$TRIAGE_MODEL" ;;               # trivial → cheapest model
  STANDARD) run_executor "$EXEC_MODEL" ;;                 # normal work → cheap executor
  HEAVY)    echo "→ HEAVY is gated: /grill-me → plan (high effort) → HUMAN APPROVES → implement on $EXEC_MODEL → review.sh ×$REVIEW_LOOP_CAP (both families) → human signs the diff." >&2; exit 10 ;;
  RALPH)    echo "→ RALPH needs specs first: write tasks/prd.md + one spec per file in tasks/todo/, then run 'software-factory ralph'." >&2; exit 11 ;;
  SWARM)    echo "→ SWARM needs decomposition first: split into ≤5 independent scopes, then 'claude --worktree <scope>' per scope." >&2; exit 11 ;;
  CRON)     echo "→ CRON: draft a Routine/Action with an explicit done-criterion. No self-looping." >&2; exit 11 ;;
  SPEC)     echo "→ SPEC: not measurable yet. /grill-me until testable, then re-run execute on the PRD." >&2; exit 11 ;;
  *)        echo "unrecognized route: $route" >&2; exit 65 ;;
esac
