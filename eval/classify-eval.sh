#!/usr/bin/env bash
# eval/classify-eval.sh — route accuracy over the golden set
set -euo pipefail
: "${SOFTWARE_FACTORY_HOME:=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
: "${AGENTIC_TARGET:=$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
export SOFTWARE_FACTORY_HOME AGENTIC_TARGET
cd "$AGENTIC_TARGET"
# prefer the target repo's golden set; fall back to the engine's seed
GOLDEN="$AGENTIC_TARGET/eval/golden.jsonl"; [[ -f "$GOLDEN" ]] || GOLDEN="$SOFTWARE_FACTORY_HOME/eval/golden.jsonl"

total=0; hit=0
while IFS= read -r line; do
  task=$(jq -r .task <<<"$line"); want=$(jq -r .route <<<"$line")
  for run in 1 2 3; do
    got=$("$SOFTWARE_FACTORY_HOME/harness/triage.sh" "$task" | jq -r .route 2>/dev/null || echo PARSE_FAIL)
    total=$((total+1)); [[ "$got" == "$want" ]] && hit=$((hit+1)) \
      || echo "MISS: '$task' want=$want got=$got"
  done
done < "$GOLDEN"
echo "route accuracy: $hit/$total"
