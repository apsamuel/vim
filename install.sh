#!/usr/bin/env bash
# install.sh — bootstrap this vim/nvim configuration.
#
# Idempotent: backs up any existing ~/.vim, ~/.vimrc, or ~/.config/nvim that
# is not already a symlink to this repo, then creates the symlinks, fetches
# all submoduled plugins, and generates helptags.

set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
TIMESTAMP="$(/bin/date +%Y%m%d-%H%M%S)"
NVIM_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/nvim"

log()  { printf '\033[1;34m[install]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[install]\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31m[install]\033[0m %s\n' "$*" >&2; exit 1; }

# ---- sanity ---------------------------------------------------------------
[[ -f "$REPO/vimrc" && -f "$REPO/init.lua" ]] \
  || die "this script must live next to vimrc and init.lua (got REPO=$REPO)"

command -v git >/dev/null 2>&1 || die "git is required"

# ---- backup helper --------------------------------------------------------
backup_if_needed() {
  local path="$1"
  if [[ -L "$path" ]]; then
    local target
    target="$(readlink "$path")"
    if [[ "$target" == "$REPO" ]]; then
      log "symlink already correct: $path"
      return 0
    fi
    warn "removing stale symlink: $path -> $target"
    rm -f "$path"
    return 0
  fi
  if [[ -e "$path" ]]; then
    local backup="${path}.bak.${TIMESTAMP}"
    warn "backing up existing $path -> $backup"
    mv "$path" "$backup"
  fi
}

# ---- symlink ~/.vim and ~/.config/nvim -----------------------------------
log "linking ~/.vim -> $REPO"
backup_if_needed "$HOME/.vim"
ln -snf "$REPO" "$HOME/.vim"

# ~/.vimrc is auto-discovered when ~/.vim/vimrc exists, so we deliberately
# do NOT create a separate ~/.vimrc symlink. We back up an existing one if
# it would conflict with this config.
if [[ -e "$HOME/.vimrc" && ! -L "$HOME/.vimrc" ]]; then
  warn "found ~/.vimrc; vim auto-loads ~/.vim/vimrc but ~/.vimrc takes precedence."
  warn "backing it up so this config wins."
  mv "$HOME/.vimrc" "$HOME/.vimrc.bak.${TIMESTAMP}"
fi

mkdir -p "$(dirname "$NVIM_CONFIG_DIR")"
log "linking $NVIM_CONFIG_DIR -> $REPO"
backup_if_needed "$NVIM_CONFIG_DIR"
ln -snf "$REPO" "$NVIM_CONFIG_DIR"

# ---- submodules -----------------------------------------------------------
if [[ -f "$REPO/.gitmodules" ]]; then
  log "fetching plugin submodules (this can take a moment)"
  git -C "$REPO" submodule update --init --recursive --depth 1 --jobs 8
else
  warn "no .gitmodules yet — skipping plugin fetch"
fi

# ---- helptags -------------------------------------------------------------
log "generating helptags (vim)"
if command -v vim >/dev/null 2>&1; then
  vim -E -es -u "$REPO/vimrc" -c 'silent! helptags ALL' -c 'qa!' >/dev/null 2>&1 || true
fi

log "generating helptags (nvim)"
if command -v nvim >/dev/null 2>&1; then
  nvim --headless -u "$REPO/init.lua" -c 'silent! helptags ALL' -c 'qa!' >/dev/null 2>&1 || true
fi

# ---- native plugin builds (fzf-native, fzf binary, jsregexp, TS parsers) -
# Delegated to `make build` so the logic lives in one place. Sub-targets are
# best-effort and skip themselves if their toolchain is missing.
if command -v make >/dev/null 2>&1; then
  log "building native plugin artifacts (make build)"
  (cd "$REPO" && make build) || warn "some native builds failed (non-fatal)"
else
  warn "make not found; skipping native plugin builds"
fi

# ---- done -----------------------------------------------------------------
log "done."
cat <<'EOF'

Next steps:
  - launch nvim; mason will install LSP servers on first file open
    (run :Mason to manage them).
  - launch vim; classic plugins (NERDTree, airline, ALE, fzf.vim, …)
    load automatically.
  - per-machine overrides:  ~/.vimrc.local

EOF
