#!/usr/bin/env bash
set -euo pipefail
: "${SOFTWARE_FACTORY_HOME:=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
: "${AGENTIC_TARGET:=$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
export SOFTWARE_FACTORY_HOME AGENTIC_TARGET
cd "$AGENTIC_TARGET"

PLAN="${1:?usage: review.sh <plan.md> [git-range] [spec.md] [validation.json]}"
RANGE="${2:-main...HEAD}"; SPEC="${3:-}"; VALIDATION="${4:-}"
SCHEMA="$SOFTWARE_FACTORY_HOME/skills/implement-spec/schemas/review.schema.json"
PROMPT_FILE="$(mktemp)"; OUTPUT_FILE="$(mktemp)"
trap 'rm -f "$PROMPT_FILE" "$OUTPUT_FILE"' EXIT
{
  echo "Independently review this diff against the authoritative goal, approved plan,"
  echo "and validation evidence. Check goal correctness, plan conformance, regressions,"
  echo "maintainability, and risk-specific concerns. Do not block on taste."
  [[ -z "$SPEC" ]] || { echo "--- SPEC ---"; cat "$SPEC"; }
  echo "--- PLAN ---"; cat "$PLAN"
  [[ -z "$VALIDATION" ]] || { echo "--- VALIDATION ---"; cat "$VALIDATION"; }
  echo "--- DIFF ---"; git diff "$RANGE"
} > "$PROMPT_FILE"
codex exec --sandbox read-only --model "${CODEX_REVIEW_MODEL:-gpt-6-astra}" \
  --output-schema "$SCHEMA" \
  --output-last-message "$OUTPUT_FILE" "$(cat "$PROMPT_FILE")"
jq -e '.approved == true or .approved == false' "$OUTPUT_FILE" >/dev/null
cat "$OUTPUT_FILE"
