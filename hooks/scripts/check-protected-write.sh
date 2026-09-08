#!/usr/bin/env bash
# PreToolUse hook for the Edit, Write, MultiEdit, NotebookEdit and Bash tools.
#
# CLAUDE.md rules 2 and 3: never edit files under tasks/done/ or
# eval/golden.jsonl, never modify test files to make tests pass. This hook
# enforces those rules at the tool boundary instead of trusting the prompt.
#
# For Edit/Write the check is exact: the target file_path is matched against
# PROTECTED_WRITE_PATTERNS (harness/loops.env, '|'-separated extended regexes,
# matched against the path relative to the repo root).
#
# For Bash the check is a heuristic on the command text: a protected path
# appearing together with a write-shaped construct (`>`/`>>` redirect, `tee`,
# `sed -i`, `perl -i`, `mv`/`cp`/`rm` to it, `open(...,'w')`, `writeFile`, or a
# heredoc). A shell command can always be rewritten to slip past a regex, so
# the Edit/Write guard is the real gate and this is a speed bump for the
# common cases — the same posture as check-bash-read.sh.
#
# Set SF_ALLOW_PROTECTED_WRITE=1 in the environment to bypass, for the human
# curating tasks/done/ or regenerating the golden set on purpose.
set -euo pipefail

[ "${SF_ALLOW_PROTECTED_WRITE:-}" = "1" ] && exit 0

PATTERNS='^tasks/done/|^eval/golden\.jsonl$|(^|/)tests?/|(^|/)__tests__/|[._-](test|spec)\.[a-z]+$|^test_[^/]+\.py$|(^|/)conftest\.py$'
LOOPS_ENV="${CLAUDE_PLUGIN_ROOT:-$(cd -P "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}/harness/loops.env"
if [ -f "$LOOPS_ENV" ]; then
  value="$(grep -E '^PROTECTED_WRITE_PATTERNS=' "$LOOPS_ENV" | head -1 | cut -d= -f2- | sed -E 's/[[:space:]]+#.*$//; s/^["'"'"']//; s/["'"'"']$//')"
  [ -n "$value" ] && PATTERNS="$value"
fi

input="$(cat)"
tool="$(jq -r '.tool_name // empty' <<<"$input")"
cwd="$(jq -r '.cwd // empty' <<<"$input")"
root="$(git -C "${cwd:-.}" rev-parse --show-toplevel 2>/dev/null || echo "${cwd:-$PWD}")"

relpath() {
  local p="$1"
  case "$p" in
    /*) ;;
    *) p="${cwd:-$PWD}/$p" ;;
  esac
  p="$(python3 -c 'import os,sys;print(os.path.normpath(sys.argv[1]))' "$p" 2>/dev/null || echo "$p")"
  case "$p" in
    "$root"/*) echo "${p#"$root"/}" ;;
    *) echo "$p" ;;
  esac
}

deny() {
  echo "$1 is a protected path (matches PROTECTED_WRITE_PATTERNS). CLAUDE.md forbids editing tasks/done/, eval/golden.jsonl, and test files to make tests pass. If the task genuinely requires this change, stop and report; a human can set SF_ALLOW_PROTECTED_WRITE=1." >&2
  exit 2
}

case "$tool" in
  Edit|Write|MultiEdit|NotebookEdit)
    file_path="$(jq -r '.tool_input.file_path // .tool_input.notebook_path // empty' <<<"$input")"
    [ -z "$file_path" ] && exit 0
    rel="$(relpath "$file_path")"
    if grep -Eq "$PATTERNS" <<<"$rel"; then
      deny "$rel"
    fi
    exit 0
    ;;
  Bash)
    command="$(jq -r '.tool_input.command // empty' <<<"$input")"
    [ -z "$command" ] && exit 0
    # Only bother when the command looks like it writes something.
    if ! grep -Eq '(^|[^<>])>{1,2}[^&]|\btee\b|\bsed\b.*[[:space:]]-[a-zA-Z]*i|\bperl\b.*[[:space:]]-[a-zA-Z]*i|\b(mv|cp|rm|truncate|install)\b|open\([^)]*,[[:space:]]*["'"'"'][wa]|writeFile|write_text|<<-?[[:space:]]*["'"'"']?[A-Za-z_]+' <<<"$command"; then
      exit 0
    fi
    # Pull every path-looking token and test each against the patterns.
    while IFS= read -r tok; do
      [ -z "$tok" ] && continue
      rel="$(relpath "$tok")"
      if grep -Eq "$PATTERNS" <<<"$rel"; then
        deny "$rel"
      fi
    done < <(grep -oE '[A-Za-z0-9_./~-]*[A-Za-z0-9_-]+\.[A-Za-z0-9]+|[A-Za-z0-9_./~-]*/[A-Za-z0-9_./-]*' <<<"$command" | sort -u)
    exit 0
    ;;
esac
exit 0
