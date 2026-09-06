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

LAST_FAIL=""
EXECUTOR="${AGENTIC_EXECUTOR:-claude}"
for i in $(seq 1 "$RALPH_MAX_ITER"); do
  NEXT="$(ls tasks/todo/*.md 2>/dev/null | head -1 || true)"
  [[ -z "$NEXT" ]] && echo "✅ all tasks done" && exit 0
  echo "── iteration $i · $NEXT"
  PROMPT="Complete exactly this ONE task, then stop: $(cat "$NEXT").
Run the test suite. If green: git commit and 'mv $NEXT tasks/done/'.
Do not modify test files. Do not touch other tasks."
  set +e
  case "$EXECUTOR" in
    claude) OUT="$(claude -p "$PROMPT" --model "$EXEC_MODEL")" ;;
    codex) OUT="$(codex exec --sandbox workspace-write --model "$CODEX_EXEC_MODEL" "$PROMPT")" ;;
    *) echo "unknown AGENTIC_EXECUTOR=$EXECUTOR (want claude|codex)" >&2; exit 64 ;;
  esac
                                              # sandbox this loop (container or throwaway
  RC=$?                                  # user) before granting write permissions
  set -e
  if [[ $RC -ne 0 ]]; then
    SIG="$(echo "$OUT" | tail -5 | md5sum | cut -d' ' -f1)"
    [[ "$SIG" == "$LAST_FAIL" ]] && echo "⛔ identical failure twice → spec defect. Fix $NEXT, rerun." && exit 2
    LAST_FAIL="$SIG"
  fi
done
echo "⛔ hit RALPH_MAX_ITER=$RALPH_MAX_ITER — review tasks/ and the log before restarting"; exit 3
