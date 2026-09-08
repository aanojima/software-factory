#!/usr/bin/env bash
# PreToolUse hook for the WebFetch tool.
#
# Unlike check-file-size.sh (a free local stat), this has to actually fetch
# to find out the page's size — a HEAD request's Content-Length can't be
# trusted (chunked encoding, compression, dynamic pages routinely omit or
# misstate it). So this curls the real body, but caps the read at
# WEB_FETCH_PRECHECK_READ_CAP bytes: it only needs to know whether the page
# is already past WEB_FETCH_PRECHECK_BYTES, not download the whole thing.
#
# Any failure here (bad URL, timeout, non-http, curl missing) fails OPEN —
# it allows the WebFetch call through rather than guessing. This precheck is
# a best-effort catch for the obvious huge cases; check-web-fetch-size.sh
# (PostToolUse) remains the backstop for whatever slips past it.
#
# Hooks fire for subagent tool calls too (the input carries agent_type when
# the call is coming from inside one), so the web-reader worker itself is
# exempt — otherwise it could never do the fetch it exists to do.
set -euo pipefail

BYTES_THRESHOLD=8000
READ_CAP=50000
TIMEOUT=10
LOOPS_ENV="${CLAUDE_PLUGIN_ROOT:-$(cd -P "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}/harness/loops.env"
if [ -f "$LOOPS_ENV" ]; then
  v="$(grep -E '^WEB_FETCH_PRECHECK_BYTES=' "$LOOPS_ENV" | head -1 | cut -d= -f2 | cut -d' ' -f1)"
  [ -n "$v" ] && BYTES_THRESHOLD="$v"
  v="$(grep -E '^WEB_FETCH_PRECHECK_READ_CAP=' "$LOOPS_ENV" | head -1 | cut -d= -f2 | cut -d' ' -f1)"
  [ -n "$v" ] && READ_CAP="$v"
  v="$(grep -E '^WEB_FETCH_PRECHECK_TIMEOUT_SEC=' "$LOOPS_ENV" | head -1 | cut -d= -f2 | cut -d' ' -f1)"
  [ -n "$v" ] && TIMEOUT="$v"
fi

command -v curl >/dev/null 2>&1 || exit 0

input="$(cat)"
agent_type="$(jq -r '.agent_type // empty' <<<"$input")"
[ "$agent_type" = "web-reader" ] && exit 0

url="$(jq -r '.tool_input.url // empty' <<<"$input")"
[ -z "$url" ] && exit 0

bytes="$( (curl -sL --max-time "$TIMEOUT" "$url" 2>/dev/null || true) | head -c "$READ_CAP" | wc -c)"
[[ "$bytes" =~ ^[0-9]+$ ]] || bytes=0

if [ "$bytes" -lt "$BYTES_THRESHOLD" ]; then
  exit 0
fi

if [ "$bytes" -ge "$READ_CAP" ]; then
  size_note="at least $READ_CAP bytes (stopped reading there)"
else
  size_note="$bytes bytes"
fi

reason="$url is $size_note — over the $BYTES_THRESHOLD-byte bulk-fetch threshold. Do not WebFetch it in full. Use the web-fetch skill: delegate to the web-reader agent with your question, and work from the bullets it returns."

jq -n --arg reason "$reason" '{hookSpecificOutput: {permissionDecision: "deny", permissionDecisionReason: $reason}}'
exit 0
