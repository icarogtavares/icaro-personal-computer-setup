#!/usr/bin/env bats

setup() {
  load 'helpers/common'
  sandbox_setup
}

@test "--skip-deps --all records no tool invocations" {
  run_install --skip-deps --all
  [ "$status" -eq 0 ]
  assert_no_calls
}

@test "SETUP_SKIP_DEPS=1 behaves like --skip-deps" {
  run_install_env SETUP_SKIP_DEPS=1 --all
  [ "$status" -eq 0 ]
  assert_no_calls
  assert_symlink "$FAKE_HOME/.zshrc" "$REPO_ROOT/modules/zsh/zshrc"
}

@test "claude installs jq through brew when missing" {
  run_install claude
  [ "$status" -eq 0 ]
  assert_calls_contain "brew list --formula jq"
  assert_calls_contain "brew install jq"
}

@test "claude skips brew installs when brew reports them installed" {
  set_brew_list_exit 0
  run_install claude
  [ "$status" -eq 0 ]
  assert_contains "$output" "jq already installed"
  refute_calls_contain "brew install jq"
}

@test "wezterm installs the nerd font casks" {
  run_install wezterm
  [ "$status" -eq 0 ]
  assert_calls_contain "brew install --cask font-meslo-lg-nerd-font"
  assert_calls_contain "brew install --cask font-hack-nerd-font"
  assert_calls_contain "brew install --cask font-symbols-only-nerd-font"
}

@test "wezterm installs the app cask when the bundle is missing" {
  run_install wezterm
  [ "$status" -eq 0 ]
  assert_calls_contain "brew install --cask wezterm"
}

@test "wezterm skips the app cask when the bundle exists" {
  mkdir -p "$FAKE_WEZTERM_APP"
  run_install wezterm
  [ "$status" -eq 0 ]
  assert_contains "$output" "WezTerm.app already installed"
  refute_calls_contain "brew install --cask wezterm"
}

@test "claude fetches the claude installer when the binary is absent" {
  run_install claude
  [ "$status" -eq 0 ]
  assert_calls_contain "curl -fsSL https://claude.ai/install.sh"
}

@test "a failing claude installer download executes nothing" {
  make_failing_curl_stub 23 "echo claude-partial >>'$STATE_DIR/calls.log'"
  run_install claude
  [ "$status" -ne 0 ]
  assert_calls_contain "curl -fsSL https://claude.ai/install.sh"
  refute_calls_contain "claude-partial"
}

@test "claude skips the installer when a claude binary is on the path" {
  make_stub claude
  run_install claude
  [ "$status" -eq 0 ]
  assert_contains "$output" "Claude Code already installed"
  refute_calls_contain "claude.ai/install.sh"
}

@test "zsh installs oh my zsh and clones the theme and plugins" {
  run_install zsh
  [ "$status" -eq 0 ]
  assert_calls_contain "curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh"
  assert_calls_contain "git clone --depth=1 https://github.com/romkatv/powerlevel10k.git $FAKE_HOME/.oh-my-zsh/custom/themes/powerlevel10k"
  assert_calls_contain "git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions.git $FAKE_HOME/.oh-my-zsh/custom/plugins/zsh-autosuggestions"
  assert_calls_contain "git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting.git $FAKE_HOME/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting"
}

@test "zsh skips oh my zsh and the clones when already present" {
  mkdir -p "$FAKE_HOME/.oh-my-zsh/custom/themes/powerlevel10k"
  mkdir -p "$FAKE_HOME/.oh-my-zsh/custom/plugins/zsh-autosuggestions"
  mkdir -p "$FAKE_HOME/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting"
  run_install zsh
  [ "$status" -eq 0 ]
  assert_contains "$output" "Oh My Zsh already installed"
  assert_contains "$output" "powerlevel10k already present"
  refute_calls_contain "git clone"
  refute_calls_contain "ohmyzsh"
}

@test "zsh installs the shell tooling through brew" {
  run_install zsh
  [ "$status" -eq 0 ]
  assert_calls_contain "brew install fzf"
  assert_calls_contain "brew install eza"
  assert_calls_contain "brew install bat"
  assert_calls_contain "brew install zoxide"
}
