# Quickstart

This guide walks through your first Touchstone session in about five minutes. It assumes you have completed [installation](installation.md).

---

## 1. Local Privileged Command

Run a simple sudo command through Touchstone:

```bash
ts-sudo whoami
```

A WezTerm window opens with three panes:

| Pane | Name | What it shows |
|------|------|---------------|
| Left | **Execution** | The command to be executed (`sudo whoami`) and its eventual output |
| Top-right | **Code Review** | The full context -- which agent requested this, the command, arguments, working directory, environment |
| Bottom-right | **Inspector** | Live security metadata -- PAM status, FIDO2 challenge state, audit trail |

**What to do:** Review the command in the Code Review pane. When satisfied, authenticate with your password. If FIDO2 is enabled, touch your YubiKey when it blinks.

The output (`root`) flows back to the calling agent in captured mode. The WezTerm window closes automatically.

---

## 2. Remote Consent

Execute a command on a remote host with SSH consent:

```bash
ts-ssh user@host whoami
```

The same three-pane window appears, but the Code Review pane now shows the full SSH connection details -- remote host, user, key fingerprint, and the command to run. Authenticate locally, and the command executes on the remote host. The output is captured and returned to the caller.

---

## 3. Interactive Mode

Some commands require live user interaction (prompts, confirmations, interactive installers). Use `ts-run` for these:

```bash
ts-run make build
```

In interactive mode, the Execution pane becomes a live terminal. You interact with the process directly -- answer prompts, provide input, watch output scroll. The Code Review and Inspector panes remain visible alongside.

The key difference: in captured mode (`ts-sudo`, `ts-ssh`), output is returned to the agent. In interactive mode (`ts-run`), you drive the session.

---

## 4. Keyboard Shortcuts

Navigate the three-pane layout with these shortcuts:

| Shortcut | Action |
|----------|--------|
| `Ctrl+1` | Focus the Execution pane |
| `Ctrl+2` | Focus the Code Review pane |
| `Ctrl+3` | Focus the Inspector pane |
| `Ctrl+Shift+Arrow` | Resize the focused pane |
| `Ctrl+Shift+X` | Zoom the focused pane to full screen (toggle) |

---

## What Just Happened

An AI coding agent needed elevated privileges. Instead of silently running `sudo` or SSH commands behind your back, Touchstone forced a full stop:

1. The agent's request was intercepted and displayed in a dedicated review window.
2. You read the code and the command. You saw exactly what would execute and where.
3. You authenticated with your password -- and optionally touched a physical hardware key that cannot be spoofed by software.
4. Only then did the command run.

The agent got root. But it got root because **you** reviewed the code, **you** entered your password, and **you** touched the hardware. No prompt injection, no background escalation, no silent overreach. The consent was hardware-bound, human-verified, and auditable.

That is the Touchstone model: the AI proposes, the human disposes.
