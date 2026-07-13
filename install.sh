#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODULES_DIR="$REPO_DIR/modules"
VERSION="2.0.0"
ALL=0
DRY_RUN=0
ASSUME_YES=0
BREW_DECLINED=0
SKIP_DEPS="${SETUP_SKIP_DEPS:-0}"
BREW_PREFIXES="${SETUP_BREW_PREFIXES:-/opt/homebrew /usr/local}"
WEZTERM_APP="${SETUP_WEZTERM_APP:-/Applications/WezTerm.app}"
SELECTED=""

COMPONENT_TABLE='claude-settings|claude|Claude Code CLI + CLAUDE.md + base settings
claude-statusline|claude|statusline script + statusLine setting
claude-notify|claude|notification hooks + notify preferences
wezterm|wezterm|WezTerm config + app and Nerd Fonts
zsh-core|zsh|Oh My Zsh, p10k, shell tools + zsh dotfiles
zsh-git|zsh|git plugin (Oh My Zsh built-in)
zsh-autosuggestions|zsh|zsh-autosuggestions plugin
zsh-syntax-highlighting|zsh|zsh-syntax-highlighting plugin'

COMPONENTS=()
COMPONENT_MODULES=()
MODULES=()
last_module=""
while IFS='|' read -r component_name module_name _; do
  COMPONENTS+=("$component_name")
  COMPONENT_MODULES+=("$module_name")
  if [ "$module_name" != "$last_module" ]; then
    MODULES+=("$module_name")
    last_module="$module_name"
  fi
done <<<"$COMPONENT_TABLE"

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
ok() { printf '%s %s\n' "${GREEN}  ✓${RESET}" "$*"; }
warn() { printf '%s %s\n' "${YELLOW}  !${RESET}" "$*"; }
die() {
  printf '%s %s\n' "${RED}error:${RESET}" "$*" >&2
  exit 1
}

usage_error() {
  printf '%s %s\n' "${RED}error:${RESET}" "$*" >&2
  printf 'run ./install.sh --help for usage\n' >&2
  exit 2
}

describe_component() {
  local name desc
  while IFS='|' read -r name _ desc; do
    if [ "$name" = "$1" ]; then
      printf '%s' "$desc"
      return 0
    fi
  done <<<"$COMPONENT_TABLE"
  return 1
}

known_component() {
  local c
  for c in "${COMPONENTS[@]}"; do
    if [ "$c" = "$1" ]; then
      return 0
    fi
  done
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

list_components() {
  printf '%s\n' "${COMPONENTS[@]}"
}

usage() {
  cat <<EOF
Usage: ./install.sh [options] [component ...]

Components:
EOF
  local c
  for c in "${COMPONENTS[@]}"; do
    printf '  %-23s %s\n' "$c" "$(describe_component "$c")"
  done
  cat <<EOF

Module aliases select every component of a module: ${MODULES[*]}

Options:
  -a, --all        Install all components
  -l, --list       List available components
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

Configs are written as real files, never symlinks; re-run after editing
the sources under modules/. Existing files are never deleted: they are
renamed to <name>-backup, or <name>-backup-<timestamp> when a backup
already exists.

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

copy_file() {
  local src="$1" dst="$2"
  if [ -f "$dst" ] && [ ! -L "$dst" ] && cmp -s "$src" "$dst"; then
    ok "already up to date: $dst"
    return 0
  fi
  if [ -e "$dst" ] || [ -L "$dst" ]; then
    backup_existing "$dst"
  fi
  if dry_run; then
    info "would copy $dst"
    return 0
  fi
  mkdir -p "$(dirname "$dst")"
  cp "$src" "$dst"
  ok "copied $dst"
}

write_file() {
  local dst="$1" content="$2"
  if [ -f "$dst" ] && [ ! -L "$dst" ] && [ "$(cat "$dst")" = "$content" ]; then
    ok "already up to date: $dst"
    return 0
  fi
  if [ -e "$dst" ] || [ -L "$dst" ]; then
    backup_existing "$dst"
  fi
  if dry_run; then
    info "would write $dst"
    return 0
  fi
  mkdir -p "$(dirname "$dst")"
  printf '%s\n' "$content" >"$dst"
  ok "wrote $dst"
}

json_merge() {
  local out="{" first=1 body fragment
  for fragment in "$@"; do
    body="$(sed '1d;$d' "$fragment")"
    if [ "$first" = "1" ]; then
      first=0
    else
      out="$out,"
    fi
    out="$out
$body"
  done
  printf '%s\n}' "$out"
}

render_zshrc() {
  local keep=""
  if component_selected zsh-git; then
    keep="$keep git"
  fi
  if component_selected zsh-autosuggestions; then
    keep="$keep zsh-autosuggestions"
  fi
  if component_selected zsh-syntax-highlighting; then
    keep="$keep zsh-syntax-highlighting"
  fi
  awk -v keep="$keep " '
    inblock && $0 == ")" { inblock = 0 }
    inblock {
      if (index(keep, " " $1 " ") == 0) next
    }
    $0 == "plugins=(" { inblock = 1 }
    { print }
  ' "$MODULES_DIR/zsh/zshrc"
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
    y | Y | yes | YES)
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

ensure_brew_pkg() {
  local kind="$1" name="$2"
  if command -v brew >/dev/null 2>&1 && brew list "--$kind" "$name" >/dev/null 2>&1; then
    ok "$name already installed"
  elif dry_run; then
    info "would install $name"
  else
    info "installing $name"
    if [ "$kind" = "cask" ]; then
      brew install --cask "$name"
    else
      brew install "$name"
    fi
  fi
}

ensure_formula() { ensure_brew_pkg formula "$1"; }
ensure_cask() { ensure_brew_pkg cask "$1"; }

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
    ensure_formula jq
  fi
  if component_selected claude-settings && deps_enabled; then
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
  info "[claude] writing configs"
  local fragments
  fragments=()
  if component_selected claude-settings; then
    copy_file "$MODULES_DIR/claude/CLAUDE.md" "$HOME/.claude/CLAUDE.md"
    fragments+=("$MODULES_DIR/claude/settings/base.json")
  fi
  if component_selected claude-statusline; then
    copy_file "$MODULES_DIR/claude/statusline.sh" "$HOME/.claude/statusline.sh"
    fragments+=("$MODULES_DIR/claude/settings/statusline.json")
  fi
  if component_selected claude-notify; then
    copy_file "$MODULES_DIR/claude/hooks/notify.sh" "$HOME/.claude/hooks/notify.sh"
    fragments+=("$MODULES_DIR/claude/settings/notify.json")
  fi
  write_file "$HOME/.claude/settings.json" "$(json_merge ${fragments[@]+"${fragments[@]}"})"
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
  info "[wezterm] writing configs"
  copy_file "$MODULES_DIR/wezterm/wezterm.lua" "$HOME/.wezterm.lua"
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
    if component_selected zsh-autosuggestions; then
      ensure_clone https://github.com/zsh-users/zsh-autosuggestions.git "$custom/plugins/zsh-autosuggestions"
    fi
    if component_selected zsh-syntax-highlighting; then
      ensure_clone https://github.com/zsh-users/zsh-syntax-highlighting.git "$custom/plugins/zsh-syntax-highlighting"
    fi
  fi
  if ensure_homebrew; then
    ensure_formula fzf
    ensure_formula eza
    ensure_formula bat
    ensure_formula zoxide
  fi
  info "[zsh] writing configs"
  write_file "$HOME/.zshrc" "$(render_zshrc)"
  copy_file "$MODULES_DIR/zsh/zprofile" "$HOME/.zprofile"
  copy_file "$MODULES_DIR/zsh/p10k.zsh" "$HOME/.p10k.zsh"
}

component_selected() {
  case " $SELECTED " in
    *" $1 "*) return 0 ;;
  esac
  return 1
}

select_component() {
  if component_selected "$1"; then
    return 0
  fi
  SELECTED="$SELECTED $1"
}

select_arg() {
  local i
  if known_component "$1"; then
    select_component "$1"
    return 0
  fi
  if known_module "$1"; then
    i=0
    while [ "$i" -lt "${#COMPONENTS[@]}" ]; do
      if [ "${COMPONENT_MODULES[$i]}" = "$1" ]; then
        select_component "${COMPONENTS[$i]}"
      fi
      i=$((i + 1))
    done
    return 0
  fi
  usage_error "unknown component: $1 (components: ${COMPONENTS[*]}; module aliases: ${MODULES[*]})"
}

module_selected() {
  local i
  i=0
  while [ "$i" -lt "${#COMPONENTS[@]}" ]; do
    if [ "${COMPONENT_MODULES[$i]}" = "$1" ] && component_selected "${COMPONENTS[$i]}"; then
      return 0
    fi
    i=$((i + 1))
  done
  return 1
}

resolve_selection() {
  local plugin
  for plugin in zsh-git zsh-autosuggestions zsh-syntax-highlighting; do
    if component_selected "$plugin" && ! component_selected zsh-core; then
      info "zsh plugins require zsh-core; selecting it"
      select_component zsh-core
    fi
  done
}

parse_args() {
  local no_more_flags=0
  while [ $# -gt 0 ]; do
    if [ "$no_more_flags" = "1" ]; then
      select_arg "$1"
      shift
      continue
    fi
    case "$1" in
      -a | --all) ALL=1 ;;
      -l | --list)
        list_components
        exit 0
        ;;
      -n | --dry-run) DRY_RUN=1 ;;
      -y | --yes) ASSUME_YES=1 ;;
      --skip-deps) SKIP_DEPS=1 ;;
      -V | --version)
        printf 'install.sh %s\n' "$VERSION"
        exit 0
        ;;
      -h | --help)
        usage
        exit 0
        ;;
      --) no_more_flags=1 ;;
      -*) usage_error "unknown option: $1" ;;
      *)
        select_arg "$1"
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
  local i mark desc pointer
  if [ "$1" = "1" ]; then
    printf '\033[%dA\033[J' "$((${#COMPONENTS[@]} + 4))"
  fi
  printf '%s\n\n' "${BOLD}icaro-personal-computer-setup${RESET}"
  i=0
  while [ "$i" -lt "${#COMPONENTS[@]}" ]; do
    mark=" "
    if [ "${checked[i]}" = "1" ]; then
      mark="${GREEN}x${RESET}"
    fi
    pointer="  "
    if [ "$i" = "$cursor" ]; then
      pointer="${BOLD}> ${RESET}"
    fi
    desc="$(describe_component "${COMPONENTS[$i]}")"
    printf '%s[%s] %d. %-23s %s\n' "$pointer" "$mark" "$((i + 1))" "${COMPONENTS[$i]}" "${desc:0:44}"
    i=$((i + 1))
  done
  printf '\n  ↑↓ move · space/1-%d toggle · a all · n none · enter install · q quit\n' "${#COMPONENTS[@]}"
}

toggle_row() {
  if [ "${checked[$1]}" = "1" ]; then
    checked[$1]=0
  else
    checked[$1]=1
  fi
  menu_draw 1
}

interactive_select() {
  local checked count i key cursor
  count=${#COMPONENTS[@]}
  cursor=0
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
    IFS= read -rsn1 key || key="q"
    case "$key" in
      $'\033')
        key=""
        read -rsn2 -t 1 key || true
        case "$key" in
          "[A")
            if [ "$cursor" -gt 0 ]; then
              cursor=$((cursor - 1))
              menu_draw 1
            fi
            ;;
          "[B")
            if [ "$cursor" -lt "$((count - 1))" ]; then
              cursor=$((cursor + 1))
              menu_draw 1
            fi
            ;;
        esac
        ;;
      " ")
        toggle_row "$cursor"
        ;;
      [1-9])
        if [ "$key" -le "$count" ]; then
          toggle_row "$((key - 1))"
        fi
        ;;
      a | A)
        i=0
        while [ "$i" -lt "$count" ]; do
          checked[i]=1
          i=$((i + 1))
        done
        menu_draw 1
        ;;
      n | N)
        i=0
        while [ "$i" -lt "$count" ]; do
          checked[i]=0
          i=$((i + 1))
        done
        menu_draw 1
        ;;
      q | Q)
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
      SELECTED="$SELECTED ${COMPONENTS[$i]}"
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
    SELECTED="${COMPONENTS[*]}"
  fi
  if [ -z "${SELECTED// /}" ]; then
    if [ "$ASSUME_YES" = "1" ]; then
      usage_error "no components specified (--yes disables the interactive menu); try --all"
    elif [ -t 0 ] && [ -t 1 ]; then
      interactive_select
    else
      usage_error "no components specified and no interactive terminal; try --all"
    fi
  fi
  resolve_selection
  if dry_run; then
    info "dry run: no changes will be made"
  fi
  local m
  for m in "${MODULES[@]}"; do
    if module_selected "$m"; then
      type "install_$m" >/dev/null 2>&1 || die "missing install_$m"
      "install_$m"
    fi
  done
  printf '\n'
  if dry_run; then
    info "dry run complete: nothing was changed"
  else
    info "done"
    warn "open a new terminal so the new configs are loaded"
  fi
}

main "$@"
