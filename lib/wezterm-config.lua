-- Touchstone — WezTerm dynamic config
-- Terminator-style: dark theme, visible pane dividers, full OS decorations
local wezterm = require 'wezterm'
local config = wezterm.config_builder()

-- ── Window ──────────────────────────────────────────────────────────
-- Do NOT set window_decorations — let the OS/WM provide full decorations
-- (title bar, close/min/max buttons, resize borders)
config.window_padding = { left = 2, right = 2, top = 2, bottom = 2 }
config.initial_cols = 90
config.initial_rows = 35
config.window_close_confirmation = "NeverPrompt"
config.adjust_window_size_when_changing_font_size = false

-- ── Tab bar: hidden ─────────────────────────────────────────────────
config.enable_tab_bar = false
config.use_fancy_tab_bar = false

-- ── Theme: dark, Terminator-like ────────────────────────────────────
config.color_scheme = "Tango (terminal.sexy)"
config.colors = {
  background = "#171421",
  foreground = "#d0cfcc",
  cursor_bg = "#d0cfcc",
  cursor_fg = "#171421",
  selection_bg = "#264f78",
  selection_fg = "#ffffff",
  split = "#555753",
}

-- ── Font ────────────────────────────────────────────────────────────
config.font_size = 10.0

-- ── Inactive pane dimming ───────────────────────────────────────────
config.inactive_pane_hsb = {
  saturation = 0.85,
  brightness = 0.7,
}

-- ── Keybindings: Terminator-style + Touchstone pane switching ───────
config.keys = {
  -- Terminator splits
  { key = "o", mods = "CTRL|SHIFT", action = wezterm.action.SplitHorizontal { domain = "CurrentPaneDomain" } },
  { key = "e", mods = "CTRL|SHIFT", action = wezterm.action.SplitVertical { domain = "CurrentPaneDomain" } },
  { key = "w", mods = "CTRL|SHIFT", action = wezterm.action.CloseCurrentPane { confirm = false } },

  -- Pane navigation (Alt+Arrow)
  { key = "LeftArrow",  mods = "ALT", action = wezterm.action.ActivatePaneDirection "Left" },
  { key = "RightArrow", mods = "ALT", action = wezterm.action.ActivatePaneDirection "Right" },
  { key = "UpArrow",    mods = "ALT", action = wezterm.action.ActivatePaneDirection "Up" },
  { key = "DownArrow",  mods = "ALT", action = wezterm.action.ActivatePaneDirection "Down" },

  -- Pane resize (Ctrl+Shift+Arrow)
  { key = "LeftArrow",  mods = "CTRL|SHIFT", action = wezterm.action.AdjustPaneSize { "Left", 3 } },
  { key = "RightArrow", mods = "CTRL|SHIFT", action = wezterm.action.AdjustPaneSize { "Right", 3 } },
  { key = "UpArrow",    mods = "CTRL|SHIFT", action = wezterm.action.AdjustPaneSize { "Up", 3 } },
  { key = "DownArrow",  mods = "CTRL|SHIFT", action = wezterm.action.AdjustPaneSize { "Down", 3 } },

  -- Touchstone quick pane jump (Ctrl+1/2/3)
  { key = "1", mods = "CTRL", action = wezterm.action.ActivatePaneByIndex(0) },
  { key = "2", mods = "CTRL", action = wezterm.action.ActivatePaneByIndex(1) },
  { key = "3", mods = "CTRL", action = wezterm.action.ActivatePaneByIndex(2) },

  -- Zoom/maximize current pane (Ctrl+Shift+X)
  { key = "x", mods = "CTRL|SHIFT", action = wezterm.action.TogglePaneZoomState },

  -- Scrollback
  { key = "PageUp",   mods = "SHIFT", action = wezterm.action.ScrollByPage(-1) },
  { key = "PageDown", mods = "SHIFT", action = wezterm.action.ScrollByPage(1) },
}

-- ── Mouse: click to focus pane ──────────────────────────────────────
config.pane_focus_follows_mouse = true

return config
