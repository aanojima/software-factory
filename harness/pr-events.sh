#!/usr/bin/env bash
# pr-events.sh — the ONLY event stream a pr-intake Monitor may consume.
#
# Wraps `gh pr-monitor --json` and prints exactly one JSON line per event the
# watcher should act on. Anything else is dropped here, deterministically, so
# the watching agent is never woken for noise. The agent does not get to
# reinterpret this: it runs this script, not gh-pr-monitor directly.
#
# Dropped (never reach stdout):
#   - empty ticks                 gh-pr-monitor prints nothing; nothing to drop
#   - check events still running  status != COMPLETED and no terminal state —
#                                  queued/in_progress transitions are not signal
#   - mergeable flaps via UNKNOWN GitHub recomputes mergeability after every
#                                  fetch; UNKNOWN<->X is not a real change
#   - deletions/review_request    informational; classifier routes them log-only
#   - stderr                      appended to $RUN_DIR/monitor.stderr
#
# Usage: pr-events.sh <PR> [interval-seconds]
set -euo pipefail
PR="${1:?usage: pr-events.sh <PR number or URL> [interval]}"
INTERVAL="${2:-${PR_WATCH_POLL_INTERVAL_SEC:-60}}"
: "${RUN_DIR:=.agent-runs/pr-watch/$PR}"
mkdir -p "$RUN_DIR"

if ! gh extension list 2>/dev/null | grep -q 'aanojima/gh-pr-monitor'; then
  gh extension install aanojima/gh-pr-monitor >&2
fi

# --unbuffered: jq must flush per line or events sit in its buffer unseen.
gh pr-monitor "$PR" --json --interval "$INTERVAL" 2>>"$RUN_DIR/monitor.stderr" \
  | jq --unbuffered -c '
      select(
        (.type == "check" and (
            .data.status == "COMPLETED"
            or ((.data.state // "") | IN("SUCCESS","FAILURE","ERROR"))
        ))
        or (.type == "mergeable" and
            .data.from.state != "UNKNOWN" and .data.to.state != "UNKNOWN")
        or (.type | IN("comment","inline_comment","review","description"))
      )'
