# Shared exact provenance checks for links written by an older checkout.
# Callers decide whether a matching link should be removed and how to report it.

legacy_sha256_file() {
  local file="$1" digest
  if command -v shasum >/dev/null 2>&1; then
    digest="$(shasum -a 256 -- "$file" 2>/dev/null | awk 'NF {print $1; exit}')" || return 1
  elif command -v sha256sum >/dev/null 2>&1; then
    digest="$(sha256sum -- "$file" 2>/dev/null | awk 'NF {print $1; exit}')" || return 1
  else
    return 1
  fi
  [[ "$digest" =~ ^[[:xdigit:]]{64}$ ]] || return 1
  printf '%s\n' "$digest"
}

# Return success when PATH itself (or, by default, one of its lexical parents)
# is a symlink, stopping at the explicit TRUST_ROOT. Callers that are about to
# mutate a directory path include the final component; leaf-link cleanup leaves
# it out so direct leaf symlinks stay supported. A path outside its trust root
# is unsafe by definition, so fail closed with success.
legacy_path_has_symlink_ancestor() {
  local path="$1" include_leaf="${2:-0}" trust_root="${3:-}" current
  [[ "$path" = /* && "$trust_root" = /* ]] || return 0
  case "$path" in
    "$trust_root"|"$trust_root"/*) ;;
    *) return 0 ;;
  esac
  current="$path"
  if [[ "$include_leaf" != 1 ]]; then
    current="$(dirname "$current")"
  fi
  while :; do
    [[ -L "$current" ]] && return 0
    [[ "$current" == "$trust_root" || "$current" == "/" ]] && break
    current="$(dirname "$current")"
  done
  return 1
}

# Canonicalize a path while allowing its final component to be absent. Every
# parent must exist, so a dangling managed link can still be checked exactly.
legacy_canonical_dangling_leaf() {
  local candidate="$1" parent leaf link_target
  local hops=0
  [[ "$candidate" = /* ]] || return 1
  while :; do
    parent="$(dirname "$candidate")"
    parent="$(cd -P "$parent" 2>/dev/null && pwd)" || return 1
    leaf="$(basename "$candidate")"
    candidate="$parent/$leaf"
    if [[ -L "$candidate" ]]; then
      (( hops < 40 )) || return 1
      link_target="$(readlink "$candidate" 2>/dev/null)" || return 1
      if [[ "$link_target" = /* ]]; then
        candidate="$link_target"
      else
        candidate="$parent/$link_target"
      fi
      hops=$((hops + 1))
      continue
    fi
    printf '%s\n' "$candidate"
    return 0
  done
}

# Return success only when LINK is a symlink whose canonical target is exactly
# EXPECTED_REL below a marked plugin checkout. The marker name and relative
# path are both part of the provenance proof; suffixes are never sufficient.
legacy_link_matches_checkout_path() {
  local link_path="$1" expected_rel="$2"
  local raw_target target canonical target_root root manifest expected
  [[ -L "$link_path" && "$expected_rel" != /* && -n "$expected_rel" ]] || return 1
  raw_target="$(readlink "$link_path" 2>/dev/null)" || return 1
  if [[ "$raw_target" = /* ]]; then
    target="$raw_target"
  else
    target="$(dirname "$link_path")/$raw_target"
  fi
  canonical="$(legacy_canonical_dangling_leaf "$target")" || return 1
  target_root="$(dirname "$canonical")"
  root="$target_root"
  while :; do
    for manifest in "$root/.claude-plugin/plugin.json" "$root/.codex-plugin/plugin.json"; do
      if [[ -f "$manifest" ]] && jq -e \
        '(.name == "agentic-harness") or (.name == "software-factory")' \
        "$manifest" >/dev/null 2>&1; then
        expected="$(legacy_canonical_dangling_leaf "$root/$expected_rel")" || continue
        case "$canonical" in
          "$root"/*) ;;
          *) continue ;;
        esac
        case "$expected" in
          "$root"/*) ;;
          *) continue ;;
        esac
        [[ "$canonical" == "$expected" ]] && return 0
      fi
    done
    [[ "$root" == "/" ]] && break
    root="$(dirname "$root")"
  done
  return 1
}
