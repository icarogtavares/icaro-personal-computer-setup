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
  assert_contains "$output" "9. zoxide"
  assert_contains "$output" "10. eza"
  assert_contains "$output" "11. fzf"
  assert_contains "$output" "12. bat"
  assert_contains "$output" "space/1-9 toggle"
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
  assert_file_equals "$FAKE_HOME/.zshrc" "$(rendered_zshrc_template)"
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
  run_menu 0 ENTER
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
  assert_contains "$output" "zsh-syntax-highlighting requires zsh-core; selecting it"
  assert_regular_file "$FAKE_HOME/.zshrc"
  assert_line_present "$FAKE_HOME/.zshrc" "  zsh-syntax-highlighting"
  refute_line_present "$FAKE_HOME/.zshrc" "  git"
}

@test "the cursor clamps at the top and bottom" {
  run_menu UP SPACE DOWN DOWN DOWN DOWN DOWN DOWN DOWN DOWN DOWN DOWN DOWN DOWN SPACE ENTER
  [ "$status" -eq 0 ]
  assert_file_equals "$FAKE_HOME/.claude/CLAUDE.md" "$REPO_ROOT/modules/claude/CLAUDE.md"
  assert_line_present "$FAKE_HOME/.zshrc" 'export BAT_THEME="Visual Studio Dark+"'
  [ ! -e "$FAKE_HOME/.wezterm.lua" ]
}

@test "plain escape leaves the menu running" {
  run_menu ESC PAUSE 1 q
  [ "$status" -eq 0 ]
  assert_contains "$output" "[x] 1. claude-settings"
  assert_home_empty
}

@test "module labels render with hotkeys and live counts" {
  run_menu q
  [ "$status" -eq 0 ]
  assert_contains "$output" "── claude (c) · 0/3"
  assert_contains "$output" "── wezterm (w) · 0/1"
  assert_contains "$output" "── zsh (z) · 0/8"
  assert_contains "$output" "c/w/z fill/clear module"
}

@test "the title shows a live selection counter" {
  run_menu 1 q
  [ "$status" -eq 0 ]
  assert_contains "$output" "icaro-personal-computer-setup · 0/12 selected"
  assert_contains "$output" "icaro-personal-computer-setup · 1/12 selected"
  assert_home_empty
}

@test "z fills every zsh component and nothing else" {
  run_menu z q
  [ "$status" -eq 0 ]
  assert_contains "$output" "── zsh (z) · 8/8"
  assert_contains "$output" "[x] 5. zsh-core"
  assert_contains "$output" "[x] 12. bat"
  refute_contains "$output" "[x] 1."
  refute_contains "$output" "[x] 4."
  assert_home_empty
}

@test "pressing the module key twice selects nothing" {
  run_menu z z ENTER
  [ "$status" -eq 0 ]
  assert_contains "$output" "nothing selected"
  assert_home_empty
}

@test "a partially selected module fills on its key" {
  run_menu 6 z ENTER
  [ "$status" -eq 0 ]
  assert_file_equals "$FAKE_HOME/.zshrc" "$(rendered_zshrc_template)"
  [ ! -e "$FAKE_HOME/.wezterm.lua" ]
}

@test "partial module counts render live" {
  run_menu 5 q
  [ "$status" -eq 0 ]
  assert_contains "$output" "── zsh (z) · 1/8"
  assert_home_empty
}

@test "uppercase module keys toggle too" {
  run_menu Z q
  [ "$status" -eq 0 ]
  assert_contains "$output" "── zsh (z) · 8/8"
  assert_home_empty
}

@test "the claude module key installs only claude components" {
  run_menu c ENTER
  [ "$status" -eq 0 ]
  assert_file_equals "$FAKE_HOME/.claude/CLAUDE.md" "$REPO_ROOT/modules/claude/CLAUDE.md"
  assert_file_equals "$FAKE_HOME/.claude/statusline.sh" "$REPO_ROOT/modules/claude/statusline.sh"
  assert_file_equals "$FAKE_HOME/.claude/hooks/notify.sh" "$REPO_ROOT/modules/claude/hooks/notify.sh"
  [ ! -e "$FAKE_HOME/.zshrc" ]
  [ ! -e "$FAKE_HOME/.wezterm.lua" ]
}

@test "unchecking zsh-core after a module fill re-adds it at install time" {
  run_menu z 5 ENTER
  [ "$status" -eq 0 ]
  assert_contains "$output" "zsh-git requires zsh-core; selecting it"
  assert_file_equals "$FAKE_HOME/.zshrc" "$(rendered_zshrc_template)"
}

@test "a checked dependent marks zsh-core as implied" {
  run_menu 6 q
  [ "$status" -eq 0 ]
  assert_contains "$output" "[+] 5. zsh-core"
  assert_home_empty
}

@test "redraw erases the full menu height" {
  run_menu z q
  [ "$status" -eq 0 ]
  assert_contains "$output" $'\033[20A\033[J'
}

@test "no rendered menu line exceeds 80 columns" {
  run_menu z q
  [ "$status" -eq 0 ]
  stripped="$(printf '%s' "$output" | tr -d '\r' | grep -v '^spawn ' | sed -e $'s/\033\\[[0-9;?]*[A-Za-z]//g' -e 's/─/-/g' -e 's/·/./g' -e 's/↑/^/g' -e 's/↓/v/g')"
  longest="$(awk '{ if (length($0) > max) max = length($0) } END { print max + 0 }' <<<"$stripped")"
  [ "$longest" -le 80 ]
}

@test "module keys work after a plain escape" {
  run_menu ESC PAUSE z q
  [ "$status" -eq 0 ]
  assert_contains "$output" "── zsh (z) · 8/8"
  assert_home_empty
}

@test "modified arrow keys leave the selection untouched" {
  run_menu $'\033[1;2C' $'\033[1;5C' q
  [ "$status" -eq 0 ]
  refute_contains "$output" "[x]"
  assert_home_empty
}
