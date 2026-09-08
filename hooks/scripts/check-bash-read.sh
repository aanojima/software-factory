#!/usr/bin/env bash
# PreToolUse hook for the Bash tool.
#
# Blocks cat/less/more of a single file over BULK_READ_LINE_THRESHOLD lines —
# these dump the whole file into context just like a full Read does. head and
# tail are left alone: they already bound their own output.
#
# Hooks fire for subagent tool calls too (the input carries agent_type when
# the call is coming from inside one), so the bulk-reader worker itself is
# exempt — otherwise it could never do the read it exists to do.
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

command="$(jq -r '.tool_input.command // empty' <<<"$input")"
[ -z "$command" ] && exit 0

# Only look at a bare `cat`/`less`/`more <file>` invocation — anything piped,
# redirected, or combined with other flags is left to the model's judgment.
read -r verb rest <<<"$command"
case "$verb" in
  cat|less|more) ;;
  *) exit 0 ;;
esac

file_path="$(echo "$rest" | awk '{print $NF}')"
[ -z "$file_path" ] || [ ! -f "$file_path" ] && exit 0

lines="$(wc -l < "$file_path" 2>/dev/null || echo 0)"
if [ "$lines" -le "$THRESHOLD" ]; then
  exit 0
fi

reason="$file_path is $lines lines (over the $THRESHOLD-line bulk-read threshold). Do not dump it with $verb. Use the bulk-read skill: delegate to the bulk-reader agent with your question, and work from the bullets it returns — or use head/tail with an explicit line count if you already know the exact section you need."

echo "$reason" >&2
exit 2
