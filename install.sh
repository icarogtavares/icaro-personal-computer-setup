#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VERSION="1.0.0"
ALL=0
DRY_RUN=0
ASSUME_YES=0
BREW_DECLINED=0
SKIP_DEPS="${SETUP_SKIP_DEPS:-0}"
BREW_PREFIXES="${SETUP_BREW_PREFIXES:-/opt/homebrew /usr/local}"
WEZTERM_APP="${SETUP_WEZTERM_APP:-/Applications/WezTerm.app}"
SELECTED=""

MODULE_TABLE='claude|Claude Code config (CLAUDE.md, settings, statusline, hooks) + rtk, jq
wezterm|WezTerm config + app and Nerd Fonts
zsh|Oh My Zsh, powerlevel10k, plugins, fzf/eza/bat/zoxide + zsh dotfiles'

MODULES=()
while IFS='|' read -r module_name _; do
  MODULES+=("$module_name")
done <<<"$MODULE_TABLE"

if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  BLUE=$'\033[1;34m'
  GREEN=$'\033[0;32m'
  YELLOW=$'\033[0;33m'
  RED=$'\033[0;31m'
  BOLD=$'\033[1m'
  RESET=$'\033[0m'
else
  BLUE=""
  GREEN=""
  YELLOW=""
  RED=""
  BOLD=""
  RESET=""
fi

info() { printf '%s %s\n' "${BLUE}==>${RESET}" "$*"; }
ok()   { printf '%s %s\n' "${GREEN}  ✓${RESET}" "$*"; }
warn() { printf '%s %s\n' "${YELLOW}  !${RESET}" "$*"; }
die()  { printf '%s %s\n' "${RED}error:${RESET}" "$*" >&2; exit 1; }

usage_error() {
  printf '%s %s\n' "${RED}error:${RESET}" "$*" >&2
  printf 'run ./install.sh --help for usage\n' >&2
  exit 2
}

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
Usage: ./install.sh [options] [module ...]

Modules:
EOF
  local m
  for m in "${MODULES[@]}"; do
    printf '  %-10s %s\n' "$m" "$(describe_module "$m")"
  done
  cat <<EOF

Options:
  -a, --all        Install all modules
  -l, --list       List available modules
  -n, --dry-run    Preview without changing anything
  -y, --yes        Assume yes; never prompt
      --skip-deps  Skip Homebrew/dependency installs
  -V, --version    Print version
  -h, --help       Show this help

Environment:
  SETUP_SKIP_DEPS=1     Same as --skip-deps
  SETUP_BREW_PREFIXES   Homebrew prefixes to probe (default: /opt/homebrew /usr/local)
  SETUP_WEZTERM_APP     WezTerm app bundle path (default: /Applications/WezTerm.app)
  NO_COLOR              Disable colored output

Existing files are never deleted: they are renamed to <name>-backup,
or <name>-backup-<timestamp> when a backup already exists.

Run with no arguments in a terminal for an interactive menu.
EOF
}

deps_enabled() { [ "$SKIP_DEPS" != "1" ]; }
dry_run() { [ "$DRY_RUN" = "1" ]; }

backup_existing() {
  local target="$1" backup="$1-backup"
  if [ -e "$backup" ] || [ -L "$backup" ]; then
    backup="$backup-$(date +%Y%m%d%H%M%S)"
  fi
  if dry_run; then
    warn "would keep existing $target as $backup"
    return 0
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
  if dry_run; then
    info "would link $dst -> $src"
    return 0
  fi
  mkdir -p "$(dirname "$dst")"
  ln -s "$src" "$dst"
  ok "linked $dst -> $src"
}

activate_brew_prefix() {
  local prefixes prefix
  read -r -a prefixes <<<"$BREW_PREFIXES"
  for prefix in ${prefixes[@]+"${prefixes[@]}"}; do
    if [ -x "$prefix/bin/brew" ]; then
      eval "$("$prefix/bin/brew" shellenv)"
      return 0
    fi
  done
  return 1
}

ensure_homebrew() {
  deps_enabled || return 1
  [ "$BREW_DECLINED" = "1" ] && return 1
  command -v brew >/dev/null 2>&1 && return 0
  activate_brew_prefix && return 0
  if dry_run; then
    info "would install Homebrew"
    return 0
  fi
  local answer=""
  if [ "$ASSUME_YES" = "1" ]; then
    answer=y
  else
    printf 'Homebrew is required for dependencies. Install it now? [y/N] '
    read -r answer || true
  fi
  case "$answer" in
    y|Y|yes|YES)
      local brew_installer
      brew_installer="$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
      /bin/bash -c "$brew_installer"
      activate_brew_prefix && return 0
      die "Homebrew installation did not complete"
      ;;
    *)
      BREW_DECLINED=1
      warn "skipping dependency installation (Homebrew unavailable)"
      return 1
      ;;
  esac
}

ensure_formula() {
  if command -v brew >/dev/null 2>&1 && brew list --formula "$1" >/dev/null 2>&1; then
    ok "$1 already installed"
  elif dry_run; then
    info "would install $1"
  else
    info "installing $1"
    brew install "$1"
  fi
}

ensure_cask() {
  if command -v brew >/dev/null 2>&1 && brew list --cask "$1" >/dev/null 2>&1; then
    ok "$1 already installed"
  elif dry_run; then
    info "would install $1"
  else
    info "installing $1"
    brew install --cask "$1"
  fi
}

ensure_clone() {
  local url="$1" dir="$2"
  if [ -d "$dir" ]; then
    ok "$(basename "$dir") already present"
  elif dry_run; then
    info "would clone $(basename "$dir")"
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
    elif dry_run; then
      info "would install Claude Code"
    else
      info "installing Claude Code"
      local claude_installer
      claude_installer="$(curl -fsSL https://claude.ai/install.sh)"
      /bin/bash -c "$claude_installer"
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
    if [ -d "$WEZTERM_APP" ]; then
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
    elif dry_run; then
      info "would install Oh My Zsh"
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

parse_args() {
  local no_more_flags=0
  while [ $# -gt 0 ]; do
    if [ "$no_more_flags" = "1" ]; then
      known_module "$1" || usage_error "unknown module: $1 (available: ${MODULES[*]})"
      SELECTED="$SELECTED $1"
      shift
      continue
    fi
    case "$1" in
      -a|--all) ALL=1 ;;
      -l|--list) list_modules; exit 0 ;;
      -n|--dry-run) DRY_RUN=1 ;;
      -y|--yes) ASSUME_YES=1 ;;
      --skip-deps) SKIP_DEPS=1 ;;
      -V|--version) printf 'install.sh %s\n' "$VERSION"; exit 0 ;;
      -h|--help) usage; exit 0 ;;
      --) no_more_flags=1 ;;
      -*) usage_error "unknown option: $1" ;;
      *)
        known_module "$1" || usage_error "unknown module: $1 (available: ${MODULES[*]})"
        SELECTED="$SELECTED $1"
        ;;
    esac
    shift
  done
}

menu_restore() {
  printf '\033[?25h'
  stty echo 2>/dev/null || true
}

menu_draw() {
  local i mark desc
  if [ "$1" = "1" ]; then
    printf '\033[%dA\033[J' "$((${#MODULES[@]} + 4))"
  fi
  printf '%s\n\n' "${BOLD}icaro-personal-computer-setup${RESET}"
  i=0
  while [ "$i" -lt "${#MODULES[@]}" ]; do
    mark=" "
    if [ "${checked[i]}" = "1" ]; then
      mark="${GREEN}x${RESET}"
    fi
    desc="$(describe_module "${MODULES[$i]}")"
    printf '  [%s] %d. %-10s %s\n' "$mark" "$((i + 1))" "${MODULES[$i]}" "${desc:0:56}"
    i=$((i + 1))
  done
  printf '\n  1-%d toggle · a all · n none · enter install · q quit\n' "${#MODULES[@]}"
}

interactive_select() {
  local checked count i key
  count=${#MODULES[@]}
  checked=()
  i=0
  while [ "$i" -lt "$count" ]; do
    checked[i]=0
    i=$((i + 1))
  done
  trap 'menu_restore; exit 130' INT TERM
  printf '\033[?25l'
  menu_draw 0
  while true; do
    key=""
    read -rsn1 key || key="q"
    case "$key" in
      $'\033')
        read -rsn2 -t 1 key || true
        ;;
      [1-9])
        if [ "$key" -le "$count" ]; then
          i=$((key - 1))
          if [ "${checked[i]}" = "1" ]; then
            checked[i]=0
          else
            checked[i]=1
          fi
          menu_draw 1
        fi
        ;;
      a|A)
        i=0
        while [ "$i" -lt "$count" ]; do
          checked[i]=1
          i=$((i + 1))
        done
        menu_draw 1
        ;;
      n|N)
        i=0
        while [ "$i" -lt "$count" ]; do
          checked[i]=0
          i=$((i + 1))
        done
        menu_draw 1
        ;;
      q|Q)
        menu_restore
        trap - INT TERM
        exit 0
        ;;
      "")
        break
        ;;
    esac
  done
  menu_restore
  trap - INT TERM
  i=0
  while [ "$i" -lt "$count" ]; do
    if [ "${checked[i]}" = "1" ]; then
      SELECTED="$SELECTED ${MODULES[$i]}"
    fi
    i=$((i + 1))
  done
  if [ -z "${SELECTED// /}" ]; then
    info "nothing selected"
    exit 0
  fi
}

main() {
  parse_args "$@"
  if [ "$ALL" = "1" ]; then
    SELECTED="${MODULES[*]}"
  fi
  if [ -z "${SELECTED// /}" ]; then
    if [ "$ASSUME_YES" = "1" ]; then
      usage_error "no modules specified (--yes disables the interactive menu); try --all"
    elif [ -t 0 ] && [ -t 1 ]; then
      interactive_select
    else
      usage_error "no modules specified and no interactive terminal; try --all"
    fi
  fi
  if dry_run; then
    info "dry run: no changes will be made"
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
  if dry_run; then
    info "dry run complete: nothing was changed"
  else
    info "done"
    warn "open a new terminal so the linked configs are loaded"
  fi
}

main "$@"
