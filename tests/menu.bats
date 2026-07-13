#!/usr/bin/env bats

setup() {
  load 'helpers/common'
  sandbox_setup
}

@test "menu renders the title, module rows and hint line" {
  run_menu q
  [ "$status" -eq 0 ]
  assert_contains "$output" "icaro-personal-computer-setup"
  assert_contains "$output" "1. claude"
  assert_contains "$output" "2. wezterm"
  assert_contains "$output" "3. zsh"
  assert_contains "$output" "enter install"
}

@test "pressing a number marks the module checked" {
  run_menu 1 q
  [ "$status" -eq 0 ]
  assert_contains "$output" "[x] 1. claude"
}

@test "toggling twice selects nothing" {
  run_menu 1 1 ENTER
  [ "$status" -eq 0 ]
  assert_contains "$output" "nothing selected"
  assert_home_empty
}

@test "a selects all and enter installs every module" {
  run_menu a ENTER
  [ "$status" -eq 0 ]
  assert_symlink "$FAKE_HOME/.claude/CLAUDE.md" "$REPO_ROOT/claude/CLAUDE.md"
  assert_symlink "$FAKE_HOME/.wezterm.lua" "$REPO_ROOT/wezterm/wezterm.lua"
  assert_symlink "$FAKE_HOME/.zshrc" "$REPO_ROOT/zsh/zshrc"
}

@test "n clears the selection" {
  run_menu 1 n ENTER
  [ "$status" -eq 0 ]
  assert_contains "$output" "nothing selected"
  assert_home_empty
}

@test "q quits without installing and restores the cursor" {
  run_menu q
  [ "$status" -eq 0 ]
  assert_home_empty
  assert_contains "$output" $'\033[?25h'
}

@test "enter installs only the selected module" {
  run_menu 3 ENTER
  [ "$status" -eq 0 ]
  assert_symlink "$FAKE_HOME/.zshrc" "$REPO_ROOT/zsh/zshrc"
  [ ! -e "$FAKE_HOME/.claude/CLAUDE.md" ]
  [ ! -e "$FAKE_HOME/.wezterm.lua" ]
}

@test "out of range numbers are ignored" {
  run_menu 9 ENTER
  [ "$status" -eq 0 ]
  assert_contains "$output" "nothing selected"
  assert_home_empty
}

@test "ctrl-c exits 130 and restores the cursor" {
  run_menu CTRL_C
  [ "$status" -eq 130 ]
  assert_contains "$output" $'\033[?25h'
  assert_home_empty
}
