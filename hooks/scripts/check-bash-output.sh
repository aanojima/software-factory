#!/usr/bin/env bash
# PostToolUse hook for the Bash tool.
#
# check-bash-read.sh (PreToolUse) only catches a bare `cat/less/more <file>`.
# A file can be dumped into context many other ways — `python3 - <<EOF ...
# print(open(p).read())`, `sed -n '1,$p'`, `awk '{print}'`, `grep '' file`,
# `cat file | ...`, `node -e`, `jq . file` — and no command-shape filter can
# enumerate them all. This hook closes that gap from the other side: it
# measures the *output*, not the command. Any Bash result over
# BULK_READ_LINE_THRESHOLD lines (default 350, harness/loops.env) trips it,
# whatever produced it.
#
# The content is already in context by the time a PostToolUse hook runs, so
# this cannot block like the PreToolUse guard does. It nudges the model toward
# the bulk-read skill for the next read, the same way check-web-fetch-size.sh
# backstops the WebFetch precheck.
#
# The bulk-reader worker is exempt — it is one-shot and has nowhere to act on
# the nudge.
set -euo pipefail

THRESHOLD=350
LOOPS_ENV="${CLAUDE_PLUGIN_ROOT:-$(cd -P "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}/harness/loops.env"
if [ -f "$LOOPS_ENV" ]; then
  value="$(grep -E '^BULK_READ_LINE_THRESHOLD=' "$LOOPS_ENV" | head -1 | cut -d= -f2 | cut -d' ' -f1)"
  [ -n "$value" ] && THRESHOLD="$value"
fi

input="$(cat)"
agent_type="$(jq -r '.agent_type // empty' <<<"$input")"
[ "$agent_type" = "bulk-reader" ] && exit 0

lines="$(jq -r '
  if (.tool_response|type)=="string" then .tool_response
  elif (.tool_response.stdout|type)=="string" then .tool_response.stdout
  elif (.tool_response.output|type)=="string" then .tool_response.output
  else (.tool_response|tostring)
  end | split("\n") | length
' <<<"$input" 2>/dev/null || echo 0)"

if [ "$lines" -le "$THRESHOLD" ]; then
  exit 0
fi

command="$(jq -r '.tool_input.command // "that command"' <<<"$input" | head -1 | cut -c1-120)"
note="Bash output was $lines lines (over the $THRESHOLD-line bulk-read threshold) from: $command. That output is now sitting in full in this context. Do not read files this way. For the next bulk read, use the bulk-read skill: delegate to the bulk-reader agent with your question and work from the bullets it returns — or bound the output with head/tail and an explicit line count."

jq -n --arg note "$note" '{hookSpecificOutput: {hookEventName: "PostToolUse", additionalContext: $note}}'
exit 0
