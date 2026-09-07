#!/usr/bin/env bash
# PreToolUse hook for the Read tool.
#
# Blocks a full-file Read over BULK_READ_LINE_THRESHOLD lines (default 350,
# set in harness/loops.env) so the file's content never enters the host
# session's context. A targeted read (offset/limit already set) always
# passes through — the model already knows which section it needs.
set -euo pipefail

THRESHOLD=350
LOOPS_ENV="${CLAUDE_PLUGIN_ROOT:-$(cd -P "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}/harness/loops.env"
if [ -f "$LOOPS_ENV" ]; then
  value="$(grep -E '^BULK_READ_LINE_THRESHOLD=' "$LOOPS_ENV" | head -1 | cut -d= -f2 | cut -d' ' -f1)"
  [ -n "$value" ] && THRESHOLD="$value"
fi

input="$(cat)"
file_path="$(jq -r '.tool_input.file_path // empty' <<<"$input")"
offset="$(jq -r '.tool_input.offset // empty' <<<"$input")"
limit="$(jq -r '.tool_input.limit // empty' <<<"$input")"

# Targeted reads are deliberately allowed through.
if [ -n "$offset" ] || [ -n "$limit" ]; then
  exit 0
fi

if [ -z "$file_path" ] || [ ! -f "$file_path" ]; then
  exit 0
fi

lines="$(wc -l < "$file_path" 2>/dev/null || echo 0)"
if [ "$lines" -le "$THRESHOLD" ]; then
  exit 0
fi

reason="$file_path is $lines lines (over the $THRESHOLD-line bulk-read threshold). Do not Read it in full. Use the bulk-read skill: delegate to the bulk-reader agent with your question, and work from the bullets it returns — or re-issue this Read with an offset/limit if you already know the exact section you need."

jq -n --arg reason "$reason" '{hookSpecificOutput: {permissionDecision: "deny", permissionDecisionReason: $reason}}'
exit 0
