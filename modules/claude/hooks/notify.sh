#!/usr/bin/env bash
# Claude Code hook dispatcher. settings.json wires every event here with an
# action argument so the hot path never parses JSON:
#   notify.sh notification   Notification: waiting for approval/input
#   notify.sh stop           Stop: turn finished
#   notify.sh clear          UserPromptSubmit/PostToolUse/SessionStart/SessionEnd
# Without an argument the action is derived from stdin's .hook_event_name (jq).
#
# Two jobs:
#   1. Publish the state to WezTerm as an OSC 1337 user var (claude_status =
#      waiting | done | empty-to-clear) written to the pane tty; ~/.wezterm.lua
#      turns it into tab icons and the leader+a jump target. CLAUDE_NOTIFY_TTY
#      overrides the target so tests never touch a real terminal.
#   2. Play a DISTINCT sound (Submarine) on Notification, separate from the
#      generic bell sound (Blow) in ~/.wezterm.lua. The visible banner stays
#      Claude's own OSC 9 toast (preferredNotifChannel = "iterm2"), so none is
#      shown here — that would double up.

ACTION="${1:-}"

PANE_ID="${WEZTERM_PANE:-}"
case "$PANE_ID" in
  *[!0-9]*) PANE_ID="" ;;
esac

have() {
  command -v "$1" >/dev/null 2>&1
}

pane_tty() {
  if [ -n "${CLAUDE_NOTIFY_TTY:-}" ]; then
    printf '%s' "$CLAUDE_NOTIFY_TTY"
    return 0
  fi
  if { : >/dev/tty; } 2>/dev/null; then
    printf '%s' /dev/tty
    return 0
  fi
  if [ -z "$PANE_ID" ] || ! have wezterm || ! have jq; then
    return 1
  fi
  wezterm cli list --format json 2>/dev/null |
    jq -r --argjson pane "$PANE_ID" \
      'first(.[] | select(.pane_id == $pane) | .tty_name) // empty' 2>/dev/null
}

set_status() {
  local tty encoded
  tty="$(pane_tty)" || return 0
  [ -n "$tty" ] || return 0
  encoded="$(printf '%s' "$1" | base64 | tr -d '\n')"
  printf '\033]1337;SetUserVar=claude_status=%s\007' "$encoded" >"$tty" 2>/dev/null || true
}

play_sound() {
  if have afplay; then
    afplay /System/Library/Sounds/Submarine.aiff >/dev/null 2>&1 &
  fi
}

if [ -z "$ACTION" ]; then
  PAYLOAD="$(cat 2>/dev/null || true)"
  if have jq; then
    EVENT="$(printf '%s' "$PAYLOAD" | jq -r '.hook_event_name // empty' 2>/dev/null || true)"
    case "$EVENT" in
      Notification) ACTION="notification" ;;
      Stop) ACTION="stop" ;;
      UserPromptSubmit | PostToolUse | SessionStart | SessionEnd) ACTION="clear" ;;
    esac
  fi
elif [ ! -t 0 ]; then
  cat >/dev/null 2>&1
fi

case "$ACTION" in
  notification)
    set_status waiting
    play_sound
    ;;
  stop)
    set_status "done"
    ;;
  clear)
    set_status ""
    ;;
esac

exit 0
