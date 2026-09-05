#!/usr/bin/env bash
# pr-watch.sh — synchronous CI/review triage for one PR, for runtimes with no
# addressable background agent (Codex, OpenCode). Claude Code's equivalent is
# the `pr-intake` agent (stays alive, messages you live via SendMessage); this
# script has no such channel, so it runs in your terminal until the PR closes,
# a cap is hit, or you kill it — see escalate() for how HEAVY events degrade.
set -euo pipefail
: "${SOFTWARE_FACTORY_HOME:=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
: "${AGENTIC_TARGET:=$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
export SOFTWARE_FACTORY_HOME AGENTIC_TARGET
source "$SOFTWARE_FACTORY_HOME/harness/loops.env"
cd "$AGENTIC_TARGET"

PR="${1:?usage: pr-watch.sh <PR number or URL>}"
CLASSIFIER="$SOFTWARE_FACTORY_HOME/skills/pr-watch/references/pr-classifier.md"
CLASSIFY_SCHEMA="$SOFTWARE_FACTORY_HOME/skills/pr-watch/schemas/classify.schema.json"
REVIEW_SCHEMA="$SOFTWARE_FACTORY_HOME/skills/implement-spec/schemas/review.schema.json"

RUN_DIR=".agent-runs/pr-watch/$PR"
mkdir -p "$RUN_DIR"
STATE="$RUN_DIR/state.json"
LOG="$RUN_DIR/log.md"
AWAITING="$RUN_DIR/awaiting.md"
[[ -f "$STATE" ]] || printf '{"escalations":0,"started_epoch":%s}\n' "$(date -u +%s)" > "$STATE"

if ! gh extension list 2>/dev/null | grep -q 'aanojima/gh-pr-monitor'; then
  echo "→ installing gh extension aanojima/gh-pr-monitor" >&2
  gh extension install aanojima/gh-pr-monitor
fi

echo "→ watching PR $PR — synchronous fallback, runs until closed/capped/killed" >&2
echo "  ponytail: HEAVY events prompt on a tty and log-and-continue off one; no" >&2
echo "  live push channel exists here, upgrade path is a real notification hook" >&2
echo "  (Slack/desktop) if that's worth building later." >&2

gh_reply() {
  local body="$1"
  gh pr comment "$PR" --body "$body"
}

codex_write() {
  local prompt="$1"
  codex exec --sandbox workspace-write "$prompt"
}

classify_event() {
  local event="$1" out="$RUN_DIR/.classify.json"
  local prompt; prompt="$(cat "$CLASSIFIER"; printf '\n--- EVENT ---\n%s\n' "$event")"
  codex exec --sandbox read-only --output-schema "$CLASSIFY_SCHEMA" \
    --output-last-message "$out" "$prompt" >/dev/null
  cat "$out"
}

# HEAVY/risk=high: read-only assessment, then either a live tty decision or a
# logged-and-skipped one — see the module header for why this can't message a
# human the way pr-intake does.
escalate() {
  local event="$1" why="$2" out="$RUN_DIR/.assessment.json"
  local prompt
  prompt="$(cat <<EOF
Independently assess this PR event for a HEAVY/high-risk decision. Check
security, correctness, blast radius, and rollback. Do not write code.
--- WHY FLAGGED ---
$why
--- EVENT ---
$event
EOF
)"
  codex exec --sandbox read-only --model "${CODEX_REVIEW_MODEL:-gpt-6-astra}" \
    --output-schema "$REVIEW_SCHEMA" --output-last-message "$out" "$prompt" >/dev/null
  echo "⚠ HEAVY/high-risk: $why" >&2
  cat "$out" >&2

  local decision="skip"
  if [[ -t 0 ]]; then
    read -r -p "Apply the fix, decline, or skip for now? [apply/decline/skip] " decision
  else
    printf '%s | %s | awaiting_decision (no tty — rerun interactively, or record a decision by editing this file)\n' \
      "$(date -u +%FT%TZ)" "$why" >> "$AWAITING"
  fi
  case "$decision" in
    apply)   codex_write "Apply this fix on PR $PR. $(cat <<<"$event")" ;;
    decline) gh_reply "Declined: $why" ;;
    *)       : ;; # left pending in $AWAITING; not counted as resolved
  esac

  jq '.escalations += 1' "$STATE" > "$STATE.tmp" && mv "$STATE.tmp" "$STATE"
}

handle_event() {
  local event="$1" cls route why
  cls="$(classify_event "$event")"
  route="$(jq -r .route <<<"$cls")"
  why="$(jq -r .why <<<"$cls")"
  printf '%s | %s | %s\n' "$(date -u +%FT%TZ)" "$route" "$why" >> "$LOG"

  case "$route" in
    DIRECT)
      codex_write "Handle this PR event on $PR inline — rerun a known-flaky check, fix a trivial issue, or reply acknowledging it. Commit and push directly if you changed anything. Event: $event"
      ;;
    STANDARD)
      # ponytail: no coderabbit/ponytail-review hook wired into this
      # synchronous path yet — CI and whatever reviewer responds next is the
      # advisory backstop. Add one here if false positives become costly.
      codex_write "Implement a fix for this PR event on $PR. Discover and run the same test command CI runs for this repo — don't guess a different one, capped at $TEST_LOOP_CAP attempts. If, once you've read the diff, the suggestion doesn't actually apply, reply on the thread explaining why instead of forcing a change. Otherwise commit and push. Event: $event"
      ;;
    CONTESTED) gh_reply "$why" ;;
    SPEC)      gh_reply "Can you make this a concrete, testable ask? ($why)" ;;
    HEAVY)     escalate "$event" "$why" ;;
  esac
}

gh pr-monitor "$PR" --json --interval "$PR_WATCH_POLL_INTERVAL_SEC" | while IFS= read -r event; do
  [[ -n "$event" ]] || continue
  handle_event "$event"

  escalations="$(jq -r .escalations "$STATE")"
  started_epoch="$(jq -r .started_epoch "$STATE")"
  elapsed_min=$(( ($(date -u +%s) - started_epoch) / 60 ))
  if (( escalations >= PR_WATCH_LOOP_CAP )); then
    echo "→ PR_WATCH_LOOP_CAP ($PR_WATCH_LOOP_CAP) reached — stopping" >&2
    break
  fi
  if (( elapsed_min >= PR_WATCH_TIMEOUT_MIN )); then
    echo "→ PR_WATCH_TIMEOUT_MIN (${PR_WATCH_TIMEOUT_MIN}m) reached — stopping" >&2
    break
  fi
done

FINAL="$(gh pr view "$PR" --json state,mergedAt 2>/dev/null || echo '{}')"
echo "→ pr-watch ending for PR $PR: $FINAL" >&2
printf '%s | final | %s\n' "$(date -u +%FT%TZ)" "$FINAL" >> "$LOG"
