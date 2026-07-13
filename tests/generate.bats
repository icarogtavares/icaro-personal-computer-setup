#!/usr/bin/env bats

setup() {
  load 'helpers/common'
  sandbox_setup
}

@test "the claude alias merges all three settings fragments" {
  run_install --skip-deps claude
  [ "$status" -eq 0 ]
  assert_regular_file "$FAKE_HOME/.claude/settings.json"
  assert_valid_json "$FAKE_HOME/.claude/settings.json"
  local settings
  settings="$(cat "$FAKE_HOME/.claude/settings.json")"
  assert_contains "$settings" '"attribution"'
  assert_contains "$settings" '"model"'
  assert_contains "$settings" '"statusLine"'
  assert_contains "$settings" '"hooks"'
  assert_contains "$settings" '"preferredNotifChannel"'
  assert_contains "$settings" '"inputNeededNotifEnabled"'
}

@test "claude-statusline alone writes only the statusLine setting" {
  run_install --skip-deps claude-statusline
  [ "$status" -eq 0 ]
  assert_valid_json "$FAKE_HOME/.claude/settings.json"
  local settings
  settings="$(cat "$FAKE_HOME/.claude/settings.json")"
  assert_contains "$settings" '"statusLine"'
  refute_contains "$settings" '"hooks"'
  refute_contains "$settings" '"attribution"'
  refute_contains "$settings" '"preferredNotifChannel"'
  assert_file_equals "$FAKE_HOME/.claude/statusline.sh" "$REPO_ROOT/modules/claude/statusline.sh"
  assert_executable "$FAKE_HOME/.claude/statusline.sh"
  [ ! -e "$FAKE_HOME/.claude/CLAUDE.md" ]
  [ ! -e "$FAKE_HOME/.claude/hooks/notify.sh" ]
}

@test "claude-notify alone writes hooks and notification prefs" {
  run_install --skip-deps claude-notify
  [ "$status" -eq 0 ]
  assert_valid_json "$FAKE_HOME/.claude/settings.json"
  local settings
  settings="$(cat "$FAKE_HOME/.claude/settings.json")"
  assert_contains "$settings" '"hooks"'
  assert_contains "$settings" '"agentPushNotifEnabled"'
  refute_contains "$settings" '"statusLine"'
  refute_contains "$settings" '"model"'
  assert_file_equals "$FAKE_HOME/.claude/hooks/notify.sh" "$REPO_ROOT/modules/claude/hooks/notify.sh"
  assert_executable "$FAKE_HOME/.claude/hooks/notify.sh"
}

@test "claude-settings without claude-notify omits the notification keys" {
  run_install --skip-deps claude-settings claude-statusline
  [ "$status" -eq 0 ]
  assert_valid_json "$FAKE_HOME/.claude/settings.json"
  local settings
  settings="$(cat "$FAKE_HOME/.claude/settings.json")"
  assert_contains "$settings" '"model"'
  assert_contains "$settings" '"statusLine"'
  refute_contains "$settings" '"hooks"'
  refute_contains "$settings" '"preferredNotifChannel"'
  [ ! -e "$FAKE_HOME/.claude/hooks/notify.sh" ]
}

@test "rewriting identical settings is idempotent" {
  run_install --skip-deps claude
  [ "$status" -eq 0 ]
  run_install --skip-deps claude
  [ "$status" -eq 0 ]
  assert_contains "$output" "already up to date: $FAKE_HOME/.claude/settings.json"
  [ ! -e "$FAKE_HOME/.claude/settings.json-backup" ]
}

@test "changing the claude selection backs up settings.json" {
  run_install --skip-deps claude-settings
  [ "$status" -eq 0 ]
  run_install --skip-deps claude-settings claude-notify
  [ "$status" -eq 0 ]
  assert_regular_file "$FAKE_HOME/.claude/settings.json-backup"
  refute_contains "$(cat "$FAKE_HOME/.claude/settings.json-backup")" '"hooks"'
  assert_contains "$(cat "$FAKE_HOME/.claude/settings.json")" '"hooks"'
}

@test "a stale settings.json symlink becomes a backed-up real file" {
  mkdir -p "$FAKE_HOME/.claude"
  ln -s "$REPO_ROOT/modules/claude/settings.json" "$FAKE_HOME/.claude/settings.json"
  run_install --skip-deps claude
  [ "$status" -eq 0 ]
  assert_regular_file "$FAKE_HOME/.claude/settings.json"
  assert_symlink "$FAKE_HOME/.claude/settings.json-backup" "$REPO_ROOT/modules/claude/settings.json"
}

@test "the zsh alias renders the template minus the section markers" {
  run_install --skip-deps zsh
  [ "$status" -eq 0 ]
  assert_file_equals "$FAKE_HOME/.zshrc" "$(rendered_zshrc_template)"
  refute_contains "$(cat "$FAKE_HOME/.zshrc")" "# >>>"
  refute_contains "$(cat "$FAKE_HOME/.zshrc")" "# <<<"
}

@test "zsh-core alone writes an empty plugins block" {
  run_install --skip-deps zsh-core
  [ "$status" -eq 0 ]
  refute_line_present "$FAKE_HOME/.zshrc" "  git"
  refute_line_present "$FAKE_HOME/.zshrc" "  zsh-autosuggestions"
  refute_line_present "$FAKE_HOME/.zshrc" "  zsh-syntax-highlighting"
  assert_line_present "$FAKE_HOME/.zshrc" "plugins=("
  assert_line_present "$FAKE_HOME/.zshrc" ")"
  assert_contains "$(cat "$FAKE_HOME/.zshrc")" "source \$ZSH/oh-my-zsh.sh"
}

@test "a single plugin keeps only its line" {
  run_install --skip-deps zsh-core zsh-autosuggestions
  [ "$status" -eq 0 ]
  assert_line_present "$FAKE_HOME/.zshrc" "  zsh-autosuggestions"
  refute_line_present "$FAKE_HOME/.zshrc" "  git"
  refute_line_present "$FAKE_HOME/.zshrc" "  zsh-syntax-highlighting"
}

@test "the plugin filter leaves the example comment untouched" {
  run_install --skip-deps zsh-core
  [ "$status" -eq 0 ]
  assert_contains "$(cat "$FAKE_HOME/.zshrc")" "plugins=(rails git textmate ruby lighthouse)"
}

@test "rewriting an identical zshrc is idempotent" {
  run_install --skip-deps zsh-core zsh-git
  [ "$status" -eq 0 ]
  run_install --skip-deps zsh-core zsh-git
  [ "$status" -eq 0 ]
  assert_contains "$output" "already up to date: $FAKE_HOME/.zshrc"
  [ ! -e "$FAKE_HOME/.zshrc-backup" ]
}

@test "a zshrc symlink with identical content becomes a real file" {
  local rendered
  rendered="$(rendered_zshrc_template)"
  ln -s "$rendered" "$FAKE_HOME/.zshrc"
  run_install --skip-deps zsh
  [ "$status" -eq 0 ]
  assert_file_equals "$FAKE_HOME/.zshrc" "$rendered"
  assert_symlink "$FAKE_HOME/.zshrc-backup" "$rendered"
}

@test "a zsh plugin auto-selects zsh-core" {
  run_install --skip-deps zsh-syntax-highlighting
  [ "$status" -eq 0 ]
  assert_contains "$output" "zsh-syntax-highlighting requires zsh-core; selecting it"
  assert_line_present "$FAKE_HOME/.zshrc" "  zsh-syntax-highlighting"
  assert_file_equals "$FAKE_HOME/.zprofile" "$REPO_ROOT/modules/zsh/zprofile"
  assert_file_equals "$FAKE_HOME/.p10k.zsh" "$REPO_ROOT/modules/zsh/p10k.zsh"
}

@test "explicit zsh-core with a plugin prints no auto-add notice" {
  run_install --skip-deps zsh-core zsh-git
  [ "$status" -eq 0 ]
  refute_contains "$output" "requires zsh-core"
}

@test "zsh-core alone omits every tool section" {
  run_install --skip-deps zsh-core
  [ "$status" -eq 0 ]
  local zshrc
  zshrc="$(cat "$FAKE_HOME/.zshrc")"
  refute_contains "$zshrc" "fzf --zsh"
  refute_contains "$zshrc" "zoxide init"
  refute_contains "$zshrc" "alias ls="
  refute_contains "$zshrc" "BAT_THEME"
  assert_contains "$zshrc" "source ~/.zshrc.local"
}

@test "a single tool keeps only its own section" {
  run_install --skip-deps zsh-core zoxide
  [ "$status" -eq 0 ]
  local zshrc
  zshrc="$(cat "$FAKE_HOME/.zshrc")"
  assert_line_present "$FAKE_HOME/.zshrc" "eval \"\$(zoxide init zsh --cmd cd)\""
  refute_contains "$zshrc" "fzf --zsh"
  refute_contains "$zshrc" "alias ls="
  refute_contains "$zshrc" "BAT_THEME"
}

@test "fzf without eza and bat omits the preview config" {
  run_install --skip-deps zsh-core fzf
  [ "$status" -eq 0 ]
  local zshrc
  zshrc="$(cat "$FAKE_HOME/.zshrc")"
  assert_contains "$zshrc" "source <(fzf --zsh)"
  refute_contains "$zshrc" "FZF_CTRL_T_OPTS"
  refute_contains "$zshrc" "_fzf_comprun"
}

@test "fzf with eza and bat keeps the preview config" {
  run_install --skip-deps zsh-core fzf eza bat
  [ "$status" -eq 0 ]
  local zshrc
  zshrc="$(cat "$FAKE_HOME/.zshrc")"
  assert_contains "$zshrc" "FZF_CTRL_T_OPTS"
  assert_contains "$zshrc" "_fzf_comprun"
  assert_line_present "$FAKE_HOME/.zshrc" "alias lt='eza --tree --level=2 --icons'"
  assert_line_present "$FAKE_HOME/.zshrc" 'export BAT_THEME="Visual Studio Dark+"'
}

@test "removed tool sections leave no doubled blank lines" {
  run_install --skip-deps zsh-core fzf
  [ "$status" -eq 0 ]
  run awk 'blank && !NF { exit 1 } { blank = !NF }' "$FAKE_HOME/.zshrc"
  [ "$status" -eq 0 ]
}

@test "a shell tool auto-selects zsh-core" {
  run_install --skip-deps fzf
  [ "$status" -eq 0 ]
  assert_contains "$output" "fzf requires zsh-core; selecting it"
  assert_contains "$(cat "$FAKE_HOME/.zshrc")" "source <(fzf --zsh)"
  assert_file_equals "$FAKE_HOME/.zprofile" "$REPO_ROOT/modules/zsh/zprofile"
}
