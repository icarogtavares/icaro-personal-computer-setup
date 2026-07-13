#!/usr/bin/env bash

REPO_ROOT="$(cd "${BATS_TEST_DIRNAME:?}/.." && pwd)"
INSTALL_SH="$REPO_ROOT/install.sh"
NOTIFY_SH="$REPO_ROOT/modules/claude/hooks/notify.sh"

sandbox_setup() {
  FAKE_HOME="${BATS_TEST_TMPDIR:?}/home"
  STUB_BIN="${BATS_TEST_TMPDIR:?}/bin"
  STATE_DIR="${BATS_TEST_TMPDIR:?}/state"
  FAKE_BREW_PREFIX="${BATS_TEST_TMPDIR:?}/brew"
  FAKE_WEZTERM_APP="${BATS_TEST_TMPDIR:?}/Applications/WezTerm.app"
  export FAKE_HOME STUB_BIN STATE_DIR FAKE_BREW_PREFIX FAKE_WEZTERM_APP
  mkdir -p "$FAKE_HOME" "$STUB_BIN" "$STATE_DIR"
  : >"$STATE_DIR/calls.log"
  make_brew_stub
  make_stub curl
  make_stub git
}

make_stub() {
  cat >"$STUB_BIN/$1" <<EOF
#!/bin/bash
printf '%s\n' "$1 \$*" >>"$STATE_DIR/calls.log"
exit 0
EOF
  chmod +x "$STUB_BIN/$1"
}

write_brew_stub() {
  local bin_dir="$1" shellenv_dir="${2:-$1}"
  mkdir -p "$bin_dir"
  cat >"$bin_dir/brew" <<EOF
#!/bin/bash
printf '%s\n' "brew \$*" >>"$STATE_DIR/calls.log"
if [ "\${1:-}" = "shellenv" ]; then
  printf 'export PATH="%s:\$PATH"\n' "$shellenv_dir"
  exit 0
fi
if [ "\${1:-}" = "list" ]; then
  if [ -f "$STATE_DIR/brew.list.exit" ]; then
    exit "\$(cat "$STATE_DIR/brew.list.exit")"
  fi
  exit 1
fi
exit 0
EOF
  chmod +x "$bin_dir/brew"
}

make_brew_stub() {
  write_brew_stub "$STUB_BIN"
}

make_brew_prefix() {
  write_brew_stub "$FAKE_BREW_PREFIX/bin"
}

stage_homebrew_install() {
  write_brew_stub "$STATE_DIR/pending/bin" "$FAKE_BREW_PREFIX/bin"
  cat >"$STUB_BIN/curl" <<EOF
#!/bin/bash
printf '%s\n' "curl \$*" >>"$STATE_DIR/calls.log"
case "\$*" in
  *Homebrew/install*)
    printf "mv '%s' '%s'\n" "$STATE_DIR/pending" "$FAKE_BREW_PREFIX"
    ;;
esac
exit 0
EOF
  chmod +x "$STUB_BIN/curl"
}

make_failing_curl_stub() {
  cat >"$STUB_BIN/curl" <<EOF
#!/bin/bash
printf '%s\n' "curl \$*" >>"$STATE_DIR/calls.log"
printf '%s\n' "$2"
exit $1
EOF
  chmod +x "$STUB_BIN/curl"
}

remove_stub() {
  rm -f "$STUB_BIN/$1"
}

set_brew_list_exit() {
  printf '%s\n' "$1" >"$STATE_DIR/brew.list.exit"
}

make_wezterm_cli_stub() {
  cat >"$STUB_BIN/wezterm" <<EOF
#!/bin/bash
printf '%s\n' "wezterm \$*" >>"$STATE_DIR/calls.log"
if [ "\$*" = "cli list --format json" ]; then
  cat "$STATE_DIR/panes.json" 2>/dev/null
fi
exit 0
EOF
  chmod +x "$STUB_BIN/wezterm"
}

install_sandboxed() {
  env -i HOME="$FAKE_HOME" PATH="$STUB_BIN:/usr/bin:/bin" TERM=dumb NO_COLOR=1 \
    SETUP_BREW_PREFIXES="$FAKE_BREW_PREFIX" SETUP_WEZTERM_APP="$FAKE_WEZTERM_APP" \
    /bin/bash "$INSTALL_SH" "$@"
}

install_sandboxed_env() {
  local pairs
  pairs=()
  while [ $# -gt 0 ]; do
    case "$1" in
      *=*)
        pairs+=("$1")
        shift
        ;;
      *)
        break
        ;;
    esac
  done
  env -i HOME="$FAKE_HOME" PATH="$STUB_BIN:/usr/bin:/bin" TERM=dumb \
    SETUP_BREW_PREFIXES="$FAKE_BREW_PREFIX" SETUP_WEZTERM_APP="$FAKE_WEZTERM_APP" \
    ${pairs[@]+"${pairs[@]}"} /bin/bash "$INSTALL_SH" "$@"
}

install_stdout_only() {
  install_sandboxed "$@" 2>/dev/null
}

install_stderr_only() {
  install_sandboxed "$@" >/dev/null
}

install_sandboxed_stdin() {
  local text="$1"
  shift
  printf '%s\n' "$text" | install_sandboxed "$@"
}

run_install() {
  run install_sandboxed "$@"
}

run_install_env() {
  run install_sandboxed_env "$@"
}

run_install_stdout() {
  run install_stdout_only "$@"
}

run_install_stderr() {
  run install_stderr_only "$@"
}

run_install_stdin() {
  run install_sandboxed_stdin "$@"
}

hook_sandboxed() {
  local stdin_json="$1"
  shift
  printf '%s' "$stdin_json" | env -i HOME="$FAKE_HOME" PATH="$STUB_BIN:/usr/bin:/bin" \
    WEZTERM_PANE="${HOOK_PANE-7}" CLAUDE_NOTIFY_TTY="${HOOK_TTY-$STATE_DIR/tty.out}" \
    /bin/bash "$NOTIFY_SH" "$@"
}

run_hook() {
  run hook_sandboxed "$@"
}

run_menu() {
  run "${BATS_TEST_DIRNAME:?}/helpers/menu.exp" "$REPO_ROOT" "$FAKE_HOME" "$STUB_BIN" "$@"
}

run_menu_color() {
  export MENU_COLOR=1
  run_menu "$@"
  unset MENU_COLOR
}

rendered_zshrc_template() {
  grep -v -e '^# >>> ' -e '^# <<< ' "$REPO_ROOT/modules/zsh/zshrc" >"$STATE_DIR/zshrc.rendered"
  printf '%s' "$STATE_DIR/zshrc.rendered"
}

assert_contains() {
  case "$1" in
    *"$2"*)
      return 0
      ;;
  esac
  printf 'expected to contain: %s\nactual:\n%s\n' "$2" "$1" >&2
  return 1
}

refute_contains() {
  case "$1" in
    *"$2"*)
      printf 'expected not to contain: %s\nactual:\n%s\n' "$2" "$1" >&2
      return 1
      ;;
  esac
  return 0
}

assert_no_ansi() {
  refute_contains "$1" $'\033'
}

assert_symlink() {
  if [ ! -L "$1" ]; then
    printf 'expected symlink: %s\n' "$1" >&2
    return 1
  fi
  local target
  target="$(readlink "$1")"
  if [ "$target" != "$2" ]; then
    printf 'symlink %s points to %s, expected %s\n' "$1" "$target" "$2" >&2
    return 1
  fi
}

assert_regular_file() {
  if [ ! -f "$1" ] || [ -L "$1" ]; then
    printf 'expected regular file: %s\n' "$1" >&2
    return 1
  fi
}

assert_file_equals() {
  assert_regular_file "$1" || return 1
  if ! cmp -s "$2" "$1"; then
    printf 'file %s differs from %s\n' "$1" "$2" >&2
    return 1
  fi
}

assert_executable() {
  if [ ! -x "$1" ]; then
    printf 'expected executable: %s\n' "$1" >&2
    return 1
  fi
}

assert_valid_json() {
  command -v python3 >/dev/null 2>&1 || return 0
  if ! python3 -m json.tool "$1" >/dev/null 2>&1; then
    printf 'invalid json: %s\n' "$1" >&2
    return 1
  fi
}

assert_line_present() {
  if ! grep -qx -- "$2" "$1"; then
    printf 'expected line "%s" in %s\ncontent:\n%s\n' "$2" "$1" "$(cat "$1")" >&2
    return 1
  fi
}

refute_line_present() {
  if grep -qx -- "$2" "$1"; then
    printf 'unexpected line "%s" in %s\n' "$2" "$1" >&2
    return 1
  fi
}

assert_home_empty() {
  local entries
  entries="$(ls -A "$FAKE_HOME")"
  if [ -n "$entries" ]; then
    printf 'expected empty home, found:\n%s\n' "$entries" >&2
    return 1
  fi
}

assert_calls_contain() {
  if ! grep -qF -- "$1" "$STATE_DIR/calls.log"; then
    printf 'expected call: %s\nrecorded:\n%s\n' "$1" "$(cat "$STATE_DIR/calls.log")" >&2
    return 1
  fi
}

refute_calls_contain() {
  if grep -qF -- "$1" "$STATE_DIR/calls.log"; then
    printf 'unexpected call: %s\nrecorded:\n%s\n' "$1" "$(cat "$STATE_DIR/calls.log")" >&2
    return 1
  fi
}

assert_no_calls() {
  if [ -s "$STATE_DIR/calls.log" ]; then
    printf 'expected no calls, recorded:\n%s\n' "$(cat "$STATE_DIR/calls.log")" >&2
    return 1
  fi
}
