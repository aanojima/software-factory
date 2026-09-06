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
CALLER_EXECUTOR="${AGENTIC_EXECUTOR:-}"
[[ -f "$AGENTIC_TARGET/.software-factory.env" ]] && source "$AGENTIC_TARGET/.software-factory.env"
[[ -z "$CALLER_EXECUTOR" ]] || AGENTIC_EXECUTOR="$CALLER_EXECUTOR"
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
  echo "⚠ risk=high → gated. Human plan approval + independent review are mandatory." >&2
  printf '→ run: AGENTIC_EXECUTOR=%q software-factory dispatch %q and follow Mode C by hand.\n' \
    "$EXECUTOR" "$TASK" >&2
  exit 10
fi

# 4 · shared instruction: the executor follows the route methodology + hard rules
read -r -d '' PROMPT <<EOF || true
Execute this task through the harness. Classifier decided: route=$route tier=$tier risk=$risk.
Follow the harness routing methodology (the \`route\` skill from the software-factory plugin) for the matching workstream.
Hard rules (CLAUDE.md): never push to main; all merges via PR + CI; never modify
tests to make them pass; when a loop hits its cap, stop and report; for HEAVY or
risk=high, produce the plan, obtain native plan review, and STOP for human
approval — do not implement.
Task: $TASK
EOF

run_executor() {  # $1 = model
  case "$EXECUTOR" in
    claude) claude -p "$PROMPT" --model "$1" ;;          # VERIFY flags
    codex)  codex --enable multi_agent exec "$PROMPT" ;;
    *) echo "unknown AGENTIC_EXECUTOR=$EXECUTOR (want claude|codex)" >&2; exit 64 ;;
  esac
}

# 5 · follow the route
case "$route" in
  DIRECT)   run_executor "$TRIAGE_MODEL" ;;               # trivial → cheapest model
  STANDARD) run_executor "$EXEC_MODEL" ;;                 # normal work → cheap executor
  HEAVY)    echo "→ HEAVY is gated: explore → plan → native plan critic → HUMAN APPROVES → implement → native review panel → human signs the diff." >&2; exit 10 ;;
  RALPH)    printf '→ RALPH needs specs first; then run: AGENTIC_EXECUTOR=%q software-factory ralph\n' "$EXECUTOR" >&2; exit 11 ;;
  SWARM)
    if [[ "$EXECUTOR" == "codex" ]]; then
      echo "→ SWARM in Codex requires native agents with separate worktrees; stop if this runtime cannot provide worktree isolation." >&2
    else
      echo "→ SWARM needs decomposition first: split into ≤5 independent scopes, then 'claude --worktree <scope>' per scope." >&2
    fi
    exit 11
    ;;
  CRON)     echo "→ CRON: draft a Routine/Action with an explicit done-criterion. No self-looping." >&2; exit 11 ;;
  SPEC)     echo "→ SPEC: not measurable yet. /grill-me until testable, then re-run execute on the PRD." >&2; exit 11 ;;
  *)        echo "unrecognized route: $route" >&2; exit 65 ;;
esac
