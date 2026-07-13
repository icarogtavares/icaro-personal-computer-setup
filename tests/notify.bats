#!/usr/bin/env bats

setup() {
  load 'helpers/common'
  sandbox_setup
  if command -v jq >/dev/null 2>&1; then
    ln -s "$(command -v jq)" "$STUB_BIN/jq"
  fi
  : >"$STATE_DIR/tty.out"
}

tty_out() {
  cat "$STATE_DIR/tty.out"
}

@test "notification action writes the waiting user var to the tty target" {
  run_hook '{"hook_event_name":"Notification","message":"needs approval"}' notification
  [ "$status" -eq 0 ]
  assert_contains "$(tty_out)" $'\033]1337;SetUserVar=claude_status=d2FpdGluZw==\007'
}

@test "stop action writes the done user var" {
  run_hook '{"hook_event_name":"Stop"}' stop
  [ "$status" -eq 0 ]
  assert_contains "$(tty_out)" $'\033]1337;SetUserVar=claude_status=ZG9uZQ==\007'
}

@test "clear action writes an empty user var" {
  run_hook '{"hook_event_name":"UserPromptSubmit"}' clear
  [ "$status" -eq 0 ]
  assert_contains "$(tty_out)" $'\033]1337;SetUserVar=claude_status=\007'
}

@test "the action argument never invokes jq" {
  remove_stub jq
  make_stub jq
  run_hook '{"hook_event_name":"Stop"}' stop
  [ "$status" -eq 0 ]
  assert_contains "$(tty_out)" $'\033]1337;SetUserVar=claude_status=ZG9uZQ==\007'
  refute_calls_contain "jq"
}

@test "the stdin event name is the fallback when no action argument is given" {
  [ -x "$STUB_BIN/jq" ] || skip "jq is required for the fallback path"
  run_hook '{"hook_event_name":"Stop"}'
  [ "$status" -eq 0 ]
  assert_contains "$(tty_out)" $'\033]1337;SetUserVar=claude_status=ZG9uZQ==\007'
}

@test "notification plays the submarine sound" {
  make_stub afplay
  run_hook '{}' notification
  [ "$status" -eq 0 ]
  for _ in {1..20}; do
    if grep -qF "afplay /System/Library/Sounds/Submarine.aiff" "$STATE_DIR/calls.log"; then
      break
    fi
    sleep 0.1
  done
  assert_calls_contain "afplay /System/Library/Sounds/Submarine.aiff"
}

@test "the pane tty resolves through wezterm cli when /dev/tty is unavailable" {
  if { : >/dev/tty; } 2>/dev/null; then
    skip "requires an environment without a controlling terminal"
  fi
  [ -x "$STUB_BIN/jq" ] || skip "jq is required for the tty lookup"
  make_wezterm_cli_stub
  make_stub afplay
  printf '[{"pane_id":7,"tty_name":"%s"}]' "$STATE_DIR/fake-tty" >"$STATE_DIR/panes.json"
  : >"$STATE_DIR/fake-tty"
  export HOOK_TTY=""
  run_hook '{}' notification
  [ "$status" -eq 0 ]
  assert_contains "$(cat "$STATE_DIR/fake-tty")" $'\033]1337;SetUserVar=claude_status=d2FpdGluZw==\007'
}

@test "garbage stdin without an action is a silent no-op" {
  [ -x "$STUB_BIN/jq" ] || skip "jq is required for the fallback path"
  make_stub afplay
  run_hook 'not json'
  [ "$status" -eq 0 ]
  [ ! -s "$STATE_DIR/tty.out" ]
  refute_calls_contain "afplay"
}
