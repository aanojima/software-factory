#!/usr/bin/env bash
# pr-events.sh — the ONLY event stream a pr-intake Monitor may consume.
#
# Wraps `gh pr-monitor --json` and prints exactly one JSON line per event the
# watcher should act on. Anything else is dropped here, deterministically, so
# the watching agent is never woken for noise. The agent does not get to
# reinterpret this: it runs this script, not gh-pr-monitor directly.
#
# Passed through (one line each, unchanged):
#   comment, inline_comment, review, description
#   mergeable            only when neither side is UNKNOWN (GitHub recomputes
#                        mergeability after every fetch; UNKNOWN<->X is a flap)
#   check                only a *failed* terminal check — wakes immediately
#
# Synthesised:
#   ci_done              one line per head commit, emitted the first time every
#                        check in the rollup is terminal. Successful checks
#                        never wake on their own; they roll up into this line.
#                        data: {sha, conclusion: "success"|"failure", total,
#                        failed: [names]}
#
# Dropped:
#   empty ticks, queued/in-progress check transitions, successful individual
#   checks, deletions, review_request, stderr (-> $RUN_DIR/monitor.stderr)
#
# Usage: pr-events.sh <PR> [interval-seconds]
# Test hook: PR_EVENTS_FILTER_ONLY=1 reads events on stdin instead of running
# gh-pr-monitor, and PR_EVENTS_ROLLUP_CMD replaces the `gh pr view` rollup fetch.
set -euo pipefail
PR="${1:?usage: pr-events.sh <PR number or URL> [interval]}"
INTERVAL="${2:-${PR_WATCH_POLL_INTERVAL_SEC:-60}}"
: "${RUN_DIR:=.agent-runs/pr-watch/$PR}"
mkdir -p "$RUN_DIR"

FAILED_CONCLUSIONS='["FAILURE","ERROR","TIMED_OUT","CANCELLED","ACTION_REQUIRED","STARTUP_FAILURE"]'

fetch_rollup() {
  if [[ -n "${PR_EVENTS_ROLLUP_CMD:-}" ]]; then
    bash -c "$PR_EVENTS_ROLLUP_CMD"
  else
    gh pr view "$PR" --json headRefOid,statusCheckRollup 2>>"$RUN_DIR/monitor.stderr" || echo '{}'
  fi
}

# Emit one ci_done line if every check on the current head is terminal and we
# have not already reported that head.
last_ci_done_sha=""
maybe_ci_done() {
  local rollup sha line
  rollup="$(fetch_rollup)"
  sha="$(jq -r '.headRefOid // ""' <<<"$rollup")"
  [[ -n "$sha" && "$sha" != "$last_ci_done_sha" ]] || return 0
  line="$(jq -c --argjson failed "$FAILED_CONCLUSIONS" '
    (.statusCheckRollup // []) as $c
    | ($c | length) as $n
    | ($c | all(
        (.status? == "COMPLETED")
        or ((.state? // "") | IN("SUCCESS","FAILURE","ERROR"))
      )) as $done
    | select($n > 0 and $done)
    | [ $c[] | select(
          ((.conclusion? // "") | IN($failed[]))
          or ((.state? // "") | IN("FAILURE","ERROR"))
        ) | (.name? // .context? // "unknown") ] as $f
    | {type: "ci_done", time: (now | todate),
       data: {sha: .headRefOid, total: $n, failed: $f,
              conclusion: (if ($f | length) > 0 then "failure" else "success" end)}}
  ' <<<"$rollup")" || return 0
  [[ -n "$line" ]] || return 0
  last_ci_done_sha="$sha"
  printf '%s\n' "$line"
}

filter_events() {
  local ev type verdict
  while IFS= read -r ev; do
    [[ "$ev" == \{* ]] || continue
    type="$(jq -r '.type // ""' <<<"$ev" 2>/dev/null)" || continue
    case "$type" in
      comment|inline_comment|review|description)
        printf '%s\n' "$ev" ;;
      mergeable)
        jq -c 'select(.data.from.state != "UNKNOWN" and .data.to.state != "UNKNOWN")' <<<"$ev" ;;
      check)
        # terminal? failed? — one jq call, three-way verdict
        verdict="$(jq -r --argjson failed "$FAILED_CONCLUSIONS" '
          .data as $d
          | (($d.status? == "COMPLETED") or (($d.state? // "") | IN("SUCCESS","FAILURE","ERROR"))) as $terminal
          | ((($d.conclusion? // "") | IN($failed[])) or (($d.state? // "") | IN("FAILURE","ERROR"))) as $bad
          | if ($terminal | not) then "skip" elif $bad then "fail" else "ok" end' <<<"$ev")"
        case "$verdict" in
          fail) printf '%s\n' "$ev"; maybe_ci_done ;;
          ok)   maybe_ci_done ;;
        esac ;;
    esac
  done
}

if [[ "${PR_EVENTS_FILTER_ONLY:-}" == 1 ]]; then
  filter_events
  exit 0
fi

if ! gh extension list 2>/dev/null | grep -q 'aanojima/gh-pr-monitor'; then
  gh extension install aanojima/gh-pr-monitor >&2
fi

gh pr-monitor "$PR" --json --interval "$INTERVAL" 2>>"$RUN_DIR/monitor.stderr" | filter_events
