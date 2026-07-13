#!/usr/bin/env bats

setup() {
  load 'helpers/common'
  sandbox_setup
}

@test "--all --dry-run exits 0 and announces the dry run" {
  run_install --all --dry-run
  [ "$status" -eq 0 ]
  assert_contains "$output" "dry run: no changes will be made"
  assert_contains "$output" "dry run complete: nothing was changed"
}

@test "--all --dry-run leaves the sandbox home empty" {
  run_install --all --dry-run
  [ "$status" -eq 0 ]
  assert_home_empty
}

@test "--all --dry-run previews every link" {
  run_install --all --dry-run
  [ "$status" -eq 0 ]
  assert_contains "$output" "would link $FAKE_HOME/.claude/CLAUDE.md -> $REPO_ROOT/modules/claude/CLAUDE.md"
  assert_contains "$output" "would link $FAKE_HOME/.claude/settings.json -> $REPO_ROOT/modules/claude/settings.json"
  assert_contains "$output" "would link $FAKE_HOME/.claude/statusline.sh -> $REPO_ROOT/modules/claude/statusline.sh"
  assert_contains "$output" "would link $FAKE_HOME/.claude/hooks/notify.sh -> $REPO_ROOT/modules/claude/hooks/notify.sh"
  assert_contains "$output" "would link $FAKE_HOME/.wezterm.lua -> $REPO_ROOT/modules/wezterm/wezterm.lua"
  assert_contains "$output" "would link $FAKE_HOME/.zshrc -> $REPO_ROOT/modules/zsh/zshrc"
  assert_contains "$output" "would link $FAKE_HOME/.zprofile -> $REPO_ROOT/modules/zsh/zprofile"
  assert_contains "$output" "would link $FAKE_HOME/.p10k.zsh -> $REPO_ROOT/modules/zsh/p10k.zsh"
}

@test "--all --dry-run only queries brew and never installs" {
  run_install --all --dry-run
  [ "$status" -eq 0 ]
  assert_calls_contain "brew list --formula jq"
  refute_calls_contain "brew install"
  refute_calls_contain "curl"
  refute_calls_contain "git"
}

@test "--dry-run reports the backup it would keep without moving the file" {
  printf 'original\n' >"$FAKE_HOME/.zshrc"
  run_install --dry-run zsh
  [ "$status" -eq 0 ]
  assert_contains "$output" "would keep existing $FAKE_HOME/.zshrc as $FAKE_HOME/.zshrc-backup"
  [ -f "$FAKE_HOME/.zshrc" ]
  [ ! -e "$FAKE_HOME/.zshrc-backup" ]
  [ "$(cat "$FAKE_HOME/.zshrc")" = "original" ]
}
