local wezterm = require("wezterm")
local act = wezterm.action

local config = wezterm.config_builder()

local is_windows = os.getenv("OS") and os.getenv("OS"):lower():find("windows")
local is_macos = wezterm.target_triple:lower():find("darwin") ~= nil

-- ui
config.switch_to_last_active_tab_when_closing_tab = true
config.color_scheme = "rose-pine-moon"
config.max_fps = 120
config.font = wezterm.font_with_fallback({
  { family = "MesloLGS Nerd Font Mono", weight = "Regular" },
  "Symbols Nerd Font Mono", -- glyph fallback so icons never render as boxes
})
config.font_size = 13.0
config.line_height = 1.05
config.enable_tab_bar = true
config.hide_tab_bar_if_only_one_tab = false
config.window_decorations = "RESIZE"
config.window_padding = { left = 8, right = 8, top = 8, bottom = 4 }
config.window_frame = {
  font = wezterm.font("Hack Nerd Font", { weight = "Bold" }),
}
config.inactive_pane_hsb = {
  saturation = 0.0,
  brightness = 0.5,
}
config.scrollback_lines = 10000       -- default is 3500; you'll want more

-- Disabled here on purpose: the bell handler below owns the sound so it can be
-- distinct AND only fire when you're NOT already watching the pane. See the
-- NOTIFICATIONS section.
config.audible_bell = "Disabled"
-- config.visual_bell = {
--   target = "BackgroundColor",
--   fade_in_function = "EaseIn",
--   fade_in_duration_ms = 75,
--   fade_out_function = "EaseOut",
--   fade_out_duration_ms = 75,
-- }

if is_windows then
  config.win32_system_backdrop = "Acrylic"
  config.window_background_opacity = 0.7
  config.window_frame.font_size = 10.0
end

if is_macos then
  config.window_background_opacity = 0.8  -- lower opacity looks nice, reads worse
  config.macos_window_background_blur = 50
  config.font_size = 14.0
  config.window_frame.font_size = 13.0
end

-- ============ SHELL ============
if is_windows then
  config.default_domain = "WSL:Ubuntu-24.04"
end

-- ============ KEYS ============
config.disable_default_key_bindings = false
config.leader = { key = "Space", mods = "CTRL", timeout_milliseconds = 1000 }

wezterm.on("update-right-status", function(window, _)
  window:set_right_status(window:leader_is_active() and " LEADER " or "")
end)

-- ============ NOTIFICATIONS ============
-- Sound for a generic terminal bell from ANY program EXCEPT Claude Code.
-- Claude is routed separately (preferredNotifChannel = "iterm2" emits an OSC 9
-- toast that does NOT fire this bell event, and its Notification hook plays
-- Submarine) so the two are distinguishable by ear. Any file in
-- /System/Library/Sounds works: Glass, Ping, Hero, Submarine, Funk, Blow, Pop...
-- The same hook also publishes a claude_status user var per pane; the handlers
-- below the bell turn it into 🔔/✅ tab icons and the leader+a jump target.
local bell_sound = "/System/Library/Sounds/Blow.aiff"

-- A non-Claude program rang the terminal bell. We own the bell here (instead of
-- audible_bell) so we can:
--   1. show a native macOS notification,
--   2. play a distinct sound (Blow),
--   3. stay quiet when you're already looking at the pane that rang, and
--   4. still nudge when the window is focused but you're on a DIFFERENT tab
--      (macOS suppresses the banner for the frontmost app, so the sound is the
--      nudge in that case).
wezterm.on("bell", function(window, pane)
  -- Are you actually watching the pane that rang? Only true when the window is
  -- focused AND that pane is the active pane of the active tab.
  local active = window:active_pane()
  local watching = window:is_focused()
    and active ~= nil
    and active:pane_id() == pane:pane_id()

  if watching then
    return -- you can see it; don't make noise
  end

  window:toast_notification(
    "WezTerm",
    "🔔 " .. (pane:get_title() or "A pane") .. " needs your attention",
    nil,  -- no click-through URL
    5000  -- auto-dismiss after 5s
  )

  if is_macos then
    -- background_child_process = fire-and-forget, never blocks the UI
    wezterm.background_child_process({ "/usr/bin/afplay", bell_sound })
  end
end)

-- Claude Code attention state, published per pane by ~/.claude/hooks/notify.sh
-- as an OSC 1337 user var: claude_status = "waiting" | "done" | "" (clear).
-- Cached in wezterm.GLOBAL (survives config reloads) because format-tab-title
-- only exposes user vars for panes of the ACTIVE tab, and the whole point is
-- icons on BACKGROUND tabs. GLOBAL nested writes don't persist reliably, so
-- every mutation goes copy -> change -> whole-value reassignment.
local function read_claude_status()
  local copied = {}
  local stored = wezterm.GLOBAL.claude_status
  if stored then
    for key, entry in pairs(stored) do
      copied[key] = { status = entry.status, tab_id = entry.tab_id }
    end
  end
  return copied
end

wezterm.on("user-var-changed", function(_, pane, name, value)
  if name ~= "claude_status" then
    return
  end
  local state = read_claude_status()
  local key = tostring(pane:pane_id())
  if value == "" then
    state[key] = nil
  else
    local ok, tab = pcall(function()
      return pane:tab()
    end)
    state[key] = {
      status = value,
      tab_id = (ok and tab) and tab:tab_id() or -1,
    }
  end
  wezterm.GLOBAL.claude_status = state
end)

-- 🔔 beats ✅ when a tab hosts several claude panes.
local function claude_tab_icon(tab_id)
  local icon = ""
  for _, entry in pairs(read_claude_status()) do
    if entry.tab_id == tab_id then
      if entry.status == "waiting" then
        return "🔔 "
      elseif entry.status == "done" then
        icon = "✅ "
      end
    end
  end
  return icon
end

wezterm.on("format-tab-title", function(tab, _, _, _, _, max_width)
  local title = tab.tab_title
  if not title or #title == 0 then
    title = tab.active_pane.title
  end
  title = claude_tab_icon(tab.tab_id) .. title
  return " " .. wezterm.truncate_right(title, max_width - 2) .. " "
end)

-- Housekeeping on the ~1s update-right-status tick (every handler registered
-- for an event runs, so the LEADER one above is unaffected): drop entries for
-- dead panes, follow panes moved between tabs, and clear ✅ only once its tab
-- has actually been SEEN (window focused + tab active), mirroring the bell
-- handler's "watching" semantics.
wezterm.on("update-right-status", function(window, _)
  local state = read_claude_status()
  local changed = false
  local active_tab = window:active_tab()
  local active_tab_id = active_tab and active_tab:tab_id() or -1
  for key, entry in pairs(state) do
    local ok, mux_pane = pcall(wezterm.mux.get_pane, tonumber(key))
    if not ok or not mux_pane then
      state[key] = nil
      changed = true
    else
      local tab_ok, tab = pcall(function()
        return mux_pane:tab()
      end)
      local tab_id = (tab_ok and tab) and tab:tab_id() or entry.tab_id
      if entry.status == "done" and window:is_focused() and tab_id == active_tab_id then
        state[key] = nil
        changed = true
      elseif tab_id ~= entry.tab_id then
        entry.tab_id = tab_id
        changed = true
      end
    end
  end
  if changed then
    wezterm.GLOBAL.claude_status = state
  end
end)

config.keys = {
  -- clipboard
  { key = "v", mods = "CMD",    action = act.PasteFrom("Clipboard") },
  { key = "c", mods = "CMD",    action = act.CopyTo("Clipboard") },

  -- panes: splits (leader + \ and -)
  { key = "\\", mods = "LEADER", action = act.SplitHorizontal({ domain = "CurrentPaneDomain" }) },
  { key = "-", mods = "LEADER",       action = act.SplitVertical({ domain = "CurrentPaneDomain" }) },

  -- panes: navigate (leader + hjkl, vim-style)
  { key = "h", mods = "LEADER", action = act.ActivatePaneDirection("Left") },
  { key = "j", mods = "LEADER", action = act.ActivatePaneDirection("Down") },
  { key = "k", mods = "LEADER", action = act.ActivatePaneDirection("Up") },
  { key = "l", mods = "LEADER", action = act.ActivatePaneDirection("Right") },

  -- panes: resize (leader + arrows)
  { key = "LeftArrow",  mods = "LEADER", action = act.AdjustPaneSize({ "Left", 5 }) },
  { key = "DownArrow",  mods = "LEADER", action = act.AdjustPaneSize({ "Down", 5 }) },
  { key = "UpArrow",    mods = "LEADER", action = act.AdjustPaneSize({ "Up", 5 }) },
  { key = "RightArrow", mods = "LEADER", action = act.AdjustPaneSize({ "Right", 5 }) },

  -- panes: zoom / close
  { key = "z", mods = "LEADER", action = act.TogglePaneZoomState },
  { key = "x", mods = "LEADER", action = act.CloseCurrentPane({ confirm = true }) },

    -- font zoom (lost when defaults were disabled)
  { key = "=", mods = "CMD", action = act.IncreaseFontSize },
  { key = "-", mods = "CMD", action = act.DecreaseFontSize },
  { key = "0", mods = "CMD", action = act.ResetFontSize },

  -- tabs
  { key = "c", mods = "LEADER", action = act.SpawnTab("CurrentPaneDomain") },
  { key = "n", mods = "LEADER", action = act.ActivateTabRelative(1) },
  { key = "p", mods = "LEADER", action = act.ActivateTabRelative(-1) },

  -- productivity
  { key = "f", mods = "LEADER", action = act.Search({ CaseInSensitiveString = "" }) }, -- search scrollback
  { key = "[", mods = "LEADER", action = act.ActivateCopyMode },                        -- vim-like scrollback nav
  { key = "r", mods = "LEADER", action = act.ReloadConfiguration },
  { key = "w", mods = "LEADER", action = act.ShowLauncherArgs({ flags = "FUZZY|WORKSPACES" }) },

  -- jump to the claude session that wants you (🔔 first, ✅ as fallback)
  {
    key = "a",
    mods = "LEADER",
    action = wezterm.action_callback(function(_, _)
      local target
      for key, entry in pairs(read_claude_status()) do
        if entry.status == "waiting" then
          target = tonumber(key)
          break
        end
        target = target or tonumber(key)
      end
      if not target then
        return
      end
      local ok, mux_pane = pcall(wezterm.mux.get_pane, target)
      if not ok or not mux_pane then
        return
      end
      mux_pane:activate()
      local win_ok, gui_window = pcall(function()
        return mux_pane:window():gui_window()
      end)
      if win_ok and gui_window then
        gui_window:focus()
      end
    end),
  },

  -- rename the current tab
  { key = ",", mods = "LEADER", action = act.PromptInputLine({
    description = "New tab name:",
    action = wezterm.action_callback(function(window, _, line)
      if line then window:active_tab():set_title(line) end
    end),
  })},

  -- press CTRL+Space twice to send a *real* CTRL+Space to the shell
  { key = "Space", mods = "LEADER|CTRL", action = act.SendKey({ key = "Space", mods = "CTRL" }) },
}

config.hyperlink_rules = wezterm.default_hyperlink_rules()

-- quick pane switch with CMD/ALT + number (no leader needed)
for i = 1, 9 do
  table.insert(config.keys, {
    key = tostring(i),
    mods = is_macos and "CMD" or "ALT",
    action = act.ActivateTab(i - 1),
  })
end

-- ============ MOUSE ============
config.mouse_bindings = {
  -- CMD/CTRL + click opens hyperlinks
  {
    event = { Up = { streak = 1, button = "Left" } },
    mods = is_macos and "CMD" or "CTRL",
    action = act.OpenLinkAtMouseCursor,
  },
}

return config