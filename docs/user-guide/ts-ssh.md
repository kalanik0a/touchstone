# ts-ssh -- Remote Access with Consent

`ts-ssh` wraps `ssh` with Touchstone's three-pane consent UI. The human reviews the remote command, authenticates, and the output is captured and returned to the calling process.

## Usage

```bash
ts-ssh [ssh-args...] user@host [command]
```

All standard `ssh` arguments are passed through directly.

## Mode

**Captured** -- output is written to a temp file and returned to the caller after execution completes.

## Examples

### Run a remote command

```bash
ts-ssh user@host whoami
```

### Check remote system status

```bash
ts-ssh admin@prod uptime
ts-ssh admin@prod df -h
ts-ssh admin@prod "cat /var/log/syslog | tail -50"
```

### Cross-host sudo (remote sudo with local consent)

```bash
ts-ssh -t user@host "sudo whoami"
```

The `-t` flag forces TTY allocation, which is required for `sudo` to prompt for a password on the remote host. The execution pane shows both the SSH authentication and the remote sudo prompt. You authenticate at each boundary.

### Multi-hop SSH

```bash
ts-ssh -J jump@bastion admin@internal "systemctl status nginx"
```

### Port forwarding

```bash
ts-ssh -L 8080:localhost:80 user@host
```

### Custom key

```bash
ts-ssh -i ~/.ssh/deploy_key deployer@prod "docker ps"
```

## Authentication Flow

Authentication prompts appear in the execution pane. Touchstone supports all standard SSH authentication methods:

### Key-based (most common)

1. SSH client presents the key from your agent or `-i` path.
2. If the key is passphrase-protected, the passphrase prompt appears in the execution pane.
3. The remote host verifies the public key.

### Password

1. SSH prompts `user@host's password:` in the execution pane.
2. You type the password in the execution pane.

### FIDO2 / Security Key

1. SSH uses an `sk-ssh-ed25519` or `sk-ecdsa-sha2-nistp256` key.
2. The terminal displays `Confirm user presence for key ...`
3. You touch your YubiKey or FIDO2 device.
4. The remote host verifies the signature.

### Chained auth (cross-host sudo)

When using `ts-ssh -t user@host "sudo command"`, two separate authentication events occur:

1. **SSH auth** -- key, password, or FIDO2 to reach the remote host.
2. **Remote sudo auth** -- password (and optionally FIDO2 if configured on the remote) for privilege escalation on the remote host.

Both prompts appear sequentially in the execution pane.

## Captured Mode Details

The output capture works identically to `ts-sudo`:

1. SSH runs in the execution pane with stdout/stderr redirected to a temp file.
2. After SSH exits, the captured output is returned to the calling process.
3. The exit code from SSH is forwarded to the caller.

This means an AI agent receives the full remote command output. For example, Claude Code can run `ts-ssh admin@prod "docker ps"` and process the container list.
