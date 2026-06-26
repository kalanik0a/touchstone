# Touchstone

**Hardware-bound privilege consent for AI coding agents.**

Touchstone is the missing trust anchor between AI agents and operating system privileges. When an AI coding agent (Claude Code, Codex, Gemini) needs to run `sudo`, `ssh`, or any privileged command, Touchstone opens a three-pane terminal window where a human reviews the exact code being executed and authorizes it with a physical security key (FIDO2/YubiKey).

No AI agent gets root without a human physically present, reviewing the code, and touching hardware.

---

## The Problem

88% of organizations deploying AI agents have experienced security incidents. AI agents are becoming authorization bypass paths. The industry is building policy engines and OAuth scopes — but nobody built the **physical consent layer** at the OS level.

> *"Identity Is the Agentic AI Problem Nobody Has Solved Yet"*
> — Resilient Cyber, 2026

## The Solution

Touchstone fills the gap between "is this agent allowed?" and "did a human verify and authorize this specific action with a hardware trust anchor?"

```
┌─────────────────────────────────────────────┐
│  Enterprise Policy (OPA, IAM, RBAC)         │
├─────────────────────────────────────────────┤
│  Agent Identity (OAuth, SPIFFE, x509)       │
├─────────────────────────────────────────────┤
│  ► Touchstone ◄                             │
│  • Hardware-bound auth (FIDO2/YubiKey)      │
│  • Visual code transparency (three-pane)    │
│  • PAM integration (OS-level)               │
│  • Agent-agnostic                           │
├─────────────────────────────────────────────┤
│  Operating System (PAM, sudo, SSH, TTY)     │
└─────────────────────────────────────────────┘
```

## Three-Pane Consent UI

When Touchstone intercepts a privileged command, it opens a WezTerm window with three resizable panes:

```
┌──────────────────────────────────────────┐
│  EXECUTION — live command output         │
│  Password prompt, YubiKey touch, results │
├──────────────────────────────────────────┤
│  CODE REVIEW — the literal source code   │
│  Scrollable, searchable, line-numbered   │
├──────────────────────────────────────────┤
│  INSPECTOR — interactive audit shell     │
│  inspect, deps, perms, show_env, man     │
└──────────────────────────────────────────┘
```

- **Execution pane**: the command runs here. PAM prompts for password + YubiKey touch.
- **Code review pane**: shows the exact script, Makefile target, or binary being executed. Displayed in `less` with line numbers — scroll, search with `/`.
- **Inspector pane**: a bash shell pre-loaded with helper functions for investigating what the command does before you authorize it.

## Tools

| Tool | Mode | Purpose |
|------|------|---------|
| `ts-sudo` | Captured | Run elevated commands. Output returned to caller. |
| `ts-ssh` | Captured | Remote access with consent review. |
| `ts-scp` | Captured | Secure file transfer with consent review. |
| `ts-sftp` | Captured | SFTP sessions with consent review. |
| `ts-run` | Interactive | Any command with prompts. User interacts live. |

**Captured mode**: stdout/stderr written to file, returned to the calling process (e.g., Claude Code). The AI agent receives the output after the human authorizes.

**Interactive mode**: command runs live in the terminal. User sees output, responds to prompts (yes/no, passwords, confirmations). Caller receives the exit code.

## Quick Start

### Any Linux (Ubuntu, Fedora, Arch, Debian)

```bash
# Prerequisites
sudo apt install wezterm libpam-u2f   # Ubuntu/Debian
sudo dnf install wezterm pam-u2f      # Fedora
sudo pacman -S wezterm pam-u2f        # Arch

# Install Touchstone
git clone https://github.com/kalanik0a/touchstone
cd touchstone
sudo make install

# Verify
make check
ts-sudo whoami
```

### NixOS (flake)

```nix
# flake.nix
{
  inputs.touchstone.url = "github:kalanik0a/touchstone";
  # ...
  nixosConfigurations.myhost = nixpkgs.lib.nixosSystem {
    modules = [
      touchstone.nixosModules.default
      # ...
    ];
  };
}
```

### With Claude Code

Touchstone works with Claude Code out of the box. When Claude needs `sudo`:

```bash
# Claude Code calls:
ts-sudo iptables -t nat -L POSTROUTING -n

# → Three-pane window opens
# → You review the iptables command
# → You enter password + touch YubiKey
# → Output flows back to Claude Code
```

## Proven

Touchstone has been tested through the hardest auth chain possible:

**Double-hop reverse SSH with PAM + FIDO2:**

```
Inari (local) → SSH → Prod server → reverse SSH → Inari → sudo + YubiKey touch → root
```

Hardware-bound PAM auth survived a double-hop reverse tunnel. The YubiKey was physically present on the originating machine, and `pam_u2f` demanded physical touch at every privilege boundary.

## Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| `Ctrl+1` / `Ctrl+2` / `Ctrl+3` | Jump to Execution / Code / Inspector pane |
| `Alt+Arrow` | Navigate between panes |
| `Ctrl+Shift+Arrow` | Resize panes |
| `Ctrl+Shift+X` | Zoom/maximize current pane |
| `Shift+PageUp/Down` | Scroll pane history |

## Requirements

- **WezTerm** (terminal emulator with split-pane support)
- **PAM** (standard on all Linux distributions)
- **bash**, **less**, **coreutils** (standard)
- **FIDO2/YubiKey** (optional but recommended — the hardware trust anchor)
- **pam_u2f** + **libfido2** (optional — for hardware-bound authentication)

## License

MIT — Sean Jeffery Kalanikoa Lum, 2026
