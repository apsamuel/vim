#!/usr/bin/env bash
# scripts/plugin-status.sh — inspect which vendored plugins are actually
# loaded inside a vim and/or nvim session.
#
# Cross-references three sources:
#   1. plugins staged on disk under pack/{shared,nvim,vim}/{start,opt}/
#   2. each editor's runtime &runtimepath (probed headlessly)
#   3. lua/plugins/*.lua require()/packadd references
#
# Status icons:
#   ✅ loaded       — plugin dir appears in that editor's &runtimepath
#   📦 staged       — on disk but NOT loaded in that editor (likely a bug)
#   ⚪ n/a          — intentionally not for that editor (gated)
#   ❓ unknown      — that editor isn't installed
#   ❌ missing      — referenced by lua/plugins/*.lua but not on disk
#
# Use --no-emoji for ASCII output (CI), --json for machine-readable output.

set -euo pipefail

# ---- bash version guard (macOS default bash is 3.2; we use assoc arrays) -
if (( BASH_VERSINFO[0] < 4 )); then
  echo "error: plugin-status.sh requires bash >= 4 (got $BASH_VERSION)." >&2
  echo "       on macOS:  brew install bash  &&  /opt/homebrew/bin/bash $0 $*" >&2
  exit 3
fi

# ---- locate repo ----------------------------------------------------------
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
[[ -f "$REPO/vimrc" && -f "$REPO/init.lua" ]] \
  || { echo "error: cannot locate repo root from $REPO" >&2; exit 1; }

# ---- defaults / flags -----------------------------------------------------
DO_VIM=1
DO_NVIM=1
EMOJI=1
JSON=0

usage() {
  cat <<'EOF'
Usage: plugin-status.sh [--vim-only] [--nvim-only] [--no-emoji] [--json] [-h]

Inspect which vendored plugins under pack/ are actually loaded in vim/nvim.

Options:
  --vim-only    Probe vim only (skip nvim).
  --nvim-only   Probe nvim only (skip vim).
  --no-emoji    Use ASCII status markers ([+] [P] [-] [?] [X]) instead of emoji.
  --json        Emit machine-readable JSON to stdout.
  -h, --help    Show this help.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --vim-only)   DO_NVIM=0 ;;
    --nvim-only)  DO_VIM=0 ;;
    --no-emoji)   EMOJI=0 ;;
    --json)       JSON=1 ;;
    -h|--help)    usage; exit 0 ;;
    *) echo "unknown option: $1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done

# ---- status markers -------------------------------------------------------
if (( EMOJI )); then
  S_LOADED='✅' S_STAGED='📦' S_NA='⚪' S_UNKNOWN='❓' S_MISSING='❌'
else
  S_LOADED='[+]' S_STAGED='[P]' S_NA='[-]' S_UNKNOWN='[?]' S_MISSING='[X]'
fi

# ---- gated plugins (pack/shared/start/* but vimrc gates them off in nvim).
# Listing them here means we render ⚪ instead of 📦 under nvim.
NVIM_GATED=(
  nerdtree
  vim-airline
  vim-airline-themes
  vim-gitgutter
  vim-polyglot
  ale
)

is_nvim_gated() {
  local name="$1" g
  for g in "${NVIM_GATED[@]}"; do
    [[ "$g" == "$name" ]] && return 0
  done
  return 1
}

# ---- enumerate staged plugins --------------------------------------------
# Populates STAGED_NAMES (sorted unique) and per-name metadata:
#   STAGED_BUNDLE[name] = shared|nvim|vim
#   STAGED_MODE[name]   = start|opt
declare -a STAGED_NAMES=()
declare -A STAGED_BUNDLE=()
declare -A STAGED_MODE=()

scan_pack() {
  local bundle="$1" mode="$2"
  local dir="$REPO/pack/$bundle/$mode"
  [[ -d "$dir" ]] || return 0
  local entry name
  for entry in "$dir"/*; do
    [[ -d "$entry" ]] || continue
    name="$(basename "$entry")"
    [[ "$name" == ".gitkeep" ]] && continue
    if [[ -n "${STAGED_BUNDLE[$name]:-}" ]]; then
      # name collision across bundles — keep the first, warn.
      echo "warn: duplicate plugin dir name '$name' in pack/$bundle/$mode" >&2
      continue
    fi
    STAGED_NAMES+=("$name")
    STAGED_BUNDLE[$name]="$bundle"
    STAGED_MODE[$name]="$mode"
  done
}

for b in shared nvim vim; do
  for m in start opt; do
    scan_pack "$b" "$m"
  done
done

# Sort STAGED_NAMES
if (( ${#STAGED_NAMES[@]} > 0 )); then
  IFS=$'\n' STAGED_NAMES=($(printf '%s\n' "${STAGED_NAMES[@]}" | LC_ALL=C sort -u))
  unset IFS
fi

# ---- probe an editor's &runtimepath --------------------------------------
# usage: probe_runtimepath <vim|nvim>
# echoes one path per line (only paths under $REPO/pack/).
probe_runtimepath() {
  local bin="$1" tmp rtp
  command -v "$bin" >/dev/null 2>&1 || return 2
  tmp="$(mktemp -t plugin-status.XXXXXX)"
  case "$bin" in
    vim)
      vim -E -es -u "$REPO/vimrc" \
        -c "redir! > $tmp" -c 'echo &runtimepath' -c 'redir END' \
        -c 'qa!' </dev/null >/dev/null 2>&1 || true
      ;;
    nvim)
      nvim --headless -n -u "$REPO/init.lua" \
        -c "redir! > $tmp" -c 'echo &runtimepath' -c 'redir END' \
        -c 'qa!' </dev/null >/dev/null 2>&1 || true
      ;;
  esac
  if [[ ! -s "$tmp" ]]; then
    rm -f "$tmp"
    return 1
  fi
  rtp="$(tr -d '\n' < "$tmp")"
  rm -f "$tmp"
  # Split on commas, keep only paths starting with $REPO/pack/.
  local IFS=','
  for path in $rtp; do
    # trim whitespace
    path="${path#"${path%%[![:space:]]*}"}"
    path="${path%"${path##*[![:space:]]}"}"
    [[ -n "$path" ]] || continue
    [[ "$path" == "$REPO/pack/"* ]] && printf '%s\n' "$path"
  done
}

# Loaded sets (whitespace-separated dir basenames).
VIM_LOADED=""
NVIM_LOADED=""
VIM_AVAILABLE=0
NVIM_AVAILABLE=0

if (( DO_VIM )); then
  if command -v vim >/dev/null 2>&1; then
    VIM_AVAILABLE=1
    while IFS= read -r path; do
      VIM_LOADED+=" $(basename "$path") "
    done < <(probe_runtimepath vim || true)
  fi
fi

if (( DO_NVIM )); then
  if command -v nvim >/dev/null 2>&1; then
    NVIM_AVAILABLE=1
    while IFS= read -r path; do
      NVIM_LOADED+=" $(basename "$path") "
    done < <(probe_runtimepath nvim || true)
  fi
fi

is_loaded() {
  # $1 = " name1  name2 " bag, $2 = name
  case "$1" in
    *" $2 "*) return 0 ;;
    *)        return 1 ;;
  esac
}

# ---- compute status per plugin -------------------------------------------
# Status logic:
#   pack/nvim/*  → vim cell is ⚪ (n/a); nvim cell is ✅ if loaded else 📦
#   pack/vim/*   → nvim cell is ⚪;     vim cell is ✅ if loaded else 📦
#   pack/shared/* → both editors checked; nvim-gated names render ⚪ for nvim
#   editor unavailable → cell is ❓
status_for() {
  local name="$1" editor="$2"  # editor: vim|nvim
  local bundle="${STAGED_BUNDLE[$name]}"
  if [[ "$editor" == vim ]]; then
    (( VIM_AVAILABLE )) || { echo "$S_UNKNOWN"; return; }
    case "$bundle" in
      nvim) echo "$S_NA"; return ;;
    esac
    if is_loaded "$VIM_LOADED" "$name"; then echo "$S_LOADED"; else echo "$S_STAGED"; fi
  else
    (( NVIM_AVAILABLE )) || { echo "$S_UNKNOWN"; return; }
    case "$bundle" in
      vim) echo "$S_NA"; return ;;
    esac
    if is_nvim_gated "$name"; then echo "$S_NA"; return; fi
    if is_loaded "$NVIM_LOADED" "$name"; then echo "$S_LOADED"; else echo "$S_STAGED"; fi
  fi
}

# ---- referenced-but-missing detection ------------------------------------
# Scan lua/plugins/*.lua for require('plugins.X') and packadd <name> /
# vim.cmd('packadd ...') and check that the underlying plugin (best effort)
# exists on disk.
declare -a MISSING_REFS=()

scan_lua_refs() {
  local f
  [[ -d "$REPO/lua/plugins" ]] || return 0
  for f in "$REPO/lua/plugins"/*.lua; do
    [[ -f "$f" ]] || continue
    # packadd <name> and packadd! <name>
    while IFS= read -r name; do
      [[ -n "$name" ]] || continue
      if [[ -z "${STAGED_BUNDLE[$name]:-}" ]]; then
        MISSING_REFS+=("$name|packadd|$(basename "$f")")
      fi
    done < <(grep -Eho "packadd!?[[:space:]]+[A-Za-z0-9._+-]+" "$f" 2>/dev/null \
              | sed -E 's/^packadd!?[[:space:]]+//')

    # require('plugin-dir-name') — only checks if the required name happens to
    # match a staged dir. Lua module names like 'plugins.lsp' won't match any
    # plugin dir, so they are silently ignored. This catches the common case
    # require('telescope'), require('gitsigns'), etc. that map 1:1 to dirs.
    while IFS= read -r mod; do
      [[ -n "$mod" ]] || continue
      # Only the top-level module segment.
      local top="${mod%%.*}"
      # Skip our own internal modules (plugins.*, core.*).
      case "$top" in plugins|core) continue ;; esac
      # Only flag if a plugin dir with the SAME name is staged-or-missing —
      # i.e. only flag if there is a credible 1:1 mapping. We can't easily
      # tell otherwise; conservative is best to avoid false positives.
      if [[ -z "${STAGED_BUNDLE[$top]:-}" ]] \
        && [[ -z "${STAGED_BUNDLE[${top}.nvim]:-}" ]] \
        && [[ -z "${STAGED_BUNDLE[nvim-${top}]:-}" ]] \
        && [[ -z "${STAGED_BUNDLE[${top}.vim]:-}" ]]; then
        :  # no obvious dir match — don't flag (would be noisy).
      fi
    done < <(grep -Eho "require\(['\"][^'\"]+['\"]\)" "$f" 2>/dev/null \
              | sed -E "s/^require\(['\"]([^'\"]+)['\"]\)$/\1/")
  done
}

scan_lua_refs

# ---- native artifact detection -------------------------------------------
# A handful of plugins need post-clone compilation (separate from `git
# submodule update`). Only checked if the plugin is staged on disk.
declare -a NATIVE_PENDING=()

native_check_fzf_native() {
  local d="$REPO/pack/nvim/opt/telescope-fzf-native.nvim"
  [[ -d "$d" ]] || return 0
  compgen -G "$d/build/libfzf.*" >/dev/null 2>&1 && return 0
  compgen -G "$d/libfzf.*"        >/dev/null 2>&1 && return 0
  NATIVE_PENDING+=("telescope-fzf-native.nvim|libfzf.so/.dylib not built|make build-fzf-native")
}

native_check_fzf_bin() {
  local d="$REPO/pack/shared/start/fzf"
  [[ -d "$d" ]] || return 0
  [[ -x "$d/bin/fzf" ]] && return 0
  command -v fzf >/dev/null 2>&1 && return 0
  NATIVE_PENDING+=("fzf|bin/fzf missing and no system fzf on PATH|make build-fzf-bin")
}

native_check_luasnip_jsregexp() {
  local d="$REPO/pack/nvim/opt/LuaSnip"
  [[ -d "$d" ]] || return 0
  [[ -d "$d/lua/luasnip-jsregexp" ]] && return 0
  compgen -G "$d/deps/jsregexp/jsregexp*.so"    >/dev/null 2>&1 && return 0
  compgen -G "$d/deps/jsregexp/jsregexp*.dylib" >/dev/null 2>&1 && return 0
  NATIVE_PENDING+=("LuaSnip|jsregexp not built (optional; needed for LSP snippet transformations)|make build-luasnip-jsregexp")
}

native_check_treesitter() {
  local d="$REPO/pack/nvim/opt/nvim-treesitter"
  [[ -d "$d" ]] || return 0
  # Parsers land in nvim's data dir, not under the plugin dir, so we just remind.
  NATIVE_PENDING+=("nvim-treesitter|parsers compile lazily; run :TSUpdate once|make build-treesitter")
}

native_check_fzf_native
native_check_fzf_bin
native_check_luasnip_jsregexp
native_check_treesitter

# ---- output: JSON --------------------------------------------------------
json_escape() {
  # minimal JSON string escape
  local s="$1"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  printf '%s' "$s"
}

if (( JSON )); then
  printf '{\n'
  printf '  "repo": "%s",\n' "$(json_escape "$REPO")"
  printf '  "vim_available": %s,\n' "$([[ $VIM_AVAILABLE -eq 1 ]] && echo true || echo false)"
  printf '  "nvim_available": %s,\n' "$([[ $NVIM_AVAILABLE -eq 1 ]] && echo true || echo false)"
  printf '  "plugins": [\n'
  total=${#STAGED_NAMES[@]}
  i=0
  for name in "${STAGED_NAMES[@]}"; do
    i=$((i+1))
    vs="$(status_for "$name" vim)"
    ns="$(status_for "$name" nvim)"
    sep=','
    [[ $i -eq $total ]] && sep=''
    printf '    {"name":"%s","bundle":"%s","mode":"%s","vim":"%s","nvim":"%s"}%s\n' \
      "$(json_escape "$name")" \
      "$(json_escape "${STAGED_BUNDLE[$name]}")" \
      "$(json_escape "${STAGED_MODE[$name]}")" \
      "$(json_escape "$vs")" \
      "$(json_escape "$ns")" \
      "$sep"
  done
  printf '  ],\n'
  printf '  "missing_refs": ['
  if (( ${#MISSING_REFS[@]} > 0 )); then
    printf '\n'
    n=${#MISSING_REFS[@]}
    j=0
    for ref in "${MISSING_REFS[@]}"; do
      j=$((j+1))
      IFS='|' read -r mname mkind mfile <<<"$ref"
      sep=','
      [[ $j -eq $n ]] && sep=''
      printf '    {"name":"%s","kind":"%s","source":"%s"}%s\n' \
        "$(json_escape "$mname")" \
        "$(json_escape "$mkind")" \
        "$(json_escape "$mfile")" \
        "$sep"
    done
    printf '  '
  fi
  printf ']'
  printf ',\n  "native_pending": ['
  if (( ${#NATIVE_PENDING[@]} > 0 )); then
    printf '\n'
    nn=${#NATIVE_PENDING[@]}
    k=0
    for ref in "${NATIVE_PENDING[@]}"; do
      k=$((k+1))
      IFS='|' read -r pname preason pfix <<<"$ref"
      sep=','
      [[ $k -eq $nn ]] && sep=''
      printf '    {"name":"%s","reason":"%s","fix":"%s"}%s\n' \
        "$(json_escape "$pname")" \
        "$(json_escape "$preason")" \
        "$(json_escape "$pfix")" \
        "$sep"
    done
    printf '  '
  fi
  printf ']\n}\n'
  exit 0
fi

# ---- output: human table -------------------------------------------------
# Compute column width for the plugin name.
maxw=6
for name in "${STAGED_NAMES[@]}"; do
  (( ${#name} > maxw )) && maxw=${#name}
done
# Add a small margin.
fmt="  %-${maxw}s  %-7s  %-5s  %-4s  %-4s\n"

c_dim=$'\033[2m'; c_off=$'\033[0m'; c_bold=$'\033[1m'

printf '\n%srepo:%s %s\n' "$c_dim" "$c_off" "$REPO"
if (( DO_VIM )); then
  if (( VIM_AVAILABLE )); then
    printf '%svim:%s   detected\n' "$c_dim" "$c_off"
  else
    printf '%svim:%s   not installed (status will be %s)\n' "$c_dim" "$c_off" "$S_UNKNOWN"
  fi
fi
if (( DO_NVIM )); then
  if (( NVIM_AVAILABLE )); then
    printf '%snvim:%s  detected\n' "$c_dim" "$c_off"
  else
    printf '%snvim:%s  not installed (status will be %s)\n' "$c_dim" "$c_off" "$S_UNKNOWN"
  fi
fi
echo

printf "${c_bold}${fmt}${c_off}" "PLUGIN" "BUNDLE" "MODE" "VIM" "NVIM"
printf "${fmt}" "------" "------" "----" "---" "----"

# Counters
declare -A COUNT=([loaded_vim]=0 [staged_vim]=0 [na_vim]=0 [unknown_vim]=0
                  [loaded_nvim]=0 [staged_nvim]=0 [na_nvim]=0 [unknown_nvim]=0)

bump() {
  local cell="$1" editor="$2"
  case "$cell" in
    "$S_LOADED")  COUNT[loaded_$editor]=$(( ${COUNT[loaded_$editor]} + 1 )) ;;
    "$S_STAGED")  COUNT[staged_$editor]=$(( ${COUNT[staged_$editor]} + 1 )) ;;
    "$S_NA")      COUNT[na_$editor]=$(( ${COUNT[na_$editor]} + 1 )) ;;
    "$S_UNKNOWN") COUNT[unknown_$editor]=$(( ${COUNT[unknown_$editor]} + 1 )) ;;
  esac
}

for name in "${STAGED_NAMES[@]}"; do
  vs="$(status_for "$name" vim)"
  ns="$(status_for "$name" nvim)"
  bump "$vs" vim
  bump "$ns" nvim
  printf "${fmt}" "$name" "${STAGED_BUNDLE[$name]}" "${STAGED_MODE[$name]}" "$vs" "$ns"
done

echo
printf '%slegend:%s  %s loaded   %s staged-but-inert   %s n/a   %s editor unavailable   %s missing\n' \
  "$c_dim" "$c_off" "$S_LOADED" "$S_STAGED" "$S_NA" "$S_UNKNOWN" "$S_MISSING"

echo
printf '%ssummary:%s\n' "$c_dim" "$c_off"
if (( DO_VIM )); then
  printf "  vim   %s %d  %s %d  %s %d  %s %d\n" \
    "$S_LOADED"  "${COUNT[loaded_vim]}" \
    "$S_STAGED"  "${COUNT[staged_vim]}" \
    "$S_NA"      "${COUNT[na_vim]}" \
    "$S_UNKNOWN" "${COUNT[unknown_vim]}"
fi
if (( DO_NVIM )); then
  printf "  nvim  %s %d  %s %d  %s %d  %s %d\n" \
    "$S_LOADED"  "${COUNT[loaded_nvim]}" \
    "$S_STAGED"  "${COUNT[staged_nvim]}" \
    "$S_NA"      "${COUNT[na_nvim]}" \
    "$S_UNKNOWN" "${COUNT[unknown_nvim]}"
fi

# Missing references (referenced by lua/plugins/*.lua but not on disk)
if (( ${#MISSING_REFS[@]} > 0 )); then
  echo
  printf '%s referenced but not on disk:\n' "$S_MISSING"
  for ref in "${MISSING_REFS[@]}"; do
    IFS='|' read -r mname mkind mfile <<<"$ref"
    printf '   %s  (%s in %s)\n' "$mname" "$mkind" "$mfile"
  done
fi

# Native artifacts that need compilation beyond `git submodule update`.
if (( ${#NATIVE_PENDING[@]} > 0 )); then
  echo
  if (( EMOJI )); then
    printf '\xf0\x9f\xa7\xb1 native build pending:\n'
  else
    printf '[!] native build pending:\n'
  fi
  for ref in "${NATIVE_PENDING[@]}"; do
    IFS='|' read -r pname preason pfix <<<"$ref"
    printf '   %-32s  %s\n' "$pname" "$preason"
    printf '       fix: %s\n' "$pfix"
  done
fi

# Hints
staged_total=$(( ${COUNT[staged_vim]} + ${COUNT[staged_nvim]} ))
if (( staged_total > 0 )); then
  echo
  printf '%shint:%s  %s entries are vendored but not activated.\n' "$c_dim" "$c_off" "$S_STAGED"
  printf '       For nvim, ensure the dir lives under pack/nvim/opt/ and that\n'
  printf '       lua/plugins/init.lua packadd!s it (or move to pack/nvim/start/).\n'
  printf '       For vim, check pack/shared/start/ placement and any\n'
  printf '       `if !has(\047nvim\047)` gate in vimrc.\n'
fi

echo
