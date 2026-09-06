#!/usr/bin/env bash
# Install software-factory through the native Claude and Codex plugin managers.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/legacy-links.sh"

MKT_REPO="${AGENTIC_MARKETPLACE_REPO:-aanojima/software-factory}"
MKT_NAME="${AGENTIC_MARKETPLACE_NAME:-software-factory}"
PLUGIN_NAME="${AGENTIC_PLUGIN_NAME:-software-factory}"
PLUGIN_ID="${PLUGIN_NAME}@${MKT_NAME}"

if ! command -v jq >/dev/null; then
  echo "jq is required to install software-factory plugins" >&2
  exit 69
fi

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
    { }
    END { if (bad || state != "") exit 2 }
  ' "$file"
}

# This read-only check must precede plugin-manager calls and any legacy cleanup.
CODEX_CONFIG_PREFLIGHT="${CODEX_HOME:-$HOME/.codex}/config.toml"
CODEX_CONFIG_PREFLIGHT_TARGET=""
if command -v codex >/dev/null && [[ -e "$CODEX_CONFIG_PREFLIGHT" || -L "$CODEX_CONFIG_PREFLIGHT" ]]; then
  if ! CODEX_CONFIG_PREFLIGHT_TARGET="$(legacy_canonical_dangling_leaf "$CODEX_CONFIG_PREFLIGHT" 2>/dev/null)" || \
     [[ ! -f "$CODEX_CONFIG_PREFLIGHT_TARGET" ]]; then
    echo "refusing unsafe, dangling, or non-file Codex config target: $CODEX_CONFIG_PREFLIGHT" >&2
    exit 73
  fi
  if grep -Eq '(# (>>>|<<<) (agentic-harness|software-factory) implement-spec agents)' "$CODEX_CONFIG_PREFLIGHT_TARGET"; then
    if ! validate_codex_blocks "$CODEX_CONFIG_PREFLIGHT_TARGET"; then
    echo "refusing to remove malformed legacy Codex registrations: $CODEX_CONFIG_PREFLIGHT" >&2
    exit 73
    fi
  fi
fi

CLAUDE_AVAILABLE=0; CLAUDE_INSTALLED=0; CLAUDE_FAILED=0
CODEX_AVAILABLE=0; CODEX_INSTALLED=0; CODEX_FAILED=0

if command -v claude >/dev/null; then
  CLAUDE_AVAILABLE=1
  echo "→ installing $PLUGIN_ID for Claude Code"
  claude_ok=1
  if ! claude_marketplaces="$(claude plugin marketplace list --json)"; then
    claude_ok=0
  elif jq -e --arg name "$MKT_NAME" 'any(.[]; .name == $name)' <<<"$claude_marketplaces" >/dev/null; then
    if jq -e --arg name "$MKT_NAME" --arg repo "$MKT_REPO" \
      'any(.[]; .name == $name and .source == "github" and (((.repo // "") | sub("\\.git$";"")) == $repo))' \
      <<<"$claude_marketplaces" >/dev/null; then
      if ! claude plugin marketplace update "$MKT_NAME"; then claude_ok=0; fi
    else
      echo "  ! Claude marketplace collision for $MKT_NAME; preserving configured source" >&2
      claude_ok=0
    fi
  elif ! claude plugin marketplace add --scope user "$MKT_REPO"; then
    claude_ok=0
  fi
  if [[ "$claude_ok" -eq 1 ]]; then
    if ! claude_plugins="$(claude plugin list --json)"; then
      claude_ok=0
    elif jq -e --arg id "$PLUGIN_ID" '.[] | select(.id == $id and .scope == "user")' <<<"$claude_plugins" >/dev/null; then
      if ! claude plugin update --scope user --yes "$PLUGIN_ID"; then claude_ok=0; fi
    elif ! claude plugin install --scope user --yes "$PLUGIN_ID"; then
      claude_ok=0
    fi
  fi
  if [[ "$claude_ok" -eq 1 ]]; then
    CLAUDE_INSTALLED=1
  else
    CLAUDE_FAILED=1
    echo "  ! Claude plugin installation failed; preserving Claude legacy state" >&2
  fi
else
  echo "  ! Claude Code not found; skipped"
fi

if command -v codex >/dev/null; then
  CODEX_AVAILABLE=1
  echo "→ installing $PLUGIN_ID for Codex"
  mkdir -p "${CODEX_HOME:-$HOME/.codex}"
  codex_ok=1
  if ! codex_marketplaces="$(codex plugin marketplace list --json)"; then
    codex_ok=0
  elif ! CODEX_MKT_EXISTS="$(jq -r --arg name "$MKT_NAME" 'any(.marketplaces[]; .name == $name)' <<<"$codex_marketplaces")"; then
    codex_ok=0
  elif [[ "$CODEX_MKT_EXISTS" == "true" ]]; then
    CODEX_MKT_SOURCE="$(jq -r --arg name "$MKT_NAME" '.marketplaces[] | select(.name == $name) | .marketplaceSource.sourceType // empty' <<<"$codex_marketplaces")"
    CODEX_MKT_URL="$(jq -r --arg name "$MKT_NAME" '.marketplaces[] | select(.name == $name) | (.marketplaceSource.source // empty)' <<<"$codex_marketplaces")"
    CODEX_EXPECTED_URL="https://github.com/${MKT_REPO%.git}"
    CODEX_MKT_URL="${CODEX_MKT_URL%.git}"
    if [[ "$CODEX_MKT_SOURCE" == git && "$CODEX_MKT_URL" == "$CODEX_EXPECTED_URL" ]]; then
      if ! codex plugin marketplace upgrade "$MKT_NAME"; then codex_ok=0; fi
    else
      echo "  ! Codex marketplace collision for $MKT_NAME; preserving configured source" >&2
      codex_ok=0
    fi
  elif ! codex plugin marketplace add "$MKT_REPO"; then
    codex_ok=0
  fi
  if [[ "$codex_ok" -eq 1 ]] && ! codex plugin add "$PLUGIN_ID"; then codex_ok=0; fi
  if [[ "$codex_ok" -eq 1 ]]; then
    CODEX_INSTALLED=1
  else
    CODEX_FAILED=1
    echo "  ! Codex plugin installation failed; preserving Codex legacy state" >&2
  fi
else
  echo "  ! Codex not found; skipped"
fi

# Migrate only the runtime whose native plugin actually installed. A partial
# install keeps the other runtime's checkout links/config available for retry.
remove_legacy_link() {
  local path="$1" expected_rel="$2" trust_root="$3"
  [[ -L "$path" ]] || return 0
  if legacy_path_has_symlink_ancestor "$path" 0 "$trust_root"; then
    echo "  = preserved legacy link with symlink ancestor $path" >&2
  elif legacy_link_matches_checkout_path "$path" "$expected_rel"; then
    rm -f -- "$path"
    echo "  - removed legacy link $path"
  else
    echo "  = preserved unknown legacy link $path" >&2
  fi
}

cleanup_claude_legacy() {
  local name
  for name in implement-spec stage-ticket route pr-watch implement-ticket; do
    if [[ "$GLOBAL_OPENCODE_LEGACY_REMAINS" -eq 1 &&
          ( "$name" == implement-spec || "$name" == stage-ticket ) ]]; then
      echo "  = preserved shared Claude skill link $HOME/.claude/skills/$name" >&2
    else
      remove_legacy_link "$HOME/.claude/skills/$name" "skills/$name" "$HOME"
    fi
  done
  for name in goal-explorer goal-reviewer goal-security-reviewer repo-explorer conformance-reviewer security-reviewer adversarial-reviewer pr-intake implementation-worker; do
    remove_legacy_link "$HOME/.claude/agents/$name.md" "agents/$name.md" "$HOME"
  done
}

cleanup_codex_legacy() {
  # Remove old Codex registrations whose config files pointed into a checkout.
  local codex_root="${CODEX_HOME:-$HOME/.codex}"
  local codex_config="$codex_root/config.toml"
  local resolved mode tmp
  if [[ -e "$codex_config" || -L "$codex_config" ]]; then
    if legacy_path_has_symlink_ancestor "$codex_config" 0 "$codex_root"; then
      echo "  = preserved legacy Codex config with symlink ancestor: $codex_config" >&2
    elif ! resolved="$(legacy_canonical_dangling_leaf "$codex_config" 2>/dev/null)" || \
         [[ ! -f "$resolved" ]]; then
      echo "refusing unsafe, dangling, or non-file Codex config target: $codex_config" >&2
      return 73
    else
      if grep -Eq '(# (>>>|<<<) (agentic-harness|software-factory)( implement-spec agents)?)' "$resolved"; then
        if ! validate_codex_blocks "$resolved"; then
          echo "refusing to remove malformed legacy Codex registrations" >&2
          return 73
        fi
        if ! tmp="$(mktemp "$(dirname "$resolved")/.software-factory-codex.XXXXXX")"; then
          echo "failed to create temporary Codex config" >&2
          return 73
        fi
        if ! awk '
          /^# >>> (agentic-harness|software-factory) implement-spec agents$/ { skip=1; next }
          /^# <<< (agentic-harness|software-factory) implement-spec agents$/ { skip=0; next }
          { if (!skip) print }
        ' "$resolved" > "$tmp"; then
          rm -f "$tmp"
          echo "failed to filter legacy Codex registrations" >&2
          return 73
        fi
        if mode="$(stat -c '%a' "$resolved" 2>/dev/null)"; then
          :
        elif mode="$(stat -f '%Lp' "$resolved" 2>/dev/null)"; then
          :
        else
          rm -f "$tmp"
          echo "refusing to read mode for Codex config target" >&2
          return 73
        fi
        if ! chmod "$mode" "$tmp"; then
          rm -f "$tmp"
          echo "failed to preserve Codex config mode" >&2
          return 73
        fi
        if ! mv "$tmp" "$resolved"; then
          rm -f "$tmp"
          echo "failed to atomically refresh Codex config" >&2
          return 73
        fi
        echo "  - removed legacy Codex checkout registrations"
      fi
    fi
  fi

  local name
  for name in implement-spec stage-ticket; do
    if [[ "$GLOBAL_OPENCODE_LEGACY_REMAINS" -eq 1 ]]; then
      echo "  = preserved shared Codex skill link $HOME/.agents/skills/$name" >&2
    else
      remove_legacy_link "$HOME/.agents/skills/$name" "skills/$name" "$HOME"
    fi
  done
}

# Use the same exact OpenCode names and checkout provenance as init.sh. These
# links block shared PATH cleanup until a later install can migrate them.
has_recognized_global_opencode_legacy() {
  local name path expected found=1
  [[ -n "${HOME:-}" ]] || return 1
  for name in goal-explorer goal-reviewer goal-security-reviewer repo-explorer \
    conformance-reviewer security-reviewer adversarial-reviewer implementation-worker; do
    path="$HOME/.config/opencode/agents/$name.md"
    [[ -L "$path" ]] || continue
    expected="adapters/opencode/agents/$name.md"
    if legacy_link_matches_checkout_path "$path" "$expected"; then
      echo "  = recognized legacy global OpenCode link remains: $path" >&2
      found=0
    fi
  done
  for name in route implement-spec stage-ticket pr-watch; do
    path="$HOME/.config/opencode/commands/$name.md"
    [[ -L "$path" ]] || continue
    expected="adapters/opencode/commands/$name.md"
    if legacy_link_matches_checkout_path "$path" "$expected"; then
      echo "  = recognized legacy global OpenCode link remains: $path" >&2
      found=0
    fi
  done
  return "$found"
}

# Determine this before Claude or Codex cleanup: the shared implement-spec and
# stage-ticket links are still needed by recognized global OpenCode commands.
GLOBAL_OPENCODE_LEGACY_REMAINS=0
if has_recognized_global_opencode_legacy; then
  GLOBAL_OPENCODE_LEGACY_REMAINS=1
fi

if [[ "$CLAUDE_INSTALLED" -eq 1 ]]; then cleanup_claude_legacy; fi
if [[ "$CODEX_INSTALLED" -eq 1 ]]; then cleanup_codex_legacy; fi

# Shared PATH links are removable only when both native managers are present,
# both plugin installs succeed, and no recognized global OpenCode link remains.
if [[ "$CLAUDE_AVAILABLE" -ne 1 || "$CODEX_AVAILABLE" -ne 1 ||
      "$CLAUDE_INSTALLED" -ne 1 || "$CODEX_INSTALLED" -ne 1 ]]; then
  echo "  = preserving shared PATH links: both Claude and Codex managers must be present and install successfully" >&2
  if [[ "$CLAUDE_AVAILABLE" -eq 0 ]]; then
    echo "    Claude manager is absent" >&2
  elif [[ "$CLAUDE_INSTALLED" -ne 1 ]]; then
    echo "    Claude plugin installation did not succeed" >&2
  fi
  if [[ "$CODEX_AVAILABLE" -eq 0 ]]; then
    echo "    Codex manager is absent" >&2
  elif [[ "$CODEX_INSTALLED" -ne 1 ]]; then
    echo "    Codex plugin installation did not succeed" >&2
  fi
elif [[ "$GLOBAL_OPENCODE_LEGACY_REMAINS" -eq 1 ]]; then
  echo "  = preserving shared PATH links: recognized global OpenCode links remain" >&2
else
  IFS=':' read -r -a PATH_DIRS <<<"${PATH:-}"
  for path_dir in "${PATH_DIRS[@]}"; do
    [[ -z "$path_dir" ]] && continue
    remove_legacy_link "$path_dir/software-factory" bin/software-factory "$path_dir"
    remove_legacy_link "$path_dir/agentic-harness" bin/agentic-harness "$path_dir"
  done
fi

if [[ "$CLAUDE_AVAILABLE" -eq 0 && "$CODEX_AVAILABLE" -eq 0 ]]; then
  echo "install Claude Code or Codex, then rerun this command" >&2
  exit 69
fi
if [[ "$CLAUDE_FAILED" -eq 1 || "$CODEX_FAILED" -eq 1 ]]; then
  echo "plugin installation incomplete; successful runtime cleanup applied, failed runtime state preserved" >&2
  exit 1
fi

echo "✓ plugin installation complete; start new Claude Code and Codex sessions"
echo "  OpenCode is optional: use the factory-setup skill with 'init --opencode'."
