#!/usr/bin/env bats

setup() {
  load 'helpers/common'
  sandbox_setup
}

@test "--help exits 0 and prints usage on stdout" {
  run_install_stdout --help
  [ "$status" -eq 0 ]
  assert_contains "$output" "Usage: ./install.sh [options] [component ...]"
}

@test "-h matches --help" {
  run_install -h
  [ "$status" -eq 0 ]
  assert_contains "$output" "Usage: ./install.sh [options] [component ...]"
}

@test "--version exits 0 and prints the version" {
  run_install --version
  [ "$status" -eq 0 ]
  [ "$output" = "install.sh 2.0.0" ]
}

@test "-V matches --version" {
  run_install -V
  [ "$status" -eq 0 ]
  [ "$output" = "install.sh 2.0.0" ]
}

@test "--list exits 0 and prints the components in registry order" {
  run_install --list
  [ "$status" -eq 0 ]
  [ "${#lines[@]}" -eq 8 ]
  [ "${lines[0]}" = "claude-settings" ]
  [ "${lines[1]}" = "claude-statusline" ]
  [ "${lines[2]}" = "claude-notify" ]
  [ "${lines[3]}" = "wezterm" ]
  [ "${lines[4]}" = "zsh-core" ]
  [ "${lines[5]}" = "zsh-git" ]
  [ "${lines[6]}" = "zsh-autosuggestions" ]
  [ "${lines[7]}" = "zsh-syntax-highlighting" ]
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

@test "unknown component exits 2 and lists components and aliases" {
  run_install_stderr vim
  [ "$status" -eq 2 ]
  assert_contains "$output" "unknown component: vim"
  assert_contains "$output" "claude-settings claude-statusline claude-notify wezterm zsh-core zsh-git zsh-autosuggestions zsh-syntax-highlighting"
  assert_contains "$output" "module aliases: claude wezterm zsh"
}

@test "a component name installs just that component" {
  run_install --skip-deps claude-notify
  [ "$status" -eq 0 ]
  assert_file_equals "$FAKE_HOME/.claude/hooks/notify.sh" "$REPO_ROOT/modules/claude/hooks/notify.sh"
  assert_contains "$(cat "$FAKE_HOME/.claude/settings.json")" '"hooks"'
  [ ! -e "$FAKE_HOME/.claude/CLAUDE.md" ]
  [ ! -e "$FAKE_HOME/.claude/statusline.sh" ]
}

@test "a module alias selects every component of the module" {
  run_install --skip-deps claude
  [ "$status" -eq 0 ]
  assert_file_equals "$FAKE_HOME/.claude/CLAUDE.md" "$REPO_ROOT/modules/claude/CLAUDE.md"
  assert_file_equals "$FAKE_HOME/.claude/statusline.sh" "$REPO_ROOT/modules/claude/statusline.sh"
  assert_file_equals "$FAKE_HOME/.claude/hooks/notify.sh" "$REPO_ROOT/modules/claude/hooks/notify.sh"
}

@test "aliases and components mix and deduplicate" {
  run_install --skip-deps zsh zsh-core wezterm
  [ "$status" -eq 0 ]
  assert_file_equals "$FAKE_HOME/.zshrc" "$REPO_ROOT/modules/zsh/zshrc"
  assert_file_equals "$FAKE_HOME/.wezterm.lua" "$REPO_ROOT/modules/wezterm/wezterm.lua"
  [ "$(grep -c "wrote $FAKE_HOME/.zshrc" <<<"$output")" -eq 1 ]
}

@test "--yes without components exits 2 and mentions the disabled menu" {
  run_install --yes
  [ "$status" -eq 2 ]
  assert_contains "$output" "--yes disables the interactive menu"
  assert_contains "$output" "try --all"
}

@test "no components without a tty exits 2 and suggests --all" {
  run_install
  [ "$status" -eq 2 ]
  assert_contains "$output" "no interactive terminal"
  assert_contains "$output" "try --all"
}

@test "-- treats later arguments as component names" {
  run_install --skip-deps -- zsh
  [ "$status" -eq 0 ]
  assert_file_equals "$FAKE_HOME/.zshrc" "$REPO_ROOT/modules/zsh/zshrc"
}

@test "unknown component after -- exits 2" {
  run_install -- --all
  [ "$status" -eq 2 ]
  assert_contains "$output" "unknown component: --all"
}
