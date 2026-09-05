#!/usr/bin/env bash
# Launch one host runtime to orchestrate the portable implement-spec workflow.
set -euo pipefail

: "${SOFTWARE_FACTORY_HOME:=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
: "${AGENTIC_TARGET:=$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
export SOFTWARE_FACTORY_HOME AGENTIC_TARGET

usage() {
  cat <<'EOF'
usage: software-factory implement <spec-file> [options]

options:
  --runtime claude|codex|opencode  host runtime (default: AGENTIC_RUNTIME or claude)
  --headless                       run non-interactively
  --run-id <id>                    stable run directory name
  --run-dir <path>                 resume an existing initialized run
EOF
}

[[ $# -gt 0 ]] || { usage >&2; exit 64; }
SPEC=""; RUNTIME="${AGENTIC_RUNTIME:-claude}"; HEADLESS=0; RUN_ID=""; RUN_DIR=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --runtime) RUNTIME="${2:?--runtime requires a value}"; shift 2 ;;
    --headless) HEADLESS=1; shift ;;
    --run-id) RUN_ID="${2:?--run-id requires a value}"; shift 2 ;;
    --run-dir) RUN_DIR="${2:?--run-dir requires a value}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    --*) echo "unknown option: $1" >&2; usage >&2; exit 64 ;;
    *)
      [[ -z "$SPEC" ]] || { echo "only one spec file may be supplied" >&2; exit 64; }
      SPEC="$1"; shift ;;
  esac
done

cd "$AGENTIC_TARGET"
STATE_TOOL="$SOFTWARE_FACTORY_HOME/skills/implement-spec/scripts/run_state.py"
if [[ -n "$RUN_DIR" ]]; then
  RUN_DIR="$(cd "$RUN_DIR" && pwd)"
  python3 "$STATE_TOOL" status "$RUN_DIR" >/dev/null
  if [[ -z "$SPEC" ]]; then
    SPEC="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["specification"])' "$RUN_DIR/run.json")"
  fi
else
  [[ -n "$SPEC" ]] || { echo "spec file is required for a new run" >&2; exit 64; }
  [[ -f "$SPEC" ]] || { echo "spec file not found: $SPEC" >&2; exit 66; }
  INIT_ARGS=(init --spec "$SPEC" --repo "$AGENTIC_TARGET")
  [[ -z "$RUN_ID" ]] || INIT_ARGS+=(--run-id "$RUN_ID")
  RUN_DIR="$(python3 "$STATE_TOOL" "${INIT_ARGS[@]}")"
fi
SPEC="$(cd "$(dirname "$SPEC")" && pwd)/$(basename "$SPEC")"

read -r -d '' PROMPT <<EOF || true
Use the implement-spec skill to implement the authoritative specification at:
$SPEC

Resume the already initialized run at:
$RUN_DIR

Do not create a second run. The current session is the orchestrator and sole writer. Use native
read-only subagents for bounded exploration and independent review, preserve all run artifacts,
and honor readiness, risk, approval, validation, review, and loop-cap gates.
EOF

command -v "$RUNTIME" >/dev/null 2>&1 || { echo "runtime not found on PATH: $RUNTIME" >&2; exit 69; }
echo "→ runtime=$RUNTIME run=$RUN_DIR" >&2

case "$RUNTIME:$HEADLESS" in
  claude:0)   exec claude "$PROMPT" ;;
  claude:1)   exec claude -p --max-turns "${AGENTIC_MAX_TURNS:-80}" "$PROMPT" ;;
  codex:0)    exec codex --enable multi_agent "$PROMPT" ;;
  codex:1)    exec codex --enable multi_agent exec "$PROMPT" ;;
  opencode:0) exec opencode --prompt "$PROMPT" "$AGENTIC_TARGET" ;;
  opencode:1) exec opencode run "$PROMPT" ;;
  *) echo "unsupported runtime: $RUNTIME" >&2; exit 64 ;;
esac
