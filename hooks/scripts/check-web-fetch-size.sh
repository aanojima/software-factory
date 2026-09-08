#!/usr/bin/env bash
# PostToolUse hook for the WebFetch tool.
#
# A page's size can't be known before it's fetched, so this can't gate the
# call the way check-file-size.sh gates Read — the content is already in
# context by the time this runs. Instead it nudges the model toward the
# web-fetch skill's cheap worker on its *next* fetch, over
# WEB_FETCH_CHAR_THRESHOLD characters (default 8000, harness/loops.env).
#
# Hooks fire for subagent tool calls too (the input carries agent_type when
# the call is coming from inside one); the web-reader worker itself is
# exempt from the nudge — it's one-shot and has nowhere to act on it.
set -euo pipefail

THRESHOLD=8000
LOOPS_ENV="${CLAUDE_PLUGIN_ROOT:-$(cd -P "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}/harness/loops.env"
if [ -f "$LOOPS_ENV" ]; then
  value="$(grep -E '^WEB_FETCH_CHAR_THRESHOLD=' "$LOOPS_ENV" | head -1 | cut -d= -f2 | cut -d' ' -f1)"
  [ -n "$value" ] && THRESHOLD="$value"
fi

input="$(cat)"
agent_type="$(jq -r '.agent_type // empty' <<<"$input")"
[ "$agent_type" = "web-reader" ] && exit 0

url="$(jq -r '.tool_input.url // "that URL"' <<<"$input")"
chars="$(jq -r '
  if (.tool_response|type)=="string" then .tool_response
  elif (.tool_response.content|type)=="string" then .tool_response.content
  else (.tool_response|tostring)
  end | length
' <<<"$input" 2>/dev/null || echo 0)"

if [ "$chars" -le "$THRESHOLD" ]; then
  exit 0
fi

note="$url returned $chars characters (over the $THRESHOLD-character threshold). That page is now sitting in full in this context. Next time you expect a page this size, or a follow-up fetch of the same page, use the web-fetch skill's web-reader worker instead so only the answer comes back, not the whole page."

jq -n --arg note "$note" '{hookSpecificOutput: {hookEventName: "PostToolUse", additionalContext: $note}}'
exit 0
