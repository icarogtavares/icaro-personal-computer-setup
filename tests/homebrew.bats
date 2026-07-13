#!/usr/bin/env bats

setup() {
  load 'helpers/common'
  sandbox_setup
  remove_stub brew
}

@test "declining the homebrew prompt skips deps and still links" {
  run_install_stdin n claude
  [ "$status" -eq 0 ]
  assert_contains "$output" "skipping dependency installation (Homebrew unavailable)"
  assert_symlink "$FAKE_HOME/.claude/CLAUDE.md" "$REPO_ROOT/claude/CLAUDE.md"
  refute_calls_contain "brew list"
  refute_calls_contain "brew install"
}

@test "--yes runs the homebrew installer and dies when brew is still missing" {
  run_install --yes claude
  [ "$status" -eq 1 ]
  assert_calls_contain "curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh"
  assert_contains "$output" "Homebrew installation did not complete"
}

@test "dry run without homebrew previews the homebrew install" {
  run_install --dry-run claude
  [ "$status" -eq 0 ]
  assert_contains "$output" "would install Homebrew"
}

@test "the homebrew prompt is printed before reading the answer" {
  run_install_stdin n claude
  [ "$status" -eq 0 ]
  assert_contains "$output" "Homebrew is required for dependencies. Install it now? [y/N]"
}

@test "the homebrew prompt is asked at most once per run" {
  run_install_stdin n --all
  [ "$status" -eq 0 ]
  [ "$(grep -c 'Install it now?' <<<"$output")" -eq 1 ]
  assert_symlink "$FAKE_HOME/.wezterm.lua" "$REPO_ROOT/wezterm/wezterm.lua"
  assert_symlink "$FAKE_HOME/.zshrc" "$REPO_ROOT/zsh/zshrc"
}

@test "an existing brew prefix is discovered and activated" {
  make_brew_prefix
  run_install claude
  [ "$status" -eq 0 ]
  refute_contains "$output" "Install it now?"
  assert_calls_contain "brew shellenv"
  assert_calls_contain "brew install jq"
  assert_symlink "$FAKE_HOME/.claude/CLAUDE.md" "$REPO_ROOT/claude/CLAUDE.md"
}

@test "accepting the homebrew prompt installs and activates brew" {
  stage_homebrew_install
  run_install_stdin y claude
  [ "$status" -eq 0 ]
  assert_contains "$output" "Install it now?"
  assert_calls_contain "curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh"
  assert_calls_contain "brew shellenv"
  assert_calls_contain "brew install jq"
}

@test "--yes installs homebrew without prompting" {
  stage_homebrew_install
  run_install --yes claude
  [ "$status" -eq 0 ]
  refute_contains "$output" "Install it now?"
  assert_calls_contain "brew install jq"
}
