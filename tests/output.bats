#!/usr/bin/env bats

setup() {
  load 'helpers/common'
  sandbox_setup
}

@test "piped output contains no ansi escapes even without NO_COLOR" {
  run_install_env --skip-deps --all
  [ "$status" -eq 0 ]
  assert_no_ansi "$output"
}

@test "NO_COLOR output contains no ansi escapes" {
  run_install_env NO_COLOR=1 --skip-deps --all
  [ "$status" -eq 0 ]
  assert_no_ansi "$output"
}

@test "usage errors on stderr contain no ansi escapes" {
  run_install_stderr --bogus
  [ "$status" -eq 2 ]
  assert_no_ansi "$output"
  assert_contains "$output" "unknown option: --bogus"
}

@test "a color terminal renders the blue info arrows" {
  run_menu_color 1 ENTER
  [ "$status" -eq 0 ]
  assert_contains "$output" $'\033[1;34m==>\033[0m'
}

@test "a color terminal renders the checked box in green" {
  run_menu_color 1 q
  [ "$status" -eq 0 ]
  assert_contains "$output" $'\033[0;32mx\033[0m'
}

@test "--help documents every flag, env var and component" {
  run_install --help
  [ "$status" -eq 0 ]
  assert_contains "$output" "--all"
  assert_contains "$output" "--list"
  assert_contains "$output" "--dry-run"
  assert_contains "$output" "--yes"
  assert_contains "$output" "--skip-deps"
  assert_contains "$output" "--version"
  assert_contains "$output" "--help"
  assert_contains "$output" "SETUP_SKIP_DEPS"
  assert_contains "$output" "SETUP_BREW_PREFIXES"
  assert_contains "$output" "SETUP_WEZTERM_APP"
  assert_contains "$output" "NO_COLOR"
  assert_contains "$output" "claude-settings"
  assert_contains "$output" "claude-statusline"
  assert_contains "$output" "claude-notify"
  assert_contains "$output" "wezterm"
  assert_contains "$output" "zsh-core"
  assert_contains "$output" "zsh-git"
  assert_contains "$output" "zsh-autosuggestions"
  assert_contains "$output" "zsh-syntax-highlighting"
  assert_contains "$output" "Module aliases select every component of a module: claude wezterm zsh"
}
