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

@test "--help documents every flag, env var and module" {
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
  assert_contains "$output" "NO_COLOR"
  assert_contains "$output" "claude"
  assert_contains "$output" "wezterm"
  assert_contains "$output" "zsh"
}
