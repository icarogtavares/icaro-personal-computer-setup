#!/usr/bin/env bats

setup() {
  load 'helpers/common'
  sandbox_setup
}

@test "zsh module writes the zsh dotfiles" {
  run_install --skip-deps zsh
  [ "$status" -eq 0 ]
  assert_file_equals "$FAKE_HOME/.zshrc" "$(rendered_zshrc_template)"
  assert_file_equals "$FAKE_HOME/.zprofile" "$REPO_ROOT/modules/zsh/zprofile"
  assert_file_equals "$FAKE_HOME/.p10k.zsh" "$REPO_ROOT/modules/zsh/p10k.zsh"
}

@test "claude module writes all four files including the hooks dir" {
  run_install --skip-deps claude
  [ "$status" -eq 0 ]
  assert_file_equals "$FAKE_HOME/.claude/CLAUDE.md" "$REPO_ROOT/modules/claude/CLAUDE.md"
  assert_regular_file "$FAKE_HOME/.claude/settings.json"
  assert_valid_json "$FAKE_HOME/.claude/settings.json"
  assert_file_equals "$FAKE_HOME/.claude/statusline.sh" "$REPO_ROOT/modules/claude/statusline.sh"
  assert_file_equals "$FAKE_HOME/.claude/hooks/notify.sh" "$REPO_ROOT/modules/claude/hooks/notify.sh"
}

@test "copied scripts keep their executable bit" {
  run_install --skip-deps claude
  [ "$status" -eq 0 ]
  assert_executable "$FAKE_HOME/.claude/statusline.sh"
  assert_executable "$FAKE_HOME/.claude/hooks/notify.sh"
}

@test "wezterm module writes the wezterm config" {
  run_install --skip-deps wezterm
  [ "$status" -eq 0 ]
  assert_file_equals "$FAKE_HOME/.wezterm.lua" "$REPO_ROOT/modules/wezterm/wezterm.lua"
}

@test "--all creates every file" {
  run_install --skip-deps --all
  [ "$status" -eq 0 ]
  assert_file_equals "$FAKE_HOME/.claude/CLAUDE.md" "$REPO_ROOT/modules/claude/CLAUDE.md"
  assert_regular_file "$FAKE_HOME/.claude/settings.json"
  assert_file_equals "$FAKE_HOME/.claude/statusline.sh" "$REPO_ROOT/modules/claude/statusline.sh"
  assert_file_equals "$FAKE_HOME/.claude/hooks/notify.sh" "$REPO_ROOT/modules/claude/hooks/notify.sh"
  assert_file_equals "$FAKE_HOME/.wezterm.lua" "$REPO_ROOT/modules/wezterm/wezterm.lua"
  assert_file_equals "$FAKE_HOME/.zshrc" "$(rendered_zshrc_template)"
  assert_file_equals "$FAKE_HOME/.zprofile" "$REPO_ROOT/modules/zsh/zprofile"
  assert_file_equals "$FAKE_HOME/.p10k.zsh" "$REPO_ROOT/modules/zsh/p10k.zsh"
}

@test "second run is idempotent and reports already up to date" {
  run_install --skip-deps zsh
  [ "$status" -eq 0 ]
  run_install --skip-deps zsh
  [ "$status" -eq 0 ]
  assert_contains "$output" "already up to date: $FAKE_HOME/.zshrc"
  assert_contains "$output" "already up to date: $FAKE_HOME/.zprofile"
  [ ! -e "$FAKE_HOME/.zshrc-backup" ]
  [ ! -e "$FAKE_HOME/.zprofile-backup" ]
}

@test "an existing generated file is kept as a backup before writing" {
  printf 'mine\n' >"$FAKE_HOME/.zshrc"
  run_install --skip-deps zsh
  [ "$status" -eq 0 ]
  assert_contains "$output" "kept existing $FAKE_HOME/.zshrc as $FAKE_HOME/.zshrc-backup"
  assert_file_equals "$FAKE_HOME/.zshrc" "$(rendered_zshrc_template)"
  [ "$(cat "$FAKE_HOME/.zshrc-backup")" = "mine" ]
}

@test "an existing copied file is kept as a backup before copying" {
  printf 'mine\n' >"$FAKE_HOME/.zprofile"
  run_install --skip-deps zsh
  [ "$status" -eq 0 ]
  assert_contains "$output" "kept existing $FAKE_HOME/.zprofile as $FAKE_HOME/.zprofile-backup"
  assert_file_equals "$FAKE_HOME/.zprofile" "$REPO_ROOT/modules/zsh/zprofile"
  [ "$(cat "$FAKE_HOME/.zprofile-backup")" = "mine" ]
}

@test "a second backup gets a timestamp suffix and the first is untouched" {
  printf 'first\n' >"$FAKE_HOME/.zshrc-backup"
  printf 'second\n' >"$FAKE_HOME/.zshrc"
  run_install --skip-deps zsh
  [ "$status" -eq 0 ]
  [ "$(cat "$FAKE_HOME/.zshrc-backup")" = "first" ]
  local stamped
  stamped="$(compgen -G "$FAKE_HOME/.zshrc-backup-2*")"
  [ -n "$stamped" ]
  [ "$(cat "$stamped")" = "second" ]
  assert_file_equals "$FAKE_HOME/.zshrc" "$(rendered_zshrc_template)"
}

@test "a symlink pointing elsewhere is backed up and replaced" {
  printf 'other\n' >"$FAKE_HOME/other-zshrc"
  ln -s "$FAKE_HOME/other-zshrc" "$FAKE_HOME/.zshrc"
  run_install --skip-deps zsh
  [ "$status" -eq 0 ]
  assert_file_equals "$FAKE_HOME/.zshrc" "$(rendered_zshrc_template)"
  assert_symlink "$FAKE_HOME/.zshrc-backup" "$FAKE_HOME/other-zshrc"
}

@test "backups preserve the original content" {
  printf 'precious\n' >"$FAKE_HOME/.wezterm.lua"
  run_install --skip-deps wezterm
  [ "$status" -eq 0 ]
  [ "$(cat "$FAKE_HOME/.wezterm.lua-backup")" = "precious" ]
  assert_file_equals "$FAKE_HOME/.wezterm.lua" "$REPO_ROOT/modules/wezterm/wezterm.lua"
}
