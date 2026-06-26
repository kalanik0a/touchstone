# Troubleshooting

## Window Has No Title Bar or Borders

**Symptom:** The WezTerm window opens without OS decorations (no title bar, no close/minimize/maximize buttons, no resize borders).

**Cause:** On Wayland compositors, WezTerm may default to client-side decorations or no decorations, bypassing the window manager.

**Fix:** Touchstone already sets `WAYLAND_DISPLAY=""` to force X11 mode via XWayland. If the issue persists, verify the config does not set `window_decorations`:

```lua
-- lib/wezterm-config.lua
-- Do NOT set window_decorations. Let the OS provide decorations.
-- config.window_decorations = "NONE"    -- WRONG
-- config.window_decorations = "RESIZE"  -- WRONG
```

If your compositor ignores X11 decorations, you may need to add a window rule. For Hyprland:

```
windowrulev2 = decorate, class:^(org\.wezfurlong\.wezterm)$
```

## /bin/bash: No Such File or Directory

**Symptom:** Touchstone scripts fail with `/bin/bash: not found` or similar errors.

**Cause:** NixOS does not have `/bin/bash`. Bash lives in the Nix store (e.g., `/nix/store/...-bash-5.2/bin/bash`).

**Fix:** All Touchstone scripts use `#!/usr/bin/env bash`, which resolves bash from `PATH`. If you see this error, check that:

1. The failing script has `#!/usr/bin/env bash` (not `#!/bin/bash`).
2. bash is on the `PATH` of the process launching Touchstone.

If writing custom scripts for use with `ts-run`, always use `#!/usr/bin/env bash`.

## FIDO2 Touch Times Out on Chained Auth

**Symptom:** When using SSH tunnels with FIDO2 auth on both ends (e.g., SSH + remote sudo), the first touch prompt times out or fails. The second touch succeeds.

**Cause:** The FIDO2 protocol requires the authenticator to complete one challenge-response before starting another. When SSH and sudo prompts arrive in rapid succession through a tunnel, the key may still be processing the previous operation.

**Fix:** This is expected behavior. Wait for the "Please touch" prompt to appear, then touch the key. If a touch fails, wait 1-2 seconds before the next touch. PAM retries automatically.

Single-hop scenarios (the common case) do not exhibit this behavior. See [cross-host-auth.md](../security/cross-host-auth.md) for detailed documentation.

## wezterm start Returns Immediately

**Symptom:** `ts-sudo` returns instantly with no output, or the WezTerm window opens but immediately closes.

**Cause:** Without `--always-new-process`, `wezterm start` may connect to an existing WezTerm multiplexer server. If that server is in a different state or workspace, behavior is unpredictable.

**Fix:** Touchstone uses `--always-new-process` by default. If you see this issue, verify the launch command in `touchstone-core.sh`:

```bash
wezterm start --always-new-process --class "touchstone-$LABEL" -- bash "$MAIN_SCRIPT"
```

Also check that WezTerm is not crashing on startup. Test manually:

```bash
WAYLAND_DISPLAY="" wezterm start --always-new-process -- bash -c "echo test; sleep 5"
```

## Window Opens on Wrong Workspace / Monitor

**Symptom:** The Touchstone WezTerm window opens on a different workspace or monitor than expected.

**Cause:** Window placement is controlled by the window manager. The `--class "touchstone-$LABEL"` flag sets the X11 window class, which can be used in window manager rules.

**Fix:** Add window manager rules for the `touchstone-*` window class.

For i3/sway:

```
for_window [class="touchstone-sudo"] move to workspace current
for_window [class="touchstone-ssh"] move to workspace current
for_window [class="touchstone-run"] move to workspace current
```

For Hyprland:

```
windowrulev2 = workspace current, class:^(touchstone-)
```

## Temp Files Not Cleaned Up

**Symptom:** Files matching `/tmp/ts-*` accumulate.

**Cause:** If the WezTerm window is force-killed (e.g., `kill -9`, window manager close, or system crash), the cleanup code in `touchstone-core.sh` may not run, and `DONEFILE` is never touched. The caller's polling loop times out and the temp files from that session remain.

**Fix:** Manually clean up:

```bash
rm -f /tmp/ts-*
```

For automated cleanup, add a cron job or systemd timer:

```bash
# Clean Touchstone temp files older than 1 hour
find /tmp -name 'ts-*' -mmin +60 -delete
```

## No Terminal Emulator Found

**Symptom:** Error message: `Touchstone: no supported terminal emulator found (need wezterm, terminator, gnome-terminal, or xterm)`

**Cause:** None of the supported terminal emulators are on the `PATH`.

**Fix:** Install WezTerm (recommended):

```bash
# See docs/getting-started/prerequisites.md for distro-specific instructions
```

If WezTerm cannot be installed, Touchstone falls back to Terminator, GNOME Terminal, or xterm -- but only in single-pane mode (no code review or inspector panes).

## Pane Focus Stuck in Code Review

**Symptom:** After the WezTerm window opens, keyboard input goes to the code review pane (less) instead of the execution pane where the password prompt is waiting.

**Cause:** The `wezterm cli activate-pane-direction up` commands may fail silently if pane layout timing races with the activation commands.

**Fix:** Press `Ctrl+1` to jump to pane 0 (execution pane), or click on the execution pane with the mouse (pane focus follows mouse is enabled by default).

## Command Output Truncated

**Symptom:** In captured mode, the output returned to the agent appears incomplete.

**Cause:** The command's output exceeds what was written to `OUTFILE` before the process was terminated, or the command writes to a file descriptor other than stdout/stderr.

**Fix:** The redirection in the main script is `$COMMAND > "$OUTFILE" 2>&1`, which captures both stdout and stderr. If the command uses other file descriptors or writes directly to `/dev/tty`, those outputs are not captured.

For commands with complex output, use interactive mode:

```bash
ts-run <command>
```

## WezTerm Config Conflicts

**Symptom:** The Touchstone window looks different from expected, or keybindings do not work.

**Cause:** The `WEZTERM_CONFIG_FILE` override may not be taking effect, causing WezTerm to load the user's personal config instead.

**Fix:** Verify the config path:

```bash
echo "$TOUCHSTONE_LIB/wezterm-config.lua"
ls -la "$TOUCHSTONE_LIB/wezterm-config.lua"
```

Test directly:

```bash
WEZTERM_CONFIG_FILE=/path/to/touchstone/lib/wezterm-config.lua wezterm start -- bash -c "echo test; sleep 5"
```

## sudo: a password is required

**Symptom:** `ts-sudo` fails because sudo requires a password but the execution pane does not display a prompt.

**Cause:** The `NOPASSWD` sudoers flag is not set, and stdout/stderr redirection prevents the password prompt from displaying in captured mode.

**Fix:** This is expected behavior. In captured mode, the password prompt appears in the WezTerm execution pane -- you must type your password there, not in the calling terminal. Switch to the execution pane (`Ctrl+1` or click on it) and enter your password.
