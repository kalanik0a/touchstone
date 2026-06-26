# Configuration

Touchstone has three configuration surfaces: the WezTerm Lua config, the PAM stack, and SSH configuration.

## WezTerm Configuration

Touchstone ships its own WezTerm config at `lib/wezterm-config.lua`. This file is loaded via the `WEZTERM_CONFIG_FILE` environment variable, independent of the user's personal `~/.config/wezterm/wezterm.lua`.

### Window Settings

```lua
config.window_padding = { left = 2, right = 2, top = 2, bottom = 2 }
config.initial_cols = 90
config.initial_rows = 35
config.window_close_confirmation = "NeverPrompt"
config.adjust_window_size_when_changing_font_size = false
```

- **window_close_confirmation = "NeverPrompt"**: prevents WezTerm from asking "are you sure?" when panes are killed during cleanup.
- **Window decorations are intentionally not set**: this lets the OS window manager provide full decorations (title bar, close/min/max buttons, resize borders). Setting `window_decorations = "NONE"` would create a borderless window that is harder to identify and manage.

### Tab Bar

```lua
config.enable_tab_bar = false
config.use_fancy_tab_bar = false
```

Tabs are disabled. Touchstone uses panes, not tabs. Each consent window is a single WezTerm instance with multiple panes.

### Theme

```lua
config.color_scheme = "Tango (terminal.sexy)"
config.colors = {
    background = "#171421",
    foreground = "#d0cfcc",
    split = "#555753",
}
```

Dark theme with visible pane dividers. The `split` color (`#555753`) ensures pane boundaries are visible against the dark background.

### Inactive Pane Dimming

```lua
config.inactive_pane_hsb = {
    saturation = 0.85,
    brightness = 0.7,
}
```

Inactive panes are dimmed to 70% brightness. This makes the active pane (typically the execution pane during authentication) visually prominent.

### Keybindings

| Binding | Action |
|---------|--------|
| `Ctrl+1` | Activate pane 0 (Execution) |
| `Ctrl+2` | Activate pane 1 (Code Review) |
| `Ctrl+3` | Activate pane 2 (Inspector) |
| `Alt+Arrow` | Navigate between panes directionally |
| `Ctrl+Shift+Arrow` | Resize current pane |
| `Ctrl+Shift+X` | Toggle pane zoom (maximize/restore) |
| `Ctrl+Shift+O` | Split horizontally (manual) |
| `Ctrl+Shift+E` | Split vertically (manual) |
| `Ctrl+Shift+W` | Close current pane |
| `Shift+PageUp/Down` | Scroll pane history |

### Mouse

```lua
config.pane_focus_follows_mouse = true
```

Clicking on a pane focuses it. This allows quick switching between execution, code review, and inspector panes without keyboard shortcuts.

### Font

```lua
config.font_size = 10.0
```

Default font size. WezTerm uses its default font (typically JetBrains Mono or a fallback). Modify `config.font` to specify a different font:

```lua
config.font = wezterm.font("Fira Code")
config.font_size = 11.0
```

### Customizing the Config

Edit `lib/wezterm-config.lua` directly. Changes take effect on the next Touchstone invocation (each invocation launches a new WezTerm process).

Common customizations:

```lua
-- Larger window
config.initial_cols = 120
config.initial_rows = 50

-- Light theme
config.colors = {
    background = "#fafafa",
    foreground = "#333333",
    split = "#cccccc",
}

-- No pane dimming
config.inactive_pane_hsb = {
    saturation = 1.0,
    brightness = 1.0,
}
```

## PAM Configuration

Touchstone delegates authentication to the system PAM stack. The relevant PAM service files depend on which `ts-*` tool is used:

| Tool | PAM Service |
|------|-------------|
| `ts-sudo` | `/etc/pam.d/sudo` |
| `ts-ssh` | `/etc/pam.d/sshd` (on the remote host) |
| `ts-scp` | `/etc/pam.d/sshd` (on the remote host) |
| `ts-sftp` | `/etc/pam.d/sshd` (on the remote host) |
| `ts-run` | Depends on the command being run |

### Recommended sudo PAM Configuration

```
# /etc/pam.d/sudo
auth  required  pam_unix.so
auth  required  pam_u2f.so  cue  [cue_prompt=Touch your security key]
account  required  pam_unix.so
session  required  pam_limits.so
session  required  pam_unix.so
```

This requires both password and FIDO2 touch for every `sudo` invocation.

### NixOS PAM Configuration

```nix
{
  security.pam.u2f = {
    enable = true;
    cue = true;
    control = "required";
  };
}
```

NixOS manages `/etc/pam.d/` declaratively. Manual edits are overwritten on rebuild.

### Testing PAM Changes

Always keep a root shell open when modifying PAM:

```bash
# Open a root shell first (in a separate terminal)
sudo -i

# Now modify PAM and test in another terminal
ts-sudo whoami
```

If authentication breaks, use the root shell to revert the PAM configuration.

## SSH Configuration

For `ts-ssh`, `ts-scp`, and `ts-sftp`, the standard SSH configuration applies:

### Client-Side (~/.ssh/config)

```
Host prod
    HostName 10.0.0.5
    User admin
    Port 22
    IdentityFile ~/.ssh/prod_ed25519
    ForwardAgent no
```

Usage:

```bash
ts-ssh prod "uname -a"
```

### FIDO2 SSH Keys

OpenSSH supports FIDO2 resident keys (`ed25519-sk`, `ecdsa-sk`):

```bash
# Generate a FIDO2 SSH key
ssh-keygen -t ed25519-sk -C "touchstone@workstation"
```

When `ts-ssh` connects, the SSH key authentication itself requires a YubiKey touch, providing hardware binding at the SSH layer in addition to any remote sudo authentication.

### Agent Forwarding

Avoid `ForwardAgent yes` when using Touchstone. Agent forwarding exposes SSH keys to the remote host. If the remote host is compromised, the attacker can use forwarded keys for lateral movement.

If agent forwarding is necessary, use `ProxyJump` instead:

```
Host prod-internal
    HostName 10.0.0.5
    ProxyJump bastion
    User admin
```
