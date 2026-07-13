#!/usr/bin/env bats

setup() {
  load 'helpers/common'
  sandbox_setup
}

@test "zsh module links the zsh dotfiles" {
  run_install --skip-deps zsh
  [ "$status" -eq 0 ]
  assert_symlink "$FAKE_HOME/.zshrc" "$REPO_ROOT/zsh/zshrc"
  assert_symlink "$FAKE_HOME/.zprofile" "$REPO_ROOT/zsh/zprofile"
  assert_symlink "$FAKE_HOME/.p10k.zsh" "$REPO_ROOT/zsh/p10k.zsh"
}

@test "claude module links all five files including the hooks dir" {
  run_install --skip-deps claude
  [ "$status" -eq 0 ]
  assert_symlink "$FAKE_HOME/.claude/CLAUDE.md" "$REPO_ROOT/claude/CLAUDE.md"
  assert_symlink "$FAKE_HOME/.claude/RTK.md" "$REPO_ROOT/claude/RTK.md"
  assert_symlink "$FAKE_HOME/.claude/settings.json" "$REPO_ROOT/claude/settings.json"
  assert_symlink "$FAKE_HOME/.claude/statusline.sh" "$REPO_ROOT/claude/statusline.sh"
  assert_symlink "$FAKE_HOME/.claude/hooks/notify.sh" "$REPO_ROOT/claude/hooks/notify.sh"
}

@test "wezterm module links the wezterm config" {
  run_install --skip-deps wezterm
  [ "$status" -eq 0 ]
  assert_symlink "$FAKE_HOME/.wezterm.lua" "$REPO_ROOT/wezterm/wezterm.lua"
}

@test "--all creates every link" {
  run_install --skip-deps --all
  [ "$status" -eq 0 ]
  assert_symlink "$FAKE_HOME/.claude/CLAUDE.md" "$REPO_ROOT/claude/CLAUDE.md"
  assert_symlink "$FAKE_HOME/.claude/RTK.md" "$REPO_ROOT/claude/RTK.md"
  assert_symlink "$FAKE_HOME/.claude/settings.json" "$REPO_ROOT/claude/settings.json"
  assert_symlink "$FAKE_HOME/.claude/statusline.sh" "$REPO_ROOT/claude/statusline.sh"
  assert_symlink "$FAKE_HOME/.claude/hooks/notify.sh" "$REPO_ROOT/claude/hooks/notify.sh"
  assert_symlink "$FAKE_HOME/.wezterm.lua" "$REPO_ROOT/wezterm/wezterm.lua"
  assert_symlink "$FAKE_HOME/.zshrc" "$REPO_ROOT/zsh/zshrc"
  assert_symlink "$FAKE_HOME/.zprofile" "$REPO_ROOT/zsh/zprofile"
  assert_symlink "$FAKE_HOME/.p10k.zsh" "$REPO_ROOT/zsh/p10k.zsh"
}

@test "second run is idempotent and reports already linked" {
  run_install --skip-deps zsh
  [ "$status" -eq 0 ]
  run_install --skip-deps zsh
  [ "$status" -eq 0 ]
  assert_contains "$output" "already linked: $FAKE_HOME/.zshrc"
  assert_symlink "$FAKE_HOME/.zshrc" "$REPO_ROOT/zsh/zshrc"
  [ ! -e "$FAKE_HOME/.zshrc-backup" ]
}

@test "an existing file is kept as a backup before linking" {
  printf 'mine\n' >"$FAKE_HOME/.zshrc"
  run_install --skip-deps zsh
  [ "$status" -eq 0 ]
  assert_contains "$output" "kept existing $FAKE_HOME/.zshrc as $FAKE_HOME/.zshrc-backup"
  assert_symlink "$FAKE_HOME/.zshrc" "$REPO_ROOT/zsh/zshrc"
  [ "$(cat "$FAKE_HOME/.zshrc-backup")" = "mine" ]
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
  assert_symlink "$FAKE_HOME/.zshrc" "$REPO_ROOT/zsh/zshrc"
}

@test "a symlink pointing elsewhere is backed up and relinked" {
  printf 'other\n' >"$FAKE_HOME/other-zshrc"
  ln -s "$FAKE_HOME/other-zshrc" "$FAKE_HOME/.zshrc"
  run_install --skip-deps zsh
  [ "$status" -eq 0 ]
  assert_symlink "$FAKE_HOME/.zshrc" "$REPO_ROOT/zsh/zshrc"
  assert_symlink "$FAKE_HOME/.zshrc-backup" "$FAKE_HOME/other-zshrc"
}

@test "backups preserve the original content" {
  printf 'precious\n' >"$FAKE_HOME/.wezterm.lua"
  run_install --skip-deps wezterm
  [ "$status" -eq 0 ]
  [ "$(cat "$FAKE_HOME/.wezterm.lua-backup")" = "precious" ]
  assert_symlink "$FAKE_HOME/.wezterm.lua" "$REPO_ROOT/wezterm/wezterm.lua"
}
