#!/usr/bin/env bash
# Claude Code "Notification" hook.
# Fires when Claude wants your attention: permission_prompt, idle_prompt,
# agent_needs_input, etc. (see stdin JSON `.message` / notification type).
#
# Its ONE job: play a DISTINCT sound so a Claude alert is recognizable by ear,
# separate from WezTerm's generic bell sound (Blow, in ~/.wezterm.lua).
# The visible banner is handled by WezTerm's OSC 9 toast (preferredNotifChannel
# = "iterm2"), so we don't show one here — that would double up.
#
# Swap Submarine.aiff for any file in /System/Library/Sounds (Glass, Ping, ...).

cat >/dev/null 2>&1   # drain stdin so Claude doesn't see a broken pipe

if [ "$(uname)" = "Darwin" ]; then
  afplay /System/Library/Sounds/Submarine.aiff >/dev/null 2>&1 &
fi

exit 0
