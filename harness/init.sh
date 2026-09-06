#!/usr/bin/env bash
# init.sh — wire a target repo to the software-factory plugin and shared state.
#   • Claude Code → committed .claude/settings.json enables the plugin from the
#     marketplace (loads in cloud sessions at startup).
#   • Codex       → the user-installed plugin supplies skills; AGENTS.md carries
#     project rules.
#   • OpenCode    → optional repo-local compatibility files via --opencode.
#
#   factory-setup init   [target-dir]   # wire plugin + rules + seed state
#   factory-setup update [target-dir]   # refresh managed files + re-pin (keep state)
#
# State (routing-log, tasks/, golden set) is created only when absent, never
# clobbered.
set -euo pipefail

MODE="${1:?usage: init.sh <init|update> [--to <ref>] [--opencode] [target-dir]}"; shift || true
: "${SOFTWARE_FACTORY_HOME:=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

# args: optional --to <ref> (target release) and a positional target dir
TO_REF=""; OPENCODE=0; POS=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --to) TO_REF="${2:?--to needs a ref}"; shift 2 ;;
    --opencode) OPENCODE=1; shift ;;
    *)    POS+=("$1"); shift ;;
  esac
done
TARGET="${POS[0]:-${AGENTIC_TARGET:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}}"
TARGET="$(cd -P "$TARGET" && pwd)"
SRC="$SOFTWARE_FACTORY_HOME"
VERSION="$(cat "$SRC/VERSION")"
. "$SRC/harness/legacy-links.sh"

# marketplace coordinates (override for a fork)
MKT_REPO="${AGENTIC_MARKETPLACE_REPO:-aanojima/software-factory}"
MKT_NAME="${AGENTIC_MARKETPLACE_NAME:-software-factory}"
PLUGIN_NAME="${AGENTIC_PLUGIN_NAME:-software-factory}"
MKT_REF="${TO_REF:-${AGENTIC_MARKETPLACE_REF:-main}}"  # safe default until a release tag exists; --to vX.Y.Z or env overrides
ENABLE_KEY="${PLUGIN_NAME}@${MKT_NAME}"

# read the existing version marker so we can report the transition
MARKER="$TARGET/.claude/.software-factory-version"
LEGACY_MARKER="$TARGET/.claude/.agentic-harness-version"
OLD_VER="(none)"; OLD_REF="(none)"; MIGRATE_LEGACY=0
LEGACY_MARKER_RECOGNIZED=0

# A marker authorizes cleanup only when it matches the exact five-line shape
# emitted by a generated installer. User-created files with a familiar first
# line are evidence to preserve, not migration authority.
marker_is_recognized() {
  local marker="$1" plugin="$2" version_pattern="$3"
  [[ -f "$marker" && ! -L "$marker" ]] || return 1
  awk -v plugin="$plugin" -v version_pattern="$version_pattern" '
    NR == 1 {
      if ($0 !~ version_pattern) bad=1
      next
    }
    NR == 2 {
      if ($0 != plugin) bad=1
      next
    }
    NR == 3 {
      if ($0 !~ /^ref:[[:space:]]+[^[:space:]].*$/) bad=1
      next
    }
    NR == 4 {
      if ($0 !~ /^stamped:[[:space:]]+[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]$/) bad=1
      next
    }
    NR == 5 {
      if ($0 !~ /^engine:[[:space:]]+(unknown|[0-9A-Fa-f]+)$/) {
        bad=1
      } else {
        value=$0
        sub(/^engine:[[:space:]]+/, "", value)
        if (value != "unknown" && (length(value) < 7 || length(value) > 40)) bad=1
      }
      next
    }
    { bad=1 }
    END { exit !(NR == 5 && !bad) }
  ' "$marker"
}

legacy_marker_is_recognized() {
  marker_is_recognized "$1" \
    'plugin:  agentic-harness@agentic-harness' \
    '^(0\\.(0|1)\\.[0-9]+|0\\.2\\.0)$'
}

current_marker_is_recognized() {
  marker_is_recognized "$1" \
    'plugin:  software-factory@software-factory' \
    '^[0-9]+\\.[0-9]+\\.[0-9]+$'
}

if [[ -e "$MARKER" || -L "$MARKER" ]]; then
  if ! current_marker_is_recognized "$MARKER"; then
    echo "refusing unknown or modified current marker: $MARKER" >&2
    exit 73
  fi
  OLD_VER="$(head -1 "$MARKER" 2>/dev/null || echo '?')"
  OLD_REF="$(awk -F': *' '/^ref:/{print $2; exit}' "$MARKER" 2>/dev/null || echo '?')"
  case "$OLD_VER" in 0.0.*|0.1.*|0.2.0) MIGRATE_LEGACY=1 ;; esac
fi
if [[ -e "$LEGACY_MARKER" || -L "$LEGACY_MARKER" ]]; then
  if [[ -f "$LEGACY_MARKER" ]]; then
    legacy_old_ver="$(head -1 "$LEGACY_MARKER" 2>/dev/null || echo '?')"
    legacy_old_ref="$(awk -F': *' '/^ref:/{print $2; exit}' "$LEGACY_MARKER" 2>/dev/null || echo '?')"
  else
    legacy_old_ver="?"
    legacy_old_ref="?"
  fi
  if legacy_marker_is_recognized "$LEGACY_MARKER"; then
    LEGACY_MARKER_RECOGNIZED=1
    if [[ ! -f "$MARKER" ]]; then
      MIGRATE_LEGACY=1
      OLD_VER="$legacy_old_ver"
      OLD_REF="$legacy_old_ref"
    fi
  else
    echo "  = preserved unknown or modified legacy marker: $LEGACY_MARKER" >&2
  fi
fi

echo "→ $MODE software-factory v$VERSION into $TARGET" >&2
echo "  plugin: $ENABLE_KEY  marketplace: github:$MKT_REPO@$MKT_REF" >&2

BEGIN_MARK='<!-- >>> software-factory (managed block — refresh with `factory-setup update`) -->'
LEGACY_BEGIN_MARK='<!-- >>> software-factory (managed block — refresh with `software-factory update`) -->'
FIRST_BEGIN_MARK='<!-- >>> agentic-harness (managed block — refresh with `agentic-harness update`) -->'
END_MARK='<!-- <<< software-factory -->'
FIRST_END_MARK='<!-- <<< agentic-harness -->'

read -r -d '' RULES_BODY <<'EOF' || true
## Agentic harness — project rules
1. One task per conversation. Route new tasks through `/software-factory:execute`
   (Claude Code), `$route` (Codex), or `software-factory execute "<task>"`.
   Execute an approved specification through `/software-factory:implement-spec`
   (Claude), `$implement-spec` (Codex/OpenCode), or
   `software-factory implement <spec> --runtime <host>`.
   To stop at a staged commit instead of opening a PR, use `stage-ticket`
   (same command style, any runtime).
2. Never edit files under `tasks/done/` or `eval/golden.jsonl`.
3. Never modify test files to make tests pass.
4. All merges go through PR + CI. Never push to main.
5. When a loop hits its cap, stop and report — do not improvise past it.

The routing methodology (classify → announce → log → follow) is the `route`
skill from the plugin. Gates: **HEAVY** or **risk=high** → produce the plan, obtain native
plan review, and STOP for human approval; do not implement. Codex uses a fresh
native GPT-6 Astra plan critic at high effort and Claude uses a high-effort
native plan critic.

The host owns scope, plan, risk, gates, integration, and the final response.
Exactly one native implementation worker owns writes and repairs; reviewers are
inspection-only. Claude uses the plugin-bundled `implementation-worker`, while
Codex uses its built-in worker. Use native subagents from the current host. An
external CLI bridge is only for a user-requested mixed Claude + Codex review. A
native launch failure stops or retries within the applicable cap; it never
silently changes providers.
EOF

# Replace a generated file without ever replacing a symlink in the target repo.
# A symlink is safe only when its resolved target is an existing regular file;
# dangling links, directories, and loops fail before the link is touched.
safe_replace() {
  local file="$1" tmp="$2" target="$1" link_target
  local hops=0
  local mode=""
  if [[ -L "$file" ]]; then
    while [[ -L "$target" ]]; do
      if (( hops >= 40 )); then
        rm -f "$tmp"
        echo "refusing to update symlink loop: $file" >&2
        return 73
      fi
      hops=$((hops + 1))
      if ! link_target="$(readlink "$target")"; then
        rm -f "$tmp"
        echo "refusing to read symlink: $file" >&2
        return 73
      fi
      [[ "$link_target" = /* ]] || link_target="$(dirname "$target")/$link_target"
      target="$link_target"
    done
    if [[ ! -f "$target" ]]; then
      rm -f "$tmp"
      echo "refusing to replace symlink with missing or non-file target: $file" >&2
      return 73
    fi
    if stat -c '%a' "$target" >/dev/null 2>&1; then mode="$(stat -c '%a' "$target")"; else mode="$(stat -f '%Lp' "$target")"; fi
    chmod "$mode" "$tmp"
    mv "$tmp" "$target"
    return
  fi
  if [[ -e "$file" && ! -f "$file" ]]; then
    rm -f "$tmp"
    echo "refusing to replace non-file target: $file" >&2
    return 73
  fi
  if [[ -f "$file" ]]; then
    if stat -c '%a' "$file" >/dev/null 2>&1; then mode="$(stat -c '%a' "$file")"; else mode="$(stat -f '%Lp' "$file")"; fi
    chmod "$mode" "$tmp"
  fi
  mv "$tmp" "$file"
}

validate_markdown_blocks() {
  local file="$1"
  [[ -f "$file" ]] || return 0
  awk -v a0="$FIRST_BEGIN_MARK" -v a1="$FIRST_END_MARK" \
      -v s0="$BEGIN_MARK" -v s1="$LEGACY_BEGIN_MARK" -v e0="$END_MARK" '
    BEGIN { state=""; na=0; ns=0; bad=0 }
    index($0, "<!-- >>> agentic-harness") > 0 && $0 != a0 { bad=1; next }
    index($0, "<!-- >>> software-factory") > 0 && $0 != s0 && $0 != s1 { bad=1; next }
    index($0, "<!-- <<< agentic-harness") > 0 && $0 != a1 { bad=1; next }
    index($0, "<!-- <<< software-factory") > 0 && $0 != e0 { bad=1; next }
    $0 == a0 { if (state != "" || na++) bad=1; else state="a"; next }
    $0 == s0 || $0 == s1 { if (state != "" || ns++) bad=1; else state="s"; next }
    $0 == a1 { if (state != "a") bad=1; else state=""; next }
    $0 == e0 { if (state != "s") bad=1; else state=""; next }
    { }
    END { if (bad || state != "") exit 2 }
  ' "$file"
}

validate_codex_blocks() {
  local file="$1"
  [[ -f "$file" ]] || return 0
  awk '
    BEGIN { state=""; na=0; ns=0; bad=0 }
    index($0, "# >>> agentic-harness implement-spec agents") > 0 && $0 != "# >>> agentic-harness implement-spec agents" { bad=1; next }
    index($0, "# >>> software-factory implement-spec agents") > 0 && $0 != "# >>> software-factory implement-spec agents" { bad=1; next }
    index($0, "# <<< agentic-harness implement-spec agents") > 0 && $0 != "# <<< agentic-harness implement-spec agents" { bad=1; next }
    index($0, "# <<< software-factory implement-spec agents") > 0 && $0 != "# <<< software-factory implement-spec agents" { bad=1; next }
    $0 == "# >>> agentic-harness implement-spec agents" { if (state != "" || na++) bad=1; else state="a"; next }
    $0 == "# >>> software-factory implement-spec agents" { if (state != "" || ns++) bad=1; else state="s"; next }
    $0 == "# <<< agentic-harness implement-spec agents" { if (state != "a") bad=1; else state=""; next }
    $0 == "# <<< software-factory implement-spec agents" { if (state != "s") bad=1; else state=""; next }
    { if (state == "") next }
    END { if (bad || state != "") exit 2 }
  ' "$file"
}

# Existing managed destinations must resolve to regular files before any
# settings, rules, or migration cleanup can touch the target. A symlink to a
# regular file is allowed so safe_replace can update the resolved file while
# preserving the link itself.
validate_managed_destination() {
  local file="$1" resolved
  if [[ ! -e "$file" && ! -L "$file" ]]; then
    return 0
  fi
  if [[ -L "$file" ]]; then
    if ! resolved="$(legacy_canonical_dangling_leaf "$file" 2>/dev/null)" || [[ ! -f "$resolved" ]]; then
      echo "refusing unsafe managed symlink: $file" >&2
      return 73
    fi
    return 0
  fi
  if [[ ! -f "$file" ]]; then
    echo "refusing non-file managed destination: $file" >&2
    return 73
  fi
}

# Resolve the nearest existing ancestor of a destination and require that it
# is a directory canonically below the target repo. This prevents mkdir/cp
# from following an external, dangling, looping, or non-directory ancestor.
validate_directory_ancestor() {
  local path="$1" label="${2:-destination}" ancestor canonical
  case "$path" in
    "$TARGET"|"$TARGET"/*) ;;
    *)
      echo "refusing $label destination outside target: $path" >&2
      return 73
      ;;
  esac
  if legacy_path_has_symlink_ancestor "$path" 1 "$TARGET"; then
    echo "refusing $label destination through symlink ancestor: $path" >&2
    return 73
  fi
  ancestor="$path"
  while [[ ! -e "$ancestor" && ! -L "$ancestor" ]]; do
    if [[ "$ancestor" == "/" ]]; then
      echo "refusing missing $label destination ancestor: $path" >&2
      return 73
    fi
    ancestor="$(dirname "$ancestor")"
  done
  if ! canonical="$(legacy_canonical_dangling_leaf "$ancestor" 2>/dev/null)" ||
     [[ ! -d "$canonical" ]]; then
    echo "refusing unsafe $label destination ancestor: $path" >&2
    return 73
  fi
  case "$canonical" in
    "$TARGET"|"$TARGET"/*) ;;
    *)
      echo "refusing external $label destination ancestor: $path" >&2
      return 73
      ;;
  esac
}

# These destinations are written directly later in the run, so reject
# symlinks and other unsafe path types before any optional OpenCode cleanup.
validate_local_file_destination() {
  local file="$1"
  if [[ -L "$file" ]]; then
    echo "refusing symlink destination: $file" >&2
    return 73
  fi
  if [[ -e "$file" && ! -f "$file" ]]; then
    echo "refusing non-file destination: $file" >&2
    return 73
  fi
}

# A recognized legacy migration may remove files listed in the manifest. Walk
# every manifest leaf's parent without resolving any component: an intermediate
# symlink could redirect hashing or removal outside the target, even when it
# resolves back inside the repository. Missing parents are harmless because a
# missing leaf is skipped by the cleanup below; any present unsafe component is
# rejected before settings or legacy files are changed.
preflight_legacy_manifest_ancestors() {
  [[ "$MIGRATE_LEGACY" -eq 1 ]] || return 0
  local manifest_file="$SRC/harness/legacy-managed.sha256"
  local rel manifest_rel component current parent_rel
  local -a components
  if [[ ! -f "$manifest_file" || -L "$manifest_file" ]]; then
    echo "refusing legacy migration without a regular managed-file manifest: $manifest_file" >&2
    return 73
  fi
  while IFS= read -r rel; do
    [[ -z "$rel" || "$rel" == \#* ]] && continue
    manifest_rel="$rel"
    case "$manifest_rel" in
      /*|*//*|*/)
        echo "refusing unsafe legacy manifest path: $manifest_rel" >&2
        return 73
        ;;
    esac
    IFS='/' read -r -a components <<< "$manifest_rel"
    for component in "${components[@]}"; do
      case "$component" in
        ''|.|..)
          echo "refusing unsafe legacy manifest path: $manifest_rel" >&2
          return 73
          ;;
      esac
    done
    [[ "$manifest_rel" == */* ]] || continue
    parent_rel="${manifest_rel%/*}"
    IFS='/' read -r -a components <<< "$parent_rel"
    current="$TARGET"
    for component in "${components[@]}"; do
      current="$current/$component"
      if [[ -L "$current" ]]; then
        echo "refusing legacy migration through symlink ancestor: $current" >&2
        return 73
      fi
      if [[ -e "$current" && ! -d "$current" ]]; then
        echo "refusing legacy migration through non-directory ancestor: $current" >&2
        return 73
      fi
    done
  done < <(awk -F '\t' '!seen[$1]++ && $1 !~ /^#/ && $1 != "" {print $1}' "$manifest_file")
}

# Validate every managed input before settings, rules, or migration cleanup can
# mutate the target. Both historical blocks may appear once, in either order.
for managed_file in "$TARGET/AGENTS.md" "$TARGET/CLAUDE.md" "$TARGET/.claude/settings.json"; do
  if ! validate_managed_destination "$managed_file"; then
    exit 73
  fi
  if ! validate_directory_ancestor "$(dirname "$managed_file")" "managed"; then
    exit 73
  fi
done
if ! validate_directory_ancestor "$TARGET" "managed"; then
  exit 73
fi
for rules_file in "$TARGET/AGENTS.md" "$TARGET/CLAUDE.md"; do
  if ! validate_markdown_blocks "$rules_file"; then
    echo "refusing to update malformed managed block: $rules_file" >&2
    exit 73
  fi
done
if [[ -f "$TARGET/.codex/config.toml" ]] && grep -Eq '(# (>>>|<<<) (agentic-harness|software-factory) implement-spec agents)' "$TARGET/.codex/config.toml"; then
  if ! validate_codex_blocks "$TARGET/.codex/config.toml"; then
    echo "refusing to update malformed legacy Codex registrations: $TARGET/.codex/config.toml" >&2
    exit 73
  fi
fi
if [[ "$OPENCODE" -eq 1 ]]; then
  for opencode_dir in \
    "$TARGET/.agents/skills/implement-spec" \
    "$TARGET/.agents/skills/stage-ticket" \
    "$TARGET/.opencode/agents" \
    "$TARGET/.opencode/commands" \
    "$TARGET/.opencode/software-factory"; do
    if ! validate_directory_ancestor "$opencode_dir" "OpenCode"; then
      exit 73
    fi
  done
fi
if ! preflight_legacy_manifest_ancestors; then
  exit 73
fi
if ! validate_local_file_destination "$TARGET/.gitignore"; then
  exit 73
fi

# splice the managed block into a markdown file, preserving surrounding content
stamp_block() {
  local file="$1"
  local block; block="$(printf '%s\n%s\n%s' "$BEGIN_MARK" "$RULES_BODY" "$END_MARK")"
  local placeholder='__SOFTWARE_FACTORY_MANAGED_BLOCK__'
  local block_file filtered tmp managed=0 marker
  mkdir -p "$(dirname "$file")"
  if [[ -L "$file" && ! -f "$file" ]]; then
    echo "refusing to update dangling or non-file symlink: $file" >&2
    return 73
  fi
  while [[ -f "$file" ]] && grep -qxF "$placeholder" "$file"; do
    placeholder="${placeholder}_"
  done

  block_file="$(mktemp "$(dirname "$file")/.software-factory-block.XXXXXX")"
  filtered="$(mktemp "$(dirname "$file")/.software-factory-filter.XXXXXX")"
  tmp="$(mktemp "$(dirname "$file")/.software-factory-write.XXXXXX")"
  printf '%s\n' "$block" > "$block_file"

  if [[ -f "$file" ]]; then
    for marker in "$BEGIN_MARK" "$LEGACY_BEGIN_MARK" "$FIRST_BEGIN_MARK"; do
      if grep -qF "$marker" "$file"; then
        managed=1
        break
      fi
    done
  fi

  if [[ "$managed" -eq 1 ]]; then
    if ! awk \
      -v b0="$BEGIN_MARK" -v b1="$LEGACY_BEGIN_MARK" -v b2="$FIRST_BEGIN_MARK" \
      -v e0="$END_MARK" -v e1="$FIRST_END_MARK" -v p="$placeholder" '
      function is_begin(line) { return line == b0 || line == b1 || line == b2 }
      function is_end(line) { return line == e0 || line == e1 }
      {
        if (skipping) {
          if (is_end($0)) skipping = 0
          next
        }
        if (is_begin($0)) {
          if (!inserted) { print p; inserted = 1 }
          skipping = 1
          next
        }
        print
      }
      END {
        if (skipping) exit 2
        if (!inserted) print p
      }
    ' "$file" > "$filtered"; then
      rm -f "$block_file" "$filtered" "$tmp"
      echo "refusing to refresh malformed managed block: $file" >&2
      return 73
    fi
  else
    if [[ -f "$file" ]]; then
      cat "$file" > "$filtered"
      [[ ! -s "$file" ]] || printf '\n' >> "$filtered"
    fi
    printf '%s\n' "$placeholder" >> "$filtered"
  fi

  if ! awk -v p="$placeholder" -v block_file="$block_file" '
    $0 == p {
      while ((getline line < block_file) > 0) print line
      close(block_file)
      next
    }
    { print }
  ' "$filtered" > "$tmp"; then
    rm -f "$block_file" "$filtered" "$tmp"
    return 73
  fi
  rm -f "$block_file" "$filtered"
  if ! safe_replace "$file" "$tmp"; then
    rm -f "$tmp"
    return 73
  fi
  if [[ "$managed" -eq 1 ]]; then
    echo "  ~ managed block refreshed: ${file#"$TARGET"/}" >&2
  else
    echo "  + managed block added: ${file#"$TARGET"/}" >&2
  fi
}

# create a state file only if it does not already exist (never clobber)
seed_state() {
  local rel="$1" src="$2"
  if [[ -e "$TARGET/$rel" ]]; then echo "  = kept existing $rel" >&2; return; fi
  mkdir -p "$(dirname "$TARGET/$rel")"; cp "$src" "$TARGET/$rel"; echo "  + $rel" >&2
}

refresh_managed_file() {
  local src="$1" dest="$2" rel="$3" hash source_hash canonical target_hash mode tmp
  if ! validate_directory_ancestor "$(dirname "$dest")" "OpenCode"; then
    return 73
  fi
  if [[ ! -e "$dest" && ! -L "$dest" ]]; then
    if ! mkdir -p "$(dirname "$dest")"; then
      echo "  ! failed to create OpenCode destination directory for $rel" >&2
      return 73
    fi
    if ! cp "$src" "$dest"; then
      echo "  ! failed to copy packaged OpenCode file $rel" >&2
      return 73
    fi
    return 0
  fi
  if [[ -L "$dest" ]]; then
    if ! canonical="$(legacy_canonical_dangling_leaf "$dest" 2>/dev/null)"; then
      echo "  ! refusing dangling or looping OpenCode symlink $rel" >&2
      return 73
    fi
    if [[ ! -f "$canonical" ]]; then
      echo "  ! refusing symlink to non-file $rel" >&2
      return 73
    fi
    case "$canonical" in
      "$TARGET"/*) ;;
      *)
        echo "  ! refusing external OpenCode symlink $rel" >&2
        return 73
        ;;
    esac
    target_hash="$(legacy_sha256_file "$canonical" 2>/dev/null || true)"
    if cmp -s "$src" "$canonical"; then
      echo "  = preserved symlink $rel" >&2
      return 0
    fi
    if [[ -n "$target_hash" ]] && awk -F '\t' -v p="$rel" -v h="$target_hash" \
      '$1 == p && $2 == h {ok=1} END {exit !ok}' \
      "$SRC/harness/legacy-managed.sha256"; then
      if stat -c '%a' "$canonical" >/dev/null 2>&1; then
        mode="$(stat -c '%a' "$canonical")"
      elif stat -f '%Lp' "$canonical" >/dev/null 2>&1; then
        mode="$(stat -f '%Lp' "$canonical")"
      else
        echo "  ! refusing to read mode for historical OpenCode symlink target $rel" >&2
        return 73
      fi
      if ! tmp="$(mktemp "$(dirname "$canonical")/.software-factory-opencode.XXXXXX")"; then
        echo "  ! failed to create replacement for historical OpenCode symlink target $rel" >&2
        return 73
      fi
      if ! cp "$src" "$tmp"; then
        rm -f -- "$tmp"
        echo "  ! failed to copy packaged OpenCode file $rel" >&2
        return 73
      fi
      if ! chmod "$mode" "$tmp"; then
        rm -f -- "$tmp"
        echo "  ! failed to preserve mode for historical OpenCode symlink target $rel" >&2
        return 73
      fi
      if ! mv "$tmp" "$canonical"; then
        rm -f -- "$tmp"
        echo "  ! failed to atomically refresh historical OpenCode symlink target $rel" >&2
        return 73
      fi
      echo "  ~ refreshed historical OpenCode symlink target $rel" >&2
      return 0
    fi
    echo "  ! refusing stale OpenCode symlink $rel" >&2
    return 1
  fi
  if [[ ! -f "$dest" ]]; then
    echo "  ! refusing non-file $rel" >&2
    return 73
  fi
  hash="$(legacy_sha256_file "$dest" 2>/dev/null || true)"
  source_hash="$(legacy_sha256_file "$src" 2>/dev/null || true)"
  if [[ -n "$hash" && "$hash" == "$source_hash" ]] || {
    [[ -n "$hash" ]] && awk -F '\t' -v p="$rel" -v h="$hash" \
      '$1 == p && $2 == h {ok=1} END {exit !ok}' \
      "$SRC/harness/legacy-managed.sha256"
  }; then
    if ! cp "$src" "$dest"; then
      echo "  ! failed to refresh packaged OpenCode file $rel" >&2
      return 73
    fi
    return 0
  else
    echo "  ! preserved modified or unknown OpenCode file $rel" >&2
    return 1
  fi
}

refresh_managed_tree() {
  local src_root="$1" dest_root="$2" prefix="$3" src rel failed=0
  while IFS= read -r -d '' src; do
    rel="$prefix/${src#"$src_root"/}"
    if ! refresh_managed_file "$src" "$dest_root/${src#"$src_root"/}" "$rel"; then
      failed=1
    fi
  done < <(find "$src_root" -type f -print0)
  return "$failed"
}

cleanup_global_opencode_legacy() {
  local name path expected
  [[ -n "${HOME:-}" ]] || return 0
  for name in goal-explorer goal-reviewer goal-security-reviewer repo-explorer \
    conformance-reviewer security-reviewer adversarial-reviewer implementation-worker; do
    path="$HOME/.config/opencode/agents/$name.md"
    [[ -L "$path" ]] || continue
    expected="adapters/opencode/agents/$name.md"
    if legacy_path_has_symlink_ancestor "$path" 0 "$HOME"; then
      echo "  = preserved legacy OpenCode link with symlink ancestor $path" >&2
    elif legacy_link_matches_checkout_path "$path" "$expected"; then
      rm -f -- "$path"
      echo "  - removed legacy OpenCode link $path" >&2
    else
      echo "  = preserved unknown OpenCode link $path" >&2
    fi
  done
  for name in route implement-spec stage-ticket pr-watch; do
    path="$HOME/.config/opencode/commands/$name.md"
    [[ -L "$path" ]] || continue
    expected="adapters/opencode/commands/$name.md"
    if legacy_path_has_symlink_ancestor "$path" 0 "$HOME"; then
      echo "  = preserved legacy OpenCode link with symlink ancestor $path" >&2
    elif legacy_link_matches_checkout_path "$path" "$expected"; then
      rm -f -- "$path"
      echo "  - removed legacy OpenCode link $path" >&2
    else
      echo "  = preserved unknown OpenCode link $path" >&2
    fi
  done
}

# Remove files written by pre-0.2.1 installs while preserving unrelated config.
remove_legacy_kit() {
  [[ "$MIGRATE_LEGACY" -eq 1 ]] || return 0
  local file="$TARGET/.codex/config.toml"
  local tmp
  if [[ -f "$file" ]] && grep -Eq '(# (>>>|<<<) (agentic-harness|software-factory) implement-spec agents)' "$file"; then
    if legacy_path_has_symlink_ancestor "$file" 0 "$TARGET"; then
      echo "  = preserved legacy Codex config with symlink ancestor: $file" >&2
    else
      tmp="$(mktemp "$(dirname "$file")/.software-factory-codex.XXXXXX")"
      if ! validate_codex_blocks "$file"; then
        rm -f "$tmp"
        echo "refusing to remove malformed legacy Codex registrations: $file" >&2
        return 73
      fi
      awk '
        /^# >>> (agentic-harness|software-factory) implement-spec agents$/ { skip=1; next }
        /^# <<< (agentic-harness|software-factory) implement-spec agents$/ { skip=0; next }
        { if (!skip) print }
      ' "$file" > "$tmp"
      if ! safe_replace "$file" "$tmp"; then
        rm -f "$tmp"
        return 73
      fi
      echo "  - removed legacy Codex checkout registrations" >&2
    fi
  fi
  local manifest_file="$SRC/harness/legacy-managed.sha256"
  local rel hash source actual actual_hash remove
  while IFS= read -r rel; do
    [[ -z "$rel" || "$rel" == \#* ]] && continue
    actual="$TARGET/$rel"
    [[ -e "$actual" || -L "$actual" ]] || continue
    remove=0
    if [[ -L "$actual" ]]; then
      while IFS=$'\t' read -r hash source; do
        [[ -n "$source" && "$source" == *:* ]] || continue
        if legacy_link_matches_checkout_path "$actual" "${source#*:}"; then
          remove=1
          break
        fi
      done < <(awk -F '\t' -v p="$rel" '$1 == p {print $2 "\t" $3}' "$manifest_file")
      if [[ "$remove" -eq 1 ]]; then
        rm -f -- "$actual"
        echo "  - removed legacy link $rel" >&2
      else
        echo "  = preserved unknown legacy link $rel" >&2
      fi
    elif [[ -f "$actual" ]]; then
      actual_hash="$(legacy_sha256_file "$actual" 2>/dev/null || true)"
      if [[ -n "$actual_hash" ]]; then
        while IFS=$'\t' read -r hash source; do
          [[ -n "$hash" && "$actual_hash" == "$hash" ]] || continue
          remove=1
          break
        done < <(awk -F '\t' -v p="$rel" '$1 == p {print $2 "\t" $3}' "$manifest_file")
      fi
      if [[ "$remove" -eq 1 ]]; then
        rm -f -- "$actual"
        echo "  - removed legacy asset $rel" >&2
      elif [[ -n "$actual_hash" ]]; then
        echo "  = preserved modified or unknown legacy asset $rel" >&2
      else
        echo "  = preserved unverifiable legacy asset $rel" >&2
      fi
    else
      echo "  = preserved non-file legacy path $rel" >&2
    fi
  done < <(awk -F '\t' '!seen[$1]++ && $1 !~ /^#/ && $1 != "" {print $1}' "$manifest_file")
  for rel in .codex/prompts .codex/agents .codex .agents/skills/implement-spec .agents/skills/stage-ticket .agents/skills .agents .opencode/agents .opencode/commands .opencode/software-factory .opencode; do
    rmdir "$TARGET/$rel" 2>/dev/null || true
  done
  if [[ "$LEGACY_MARKER_RECOGNIZED" -eq 1 ]]; then
    rm -f -- "$LEGACY_MARKER"
    echo "  - removed recognized legacy marker" >&2
  fi
  echo "  - removed legacy checkout-based runtime files" >&2
}

stamp_gitignore() {
  local file="$TARGET/.gitignore" entry='.agent-runs/'
  touch "$file"
  if ! grep -qxF "$entry" "$file"; then
    [[ ! -s "$file" ]] || printf '\n' >> "$file"
    printf '# Local agent execution artifacts\n%s\n' "$entry" >> "$file"
    echo "  + .gitignore ($entry)" >&2
  fi
}

# --- 1 · Claude layer: enable the plugin via committed settings (loads in cloud) ---
mkdir -p "$TARGET/.claude"
SETTINGS="$TARGET/.claude/settings.json"
existing='{}'; [[ -f "$SETTINGS" ]] && existing="$(cat "$SETTINGS")"
if [[ "$MIGRATE_LEGACY" -eq 1 ]]; then
  existing="$(jq '
    def official_legacy_marketplace:
      if . == {source: {source: "github", repo: "aanojima/agentic-harness"}} then
        true
      elif type == "object" then
        if (keys != ["source"] or (.source | type) != "object") then
          false
        elif (.source | keys) != ["ref", "repo", "source"] then
          false
        elif .source.source != "github" or .source.repo != "aanojima/agentic-harness" then
          false
        elif (.source.ref | type) != "string" then
          false
        else (.source.ref | length) > 0
        end
      else false
      end;
    if (.extraKnownMarketplaces["agentic-harness"] | official_legacy_marketplace) then
      del(.extraKnownMarketplaces["agentic-harness"])
    else . end
    | if .enabledPlugins["agentic-harness@agentic-harness"] == true then
        del(.enabledPlugins["agentic-harness@agentic-harness"])
      else . end
  ' <<<"$existing")"
fi
SETTINGS_TMP="$(mktemp "$(dirname "$SETTINGS")/.software-factory-settings.XXXXXX")"
if ! jq \
  --arg mkt "$MKT_NAME" --arg repo "$MKT_REPO" --arg ref "$MKT_REF" --arg enable "$ENABLE_KEY" '
  .extraKnownMarketplaces[$mkt] = {source: {source: "github", repo: $repo, ref: $ref}}
  | .enabledPlugins[$enable] = true
' <<<"$existing" > "$SETTINGS_TMP"; then
  rm -f "$SETTINGS_TMP"
  exit 1
fi
safe_replace "$SETTINGS" "$SETTINGS_TMP"
echo "  ~ .claude/settings.json (marketplace + enabledPlugins)" >&2

# --- 2 · Shared project rules; runtime workflows come from plugins ---
remove_legacy_kit
stamp_block "$TARGET/AGENTS.md"
stamp_block "$TARGET/CLAUDE.md"

# --- 3 · optional OpenCode compatibility adapter ---
OPENCODE_INCOMPLETE=0
if [[ "$OPENCODE" -eq 1 ]]; then
  opencode_complete=1
  mkdir -p "$TARGET/.agents/skills/implement-spec" "$TARGET/.agents/skills/stage-ticket"
  if ! refresh_managed_tree "$SRC/skills/implement-spec" "$TARGET/.agents/skills/implement-spec" ".agents/skills/implement-spec"; then
    opencode_complete=0
  fi
  if ! refresh_managed_tree "$SRC/skills/stage-ticket" "$TARGET/.agents/skills/stage-ticket" ".agents/skills/stage-ticket"; then
    opencode_complete=0
  fi
  mkdir -p "$TARGET/.opencode/agents" "$TARGET/.opencode/commands" \
    "$TARGET/.opencode/software-factory"
  for src_file in "$SRC"/adapters/opencode/agents/*.md; do
    if ! refresh_managed_file "$src_file" "$TARGET/.opencode/agents/$(basename "$src_file")" ".opencode/agents/$(basename "$src_file")"; then
      opencode_complete=0
    fi
  done
  for src_file in "$SRC"/adapters/opencode/commands/*.md; do
    if ! refresh_managed_file "$src_file" "$TARGET/.opencode/commands/$(basename "$src_file")" ".opencode/commands/$(basename "$src_file")"; then
      opencode_complete=0
    fi
  done
  if ! refresh_managed_file "$SRC/harness/loops.env" "$TARGET/.opencode/software-factory/loops.env" ".opencode/software-factory/loops.env"; then
    opencode_complete=0
  fi
  if [[ "$opencode_complete" -eq 1 ]]; then
    echo "  ~ optional OpenCode skills, agents, commands, and loop caps" >&2
  else
    OPENCODE_INCOMPLETE=1
  fi
fi
stamp_gitignore

# --- 4 · state (seeded on init only; update leaves it alone) ---
if [[ "$MODE" == "init" ]]; then
  seed_state ".claude/routing-log.md" "$SRC/templates/routing-log.md"
  seed_state "eval/golden.jsonl"      "$SRC/eval/golden.jsonl"
  mkdir -p "$TARGET/tasks/todo" "$TARGET/tasks/done"
  [[ -e "$TARGET/tasks/todo/.gitkeep" ]] || : > "$TARGET/tasks/todo/.gitkeep"
  [[ -e "$TARGET/tasks/done/.gitkeep" ]] || : > "$TARGET/tasks/done/.gitkeep"
  echo "  + tasks/{todo,done}/" >&2
fi

if [[ "$OPENCODE_INCOMPLETE" -ne 0 ]]; then
  echo "✗ OpenCode migration incomplete; preserving global OpenCode links and refusing overall success." >&2
  exit 1
fi

# --- 5 · version marker ---
if ! validate_local_file_destination "$MARKER"; then
  exit 73
fi
{
  echo "$VERSION"
  echo "plugin:  $ENABLE_KEY"
  echo "ref:     $MKT_REF"
  echo "stamped: $(date +%F)"
  echo "engine:  $(git -C "$SRC" rev-parse --short HEAD 2>/dev/null || echo unknown)"
} > "$TARGET/.claude/.software-factory-version"
echo "  ~ .claude/.software-factory-version → $VERSION" >&2

# Global OpenCode fallbacks are destructive migration state. Remove them only
# after the complete explicit OpenCode run and every project write succeeded.
if [[ "$OPENCODE" -eq 1 && "$OPENCODE_INCOMPLETE" -eq 0 ]]; then
  cleanup_global_opencode_legacy
fi

echo "  → version: $OLD_VER → $VERSION   ref: $OLD_REF → $MKT_REF" >&2
cat >&2 <<EOF
✓ $MODE complete. Next:
  1. Commit the changes (so web/desktop sessions pick them up).
  2. In Claude Code, trust the repo when prompted; the plugin installs at
     session start (re-installs at the new ref after an update). Type
     /$PLUGIN_NAME:execute <task>.
  3. In Codex, use \$route, \$implement-spec, \$stage-ticket, or \$pr-watch.
  4. With --opencode, use /route <task>, /implement-spec <spec>, or
     /stage-ticket <ticket> to stop before a PR opens.
EOF
