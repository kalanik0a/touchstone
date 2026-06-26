# ts-sudo -- Elevated Commands with Consent

`ts-sudo` wraps `sudo` with Touchstone's three-pane consent UI. The human reviews the exact command, authenticates with password and optional FIDO2/YubiKey touch, and the output is captured and returned to the calling process.

## Usage

```bash
ts-sudo <command> [args...]
```

## Mode

**Captured** -- stdout and stderr are written to a temp file during execution. After the command completes and panes close, the output is printed to the caller's stdout. This means an AI agent like Claude Code receives the full command output as if it ran `sudo` directly.

## Examples

### List firewall rules

```bash
ts-sudo iptables -L
```

The three-pane window opens. The code review pane resolves `iptables` to its binary path (e.g., `/run/current-system/sw/bin/iptables`). You enter your password, optionally touch your YubiKey, and the iptables output flows back to the caller.

### Restart a service

```bash
ts-sudo systemctl restart nginx
```

### Read a protected file

```bash
ts-sudo cat /etc/shadow
```

### Run a privileged script

```bash
ts-sudo bash /opt/scripts/deploy.sh
```

The code review pane shows the literal contents of `deploy.sh` with line numbers, scrollable and searchable with `/`.

### Network diagnostics

```bash
ts-sudo tcpdump -i eth0 -c 10
ts-sudo ss -tlnp
ts-sudo journalctl -u sshd --since "1 hour ago"
```

## How Captured Mode Works

1. Touchstone creates temp files for stdout capture, exit code, and a done marker.
2. A WezTerm window opens with three panes (execution, code review, inspector).
3. The command runs in the execution pane: `sudo <your-args> > /tmp/ts-sudo-XXXXXX.out 2>&1`
4. PAM prompts appear in the execution pane -- password entry and YubiKey touch happen here.
5. After the command finishes, the code review and inspector panes are killed automatically.
6. The calling process reads the captured output file and prints it to stdout.
7. All temp files are cleaned up. The exit code is forwarded to the caller.

The caller (e.g., Claude Code) blocks until the WezTerm window closes. It receives the full stdout/stderr and the correct exit code.

## PAM Flow

When `sudo` executes in the execution pane, PAM handles authentication in the standard order:

1. **Password prompt** -- PAM asks for your user password via the terminal.
2. **FIDO2/YubiKey touch** -- If `pam_u2f` is configured in `/etc/pam.d/sudo`, PAM requests a physical touch on your security key after password entry.
3. **Authorization** -- PAM checks sudoers rules and grants or denies the request.

The three-pane UI does not intercept or modify the PAM flow. PAM prompts render directly in the execution pane's TTY. This means hardware-bound auth works exactly as it does in a normal terminal -- the YubiKey must be physically present and physically touched.

## Integration with Claude Code

Claude Code can call `ts-sudo` as a bash command. From Claude's perspective, it runs a command and gets output back:

```
Claude Code calls: ts-sudo iptables -t nat -L POSTROUTING -n
  -> WezTerm window opens on the human's display
  -> Human reviews the iptables command in code review pane
  -> Human enters password + touches YubiKey
  -> Output captured and returned to Claude Code
  -> Claude Code processes the iptables output
```

The agent never sees the password or interacts with PAM. The human is the sole gatekeeper.
