#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SELECTED=""

MODULE_TABLE='claude|Claude Code config (CLAUDE.md, settings, statusline, hooks) + rtk, jq
wezterm|WezTerm config + app and Nerd Fonts
zsh|Oh My Zsh, powerlevel10k, plugins, fzf/eza/bat/zoxide + zsh dotfiles'

MODULES=()
while IFS='|' read -r module_name _; do
  MODULES+=("$module_name")
done <<<"$MODULE_TABLE"

BLUE=$'\033[1;34m'
GREEN=$'\033[0;32m'
YELLOW=$'\033[0;33m'
RED=$'\033[0;31m'
BOLD=$'\033[1m'
RESET=$'\033[0m'

info() { printf '%s %s\n' "${BLUE}==>${RESET}" "$*"; }
ok()   { printf '%s %s\n' "${GREEN}  ✓${RESET}" "$*"; }
warn() { printf '%s %s\n' "${YELLOW}  !${RESET}" "$*"; }
die()  { printf '%s %s\n' "${RED}error:${RESET}" "$*" >&2; exit 1; }

describe_module() {
  local name desc
  while IFS='|' read -r name desc; do
    if [ "$name" = "$1" ]; then
      printf '%s' "$desc"
      return 0
    fi
  done <<<"$MODULE_TABLE"
  return 1
}

known_module() {
  local m
  for m in "${MODULES[@]}"; do
    if [ "$m" = "$1" ]; then
      return 0
    fi
  done
  return 1
}

list_modules() {
  printf '%s\n' "${MODULES[@]}"
}

usage() {
  cat <<EOF
Usage: ./install.sh [module ...]

Modules:
EOF
  local m
  for m in "${MODULES[@]}"; do
    printf '  %-9s %s\n' "$m" "$(describe_module "$m")"
  done
  cat <<EOF

Options:
  --all       Install every module
  --list      Print available module names
  -h, --help  Show this help

Environment:
  SETUP_SKIP_DEPS=1  Only link config files, skip dependency installation

Existing files are never deleted: they are renamed to <name>-backup,
or <name>-backup-<timestamp> when a backup already exists.

Run without arguments for an interactive menu.
EOF
}

deps_enabled() { [ "${SETUP_SKIP_DEPS:-0}" != "1" ]; }

backup_existing() {
  local target="$1" backup="$1-backup"
  if [ -e "$backup" ] || [ -L "$backup" ]; then
    backup="$backup-$(date +%Y%m%d%H%M%S)"
  fi
  mv "$target" "$backup"
  warn "kept existing $target as $backup"
}

link_file() {
  local src="$1" dst="$2"
  if [ -L "$dst" ]; then
    if [ "$(readlink "$dst")" = "$src" ]; then
      ok "already linked: $dst"
      return 0
    fi
    backup_existing "$dst"
  elif [ -e "$dst" ]; then
    backup_existing "$dst"
  fi
  mkdir -p "$(dirname "$dst")"
  ln -s "$src" "$dst"
  ok "linked $dst -> $src"
}

ensure_homebrew() {
  deps_enabled || return 1
  command -v brew >/dev/null 2>&1 && return 0
  local prefix
  for prefix in /opt/homebrew /usr/local; do
    if [ -x "$prefix/bin/brew" ]; then
      eval "$("$prefix/bin/brew" shellenv)"
      return 0
    fi
  done
  printf 'Homebrew is required for dependencies. Install it now? [y/N] '
  local answer=""
  read -r answer || true
  case "$answer" in
    y|Y|yes|YES)
      local brew_installer
      brew_installer="$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
      /bin/bash -c "$brew_installer"
      for prefix in /opt/homebrew /usr/local; do
        if [ -x "$prefix/bin/brew" ]; then
          eval "$("$prefix/bin/brew" shellenv)"
          return 0
        fi
      done
      die "Homebrew installation did not complete"
      ;;
    *)
      warn "skipping dependency installation (Homebrew unavailable)"
      return 1
      ;;
  esac
}

ensure_formula() {
  if brew list --formula "$1" >/dev/null 2>&1; then
    ok "$1 already installed"
  else
    info "installing $1"
    brew install "$1"
  fi
}

ensure_cask() {
  if brew list --cask "$1" >/dev/null 2>&1; then
    ok "$1 already installed"
  else
    info "installing $1"
    brew install --cask "$1"
  fi
}

ensure_clone() {
  local url="$1" dir="$2"
  if [ -d "$dir" ]; then
    ok "$(basename "$dir") already present"
  else
    info "cloning $(basename "$dir")"
    git clone --depth=1 "$url" "$dir"
  fi
}

install_claude() {
  info "[claude] dependencies"
  if ensure_homebrew; then
    ensure_formula rtk
    ensure_formula jq
  fi
  if deps_enabled; then
    if command -v claude >/dev/null 2>&1; then
      ok "Claude Code already installed"
    else
      info "installing Claude Code"
      curl -fsSL https://claude.ai/install.sh | bash
    fi
  fi
  info "[claude] linking configs"
  link_file "$REPO_DIR/claude/CLAUDE.md" "$HOME/.claude/CLAUDE.md"
  link_file "$REPO_DIR/claude/RTK.md" "$HOME/.claude/RTK.md"
  link_file "$REPO_DIR/claude/settings.json" "$HOME/.claude/settings.json"
  link_file "$REPO_DIR/claude/statusline.sh" "$HOME/.claude/statusline.sh"
  link_file "$REPO_DIR/claude/hooks/notify.sh" "$HOME/.claude/hooks/notify.sh"
}

install_wezterm() {
  info "[wezterm] dependencies"
  if ensure_homebrew; then
    if [ -d "/Applications/WezTerm.app" ]; then
      ok "WezTerm.app already installed"
    else
      ensure_cask wezterm
    fi
    ensure_cask font-meslo-lg-nerd-font
    ensure_cask font-hack-nerd-font
    ensure_cask font-symbols-only-nerd-font
  fi
  info "[wezterm] linking configs"
  link_file "$REPO_DIR/wezterm/wezterm.lua" "$HOME/.wezterm.lua"
}

install_zsh() {
  info "[zsh] dependencies"
  if deps_enabled; then
    if [ -d "$HOME/.oh-my-zsh" ]; then
      ok "Oh My Zsh already installed"
    else
      info "installing Oh My Zsh"
      local omz_installer
      omz_installer="$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
      RUNZSH=no CHSH=no KEEP_ZSHRC=yes ZSH="$HOME/.oh-my-zsh" \
        sh -c "$omz_installer" "" --unattended --keep-zshrc
    fi
    local custom="$HOME/.oh-my-zsh/custom"
    ensure_clone https://github.com/romkatv/powerlevel10k.git "$custom/themes/powerlevel10k"
    ensure_clone https://github.com/zsh-users/zsh-autosuggestions.git "$custom/plugins/zsh-autosuggestions"
    ensure_clone https://github.com/zsh-users/zsh-syntax-highlighting.git "$custom/plugins/zsh-syntax-highlighting"
  fi
  if ensure_homebrew; then
    ensure_formula fzf
    ensure_formula eza
    ensure_formula bat
    ensure_formula zoxide
  fi
  info "[zsh] linking configs"
  link_file "$REPO_DIR/zsh/zshrc" "$HOME/.zshrc"
  link_file "$REPO_DIR/zsh/zprofile" "$HOME/.zprofile"
  link_file "$REPO_DIR/zsh/p10k.zsh" "$HOME/.p10k.zsh"
}

module_by_index() {
  local i=1 m
  for m in "${MODULES[@]}"; do
    if [ "$i" = "$1" ]; then
      printf '%s' "$m"
      return 0
    fi
    i=$((i + 1))
  done
  return 1
}

resolve_token() {
  local token="$1" m
  case "$token" in
    a|all|--all)
      printf '%s' "${MODULES[*]}"
      return 0
      ;;
  esac
  for m in "${MODULES[@]}"; do
    if [ "$token" = "$m" ]; then
      printf '%s' "$m"
      return 0
    fi
  done
  case "$token" in
    [0-9]|[0-9][0-9]) module_by_index "$token" && return 0 ;;
  esac
  return 1
}

parse_selection() {
  local token resolved out=""
  [ $# -gt 0 ] || return 1
  for token in "$@"; do
    case "$token" in
      q|quit|exit) exit 0 ;;
      -h|--help)
        usage
        exit 0
        ;;
      --list)
        list_modules
        exit 0
        ;;
    esac
    if resolved="$(resolve_token "$token")"; then
      out="$out $resolved"
    else
      warn "unknown module: $token"
      return 1
    fi
  done
  SELECTED="$out"
  return 0
}

interactive_select() {
  printf '%s\n\n' "${BOLD}icaro-personal-computer-setup${RESET}"
  local i=1 m
  for m in "${MODULES[@]}"; do
    printf '  %s) %-9s %s\n' "$i" "$m" "$(describe_module "$m")"
    i=$((i + 1))
  done
  printf '  a) all\n  q) quit\n\n'
  local selection tokens
  while true; do
    printf 'Select modules to install (e.g. "1 3", "zsh", "a"): '
    selection=""
    read -r selection || exit 0
    selection="${selection//,/ }"
    tokens=()
    read -ra tokens <<<"$selection"
    if [ "${#tokens[@]}" -eq 0 ]; then
      continue
    fi
    if parse_selection "${tokens[@]}"; then
      return 0
    fi
  done
}

main() {
  if [ $# -eq 0 ]; then
    interactive_select
  else
    parse_selection "$@" || die "run ./install.sh --list to see available modules"
  fi
  local m
  for m in "${MODULES[@]}"; do
    case " $SELECTED " in
      *" $m "*)
        type "install_$m" >/dev/null 2>&1 || die "missing install_$m"
        "install_$m"
        ;;
    esac
  done
  printf '\n'
  info "done"
  warn "open a new terminal so the linked configs are loaded"
}

main "$@"
