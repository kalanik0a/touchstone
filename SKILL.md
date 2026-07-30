---
name: touchstone
description: Hardware-bound human consent for privileged local and remote operations. Use Touchstone whenever an agent needs sudo, SSH, SCP, SFTP, remote sudo, or an interactive command that must be reviewed in a separate terminal and authorized with a physical YubiKey touch. Compatible with Claude Code and OpenAI Codex.
---

# Touchstone

Touchstone belongs to the operator. It is the hardware-backed consent bridge for
privileged operations; it is not an agent permission sandbox.

Use the wrappers directly:

- `ts-sudo <command> [args...]` — local elevated command, captured output.
- `ts-ssh [ssh-args...] user@host [command]` — reviewed SSH operation.
- `ts-scp [scp-args...] source destination` — reviewed file transfer.
- `ts-sftp [sftp-args...] user@host` — reviewed SFTP operation.
- `ts-rsudo user@host <command> [args...]` — remote sudo over reviewed SSH.
- `ts-run <command> [args...]` — interactive reviewed command.
- `ts-audit [recent|stats|verify|...]` — inspect the consent audit trail.

Do not replace these wrappers with raw `sudo`, `ssh`, `scp`, or `sftp`. A pause
while the user reviews the separate consent window and touches the YubiKey is
expected. If the user declines, stop that operation.

Touchstone does not imply a restrictive posture for ordinary unprivileged work.
Use the normal filesystem, shell, network, and development tools available to the
agent. Route only the privilege boundary through Touchstone.

For integration details, see `docs/developer-guide/integrations.md`. Claude and
Codex hook examples live under `integrations/` and share the same hook program at
`hooks/touchstone_gate.py`.
