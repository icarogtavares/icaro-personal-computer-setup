#!/usr/bin/env bats

setup() {
  load 'helpers/common'
  sandbox_setup
}

@test "--help exits 0 and prints usage on stdout" {
  run_install_stdout --help
  [ "$status" -eq 0 ]
  assert_contains "$output" "Usage: ./install.sh [options] [module ...]"
}

@test "-h matches --help" {
  run_install -h
  [ "$status" -eq 0 ]
  assert_contains "$output" "Usage: ./install.sh [options] [module ...]"
}

@test "--version exits 0 and prints the version" {
  run_install --version
  [ "$status" -eq 0 ]
  [ "$output" = "install.sh 1.0.0" ]
}

@test "-V matches --version" {
  run_install -V
  [ "$status" -eq 0 ]
  [ "$output" = "install.sh 1.0.0" ]
}

@test "--list exits 0 and prints the modules in registry order" {
  run_install --list
  [ "$status" -eq 0 ]
  [ "${#lines[@]}" -eq 3 ]
  [ "${lines[0]}" = "claude" ]
  [ "${lines[1]}" = "wezterm" ]
  [ "${lines[2]}" = "zsh" ]
}

@test "--list prints nothing on stderr" {
  run_install_stderr --list
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "unknown option exits 2 and reports it on stderr" {
  run_install_stderr --bogus
  [ "$status" -eq 2 ]
  assert_contains "$output" "unknown option: --bogus"
  assert_contains "$output" "--help for usage"
}

@test "unknown option prints nothing on stdout" {
  run_install_stdout --bogus
  [ "$status" -eq 2 ]
  [ -z "$output" ]
}

@test "unknown module exits 2 and lists the available modules" {
  run_install_stderr vim
  [ "$status" -eq 2 ]
  assert_contains "$output" "unknown module: vim"
  assert_contains "$output" "claude wezterm zsh"
}

@test "--yes without modules exits 2 and mentions the disabled menu" {
  run_install --yes
  [ "$status" -eq 2 ]
  assert_contains "$output" "--yes disables the interactive menu"
  assert_contains "$output" "try --all"
}

@test "no modules without a tty exits 2 and suggests --all" {
  run_install
  [ "$status" -eq 2 ]
  assert_contains "$output" "no interactive terminal"
  assert_contains "$output" "try --all"
}

@test "-- treats later arguments as module names" {
  run_install --skip-deps -- zsh
  [ "$status" -eq 0 ]
  assert_symlink "$FAKE_HOME/.zshrc" "$REPO_ROOT/modules/zsh/zshrc"
}

@test "unknown module after -- exits 2" {
  run_install -- --all
  [ "$status" -eq 2 ]
  assert_contains "$output" "unknown module: --all"
}
