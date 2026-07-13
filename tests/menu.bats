#!/usr/bin/env bats

setup() {
  load 'helpers/common'
  sandbox_setup
}

@test "menu renders the title, component rows and hint line" {
  run_menu q
  [ "$status" -eq 0 ]
  assert_contains "$output" "icaro-personal-computer-setup"
  assert_contains "$output" "1. claude-settings"
  assert_contains "$output" "2. claude-statusline"
  assert_contains "$output" "3. claude-notify"
  assert_contains "$output" "4. wezterm"
  assert_contains "$output" "5. zsh-core"
  assert_contains "$output" "6. zsh-git"
  assert_contains "$output" "7. zsh-autosuggestions"
  assert_contains "$output" "8. zsh-syntax-highlighting"
  assert_contains "$output" "space/1-8 toggle"
  assert_contains "$output" "enter install"
}

@test "pressing a number marks the component checked" {
  run_menu 1 q
  [ "$status" -eq 0 ]
  assert_contains "$output" "[x] 1. claude-settings"
}

@test "toggling twice selects nothing" {
  run_menu 1 1 ENTER
  [ "$status" -eq 0 ]
  assert_contains "$output" "nothing selected"
  assert_home_empty
}

@test "a selects all and enter installs every component" {
  run_menu a ENTER
  [ "$status" -eq 0 ]
  assert_file_equals "$FAKE_HOME/.claude/CLAUDE.md" "$REPO_ROOT/modules/claude/CLAUDE.md"
  assert_file_equals "$FAKE_HOME/.wezterm.lua" "$REPO_ROOT/modules/wezterm/wezterm.lua"
  assert_file_equals "$FAKE_HOME/.zshrc" "$REPO_ROOT/modules/zsh/zshrc"
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

@test "enter installs only the selected component" {
  run_menu 5 ENTER
  [ "$status" -eq 0 ]
  assert_regular_file "$FAKE_HOME/.zshrc"
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

@test "the pointer starts on the first row" {
  run_menu q
  [ "$status" -eq 0 ]
  assert_contains "$output" "> [ ] 1. claude-settings"
}

@test "arrow down and space toggle the row under the cursor" {
  run_menu DOWN SPACE q
  [ "$status" -eq 0 ]
  assert_contains "$output" "> [x] 2. claude-statusline"
}

@test "space-selected components install on enter" {
  run_menu DOWN SPACE ENTER
  [ "$status" -eq 0 ]
  assert_file_equals "$FAKE_HOME/.claude/statusline.sh" "$REPO_ROOT/modules/claude/statusline.sh"
  assert_contains "$(cat "$FAKE_HOME/.claude/settings.json")" '"statusLine"'
  [ ! -e "$FAKE_HOME/.claude/CLAUDE.md" ]
  [ ! -e "$FAKE_HOME/.wezterm.lua" ]
}

@test "a menu-selected plugin row auto-adds zsh-core" {
  run_menu 8 ENTER
  [ "$status" -eq 0 ]
  assert_contains "$output" "zsh plugins require zsh-core; selecting it"
  assert_regular_file "$FAKE_HOME/.zshrc"
  assert_line_present "$FAKE_HOME/.zshrc" "  zsh-syntax-highlighting"
  refute_line_present "$FAKE_HOME/.zshrc" "  git"
}

@test "the cursor clamps at the top and bottom" {
  run_menu UP SPACE DOWN DOWN DOWN DOWN DOWN DOWN DOWN DOWN DOWN SPACE ENTER
  [ "$status" -eq 0 ]
  assert_file_equals "$FAKE_HOME/.claude/CLAUDE.md" "$REPO_ROOT/modules/claude/CLAUDE.md"
  assert_line_present "$FAKE_HOME/.zshrc" "  zsh-syntax-highlighting"
  [ ! -e "$FAKE_HOME/.wezterm.lua" ]
}

@test "plain escape leaves the menu running" {
  run_menu ESC PAUSE 1 q
  [ "$status" -eq 0 ]
  assert_contains "$output" "[x] 1. claude-settings"
  assert_home_empty
}
