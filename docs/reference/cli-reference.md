# CLI Reference

## Tools

### ts-sudo

Execute a command with elevated privileges (via `sudo`) with hardware-bound consent.

```
ts-sudo <command> [args...]
```

**Mode:** Captured. Output is written to a temp file and returned to the caller via stdout.

**Examples:**

```bash
ts-sudo whoami                              # Returns "root"
ts-sudo iptables -t nat -L POSTROUTING -n   # List NAT rules
ts-sudo systemctl restart nginx             # Restart a service
ts-sudo cat /etc/shadow                     # Read protected file
ts-sudo make install PREFIX=/usr/local      # Install with make
```

**Behavior:** Opens a three-pane WezTerm window. The execution pane runs `sudo <command> [args...]`. PAM prompts for password and FIDO2 touch. On success, command output is captured and printed to stdout. The exit code is propagated to the caller.

---

### ts-ssh

Execute a command on a remote host via SSH with consent review.

```
ts-ssh [ssh-args...] user@host [command]
```

**Mode:** Captured.

**Examples:**

```bash
ts-ssh root@prod "uname -a"                    # Remote system info
ts-ssh -p 2222 admin@server "df -h"             # Custom port
ts-ssh -i ~/.ssh/deploy_key user@host "ls /var"  # Specific key
```

**Behavior:** Opens a three-pane WezTerm window. The execution pane runs `ssh [ssh-args...] user@host [command]`. SSH authentication (keys, password, or FIDO2 resident keys) proceeds in the execution pane. Output is captured and returned.

---

### ts-scp

Secure file copy with consent review.

```
ts-scp [scp-args...] source dest
```

**Mode:** Captured. Requires at least two arguments (source and destination).

**Examples:**

```bash
ts-scp local-file.tar.gz user@host:/tmp/         # Upload
ts-scp user@host:/var/log/syslog ./syslog.bak    # Download
ts-scp -r ./configs/ admin@prod:/etc/app/         # Recursive copy
```

---

### ts-sftp

SFTP session with consent review.

```
ts-sftp [sftp-args...] user@host
```

**Mode:** Captured.

**Examples:**

```bash
ts-sftp admin@fileserver
ts-sftp -P 2222 user@host
```

**Note:** SFTP sessions are typically interactive. For file transfers, prefer `ts-scp`. For interactive SFTP, consider using `ts-run sftp user@host` instead, which uses interactive mode.

---

### ts-run

Execute any command interactively with consent review. The user sees output live and can respond to prompts.

```
ts-run <command> [args...]
```

**Mode:** Interactive. Output is displayed live in the WezTerm window. The caller receives only the exit code.

**Examples:**

```bash
ts-run make deploy-production                  # Interactive deploy
ts-run ssh -t user@host                        # Interactive SSH session
ts-run sudo nixos-rebuild switch --flake .#     # NixOS rebuild with prompts
ts-run python3 manage.py migrate --interactive  # Django migration
```

**Behavior:** Opens a three-pane WezTerm window. The command runs live in the execution pane. After completion, "Done. Press Enter to close." is displayed. The user presses Enter to close the window. The caller receives the exit code.

**Timeout:** 30 minutes (vs 5 minutes for captured mode tools).

## Environment Variables

### TOUCHSTONE_LIB

Path to the Touchstone library directory containing `touchstone-core.sh` and `wezterm-config.lua`.

- **Default:** Resolved automatically relative to the tool's location (`../lib/`).
- **Override:** Set to a custom path if the library is installed in a non-standard location.

```bash
TOUCHSTONE_LIB=/opt/touchstone/lib ts-sudo whoami
```

### WAYLAND_DISPLAY

Touchstone sets `WAYLAND_DISPLAY=""` when launching WezTerm. This forces X11 mode, which ensures the window gets full OS decorations (title bar, close/minimize/maximize buttons, resize borders).

This is set internally and does not need to be configured by the user.

### WEZTERM_CONFIG_FILE

Touchstone sets this to `$TOUCHSTONE_LIB/wezterm-config.lua` when launching WezTerm. This overrides the user's personal WezTerm configuration with Touchstone's dedicated config.

This is set internally. To modify Touchstone's WezTerm appearance, edit `lib/wezterm-config.lua` directly.

## Exit Codes

All `ts-*` tools propagate the exit code of the executed command:

| Exit Code | Meaning |
|-----------|---------|
| 0 | Command succeeded |
| 1 | Command failed (or Touchstone could not find a terminal emulator) |
| Other | The executed command's exit code (e.g., `sudo` returns 1 on auth failure) |

If the WezTerm window is closed before the command completes, the exit code file may not be written. The default return code in this case is `1`.

## Timeouts

| Mode | Timeout | Iterations | Sleep |
|------|---------|------------|-------|
| Captured | 5 minutes | 1500 | 0.2s |
| Interactive | 30 minutes | 9000 | 0.2s |

If the timeout is reached before `DONEFILE` appears, the caller unblocks and returns exit code `1`.
