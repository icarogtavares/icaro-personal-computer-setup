#!/usr/bin/env bash

REPO_ROOT="$(cd "${BATS_TEST_DIRNAME:?}/.." && pwd)"
INSTALL_SH="$REPO_ROOT/install.sh"

sandbox_setup() {
  FAKE_HOME="${BATS_TEST_TMPDIR:?}/home"
  STUB_BIN="${BATS_TEST_TMPDIR:?}/bin"
  STATE_DIR="${BATS_TEST_TMPDIR:?}/state"
  export FAKE_HOME STUB_BIN STATE_DIR
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

make_brew_stub() {
  cat >"$STUB_BIN/brew" <<EOF
#!/bin/bash
printf '%s\n' "brew \$*" >>"$STATE_DIR/calls.log"
if [ "\${1:-}" = "list" ]; then
  if [ -f "$STATE_DIR/brew.list.exit" ]; then
    exit "\$(cat "$STATE_DIR/brew.list.exit")"
  fi
  exit 1
fi
exit 0
EOF
  chmod +x "$STUB_BIN/brew"
}

remove_stub() {
  rm -f "$STUB_BIN/$1"
}

set_brew_list_exit() {
  printf '%s\n' "$1" >"$STATE_DIR/brew.list.exit"
}

install_sandboxed() {
  env -i HOME="$FAKE_HOME" PATH="$STUB_BIN:/usr/bin:/bin" TERM=dumb NO_COLOR=1 /bin/bash "$INSTALL_SH" "$@"
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
  env -i HOME="$FAKE_HOME" PATH="$STUB_BIN:/usr/bin:/bin" TERM=dumb ${pairs[@]+"${pairs[@]}"} /bin/bash "$INSTALL_SH" "$@"
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

run_menu() {
  run "${BATS_TEST_DIRNAME:?}/helpers/menu.exp" "$REPO_ROOT" "$FAKE_HOME" "$STUB_BIN" "$@"
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

skip_unless_brew_probe_free() {
  if [ -x /opt/homebrew/bin/brew ] || [ -x /usr/local/bin/brew ]; then
    skip "real Homebrew prefix present"
  fi
}
