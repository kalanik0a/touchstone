# Architecture Diagrams

## Trust Stack

```
┌─────────────────────────────────────────────────────┐
│           Enterprise Policy Layer                   │
│         (OPA, IAM, RBAC, ABAC)                     │
├─────────────────────────────────────────────────────┤
│           Agent Identity Layer                      │
│     (OAuth 2.0, SPIFFE/SPIRE, x509, JWT)           │
├═════════════════════════════════════════════════════╡
│                                                     │
│    ███  TOUCHSTONE  ███                             │
│                                                     │
│    Physical consent    Visual code        Agent-    │
│    (FIDO2/YubiKey)     transparency       agnostic  │
│                        (three-pane UI)              │
│                                                     │
├═════════════════════════════════════════════════════╡
│           Operating System                          │
│     (PAM, sudo, SSH, TTY, kernel)                  │
└─────────────────────────────────────────────────────┘
```

## Data Flow

```
AI Agent (Claude Code, Codex, Gemini)
    │
    ▼
ts-sudo / ts-ssh / ts-run
    │
    ▼
touchstone-core.sh
    │
    ├── Write code review script → /tmp/ts-*-code.sh
    ├── Write inspector script  → /tmp/ts-*-insp.sh
    ├── Write main exec script  → /tmp/ts-*-main.sh
    │
    ▼
WAYLAND_DISPLAY="" wezterm start --always-new-process
    │
    ├── Pane 0 (top):    Main execution
    │   └── Command runs here
    │       └── PAM prompts: password + YubiKey touch
    │
    ├── Pane 1 (middle): Code review
    │   └── less -R -N shows literal source
    │
    └── Pane 2 (bottom): Inspector shell
        └── inspect, deps, perms, show_env
    │
    ▼
Human reviews code → authenticates → touches hardware
    │
    ▼
Output captured to /tmp/ts-*-XXXXXX.out (captured mode)
   — OR —
Output displayed live in terminal (interactive mode)
    │
    ▼
Exit code written to /tmp/ts-*-XXXXXX.rc
Done file touched: /tmp/ts-*-XXXXXX.done
    │
    ▼
Caller receives output + exit code
Temp files cleaned up
```

## Trust Boundaries

```
┌─────────────────────────────────────────────────────────┐
│  AI Agent Process                                       │
│  (untrusted — may be compromised or jailbroken)        │
│                                                         │
│  ┌───────────────────────────────────────────────────┐  │
│  │  Boundary 1: Agent → Touchstone                   │  │
│  │  Agent must call ts-* tools (software boundary)   │  │
│  └───────────────────┬───────────────────────────────┘  │
└──────────────────────┼──────────────────────────────────┘
                       ▼
┌──────────────────────┼──────────────────────────────────┐
│  Touchstone Process  │                                   │
│  (three-pane UI)     │                                   │
│                      │                                   │
│  ┌───────────────────┴───────────────────────────────┐  │
│  │  Boundary 2: Touchstone → Human                   │  │
│  │  Human sees code in review pane (visual boundary) │  │
│  └───────────────────┬───────────────────────────────┘  │
└──────────────────────┼──────────────────────────────────┘
                       ▼
┌──────────────────────┼──────────────────────────────────┐
│  PAM Authentication  │                                   │
│                      │                                   │
│  ┌───────────────────┴───────────────────────────────┐  │
│  │  Boundary 3: Human → PAM                          │  │
│  │  Password + FIDO2 touch (auth boundary)           │  │
│  └───────────────────┬───────────────────────────────┘  │
└──────────────────────┼──────────────────────────────────┘
                       ▼
┌──────────────────────┼──────────────────────────────────┐
│  OS Kernel           │                                   │
│                      │                                   │
│  ┌───────────────────┴───────────────────────────────┐  │
│  │  Boundary 4: PAM → Kernel                         │  │
│  │  Kernel enforces privilege (execution boundary)   │  │
│  └───────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────┘
```

## Cross-Host Auth Flow

```
┌──────────┐    SSH     ┌──────────┐   reverse SSH   ┌──────────┐
│  Inari   │ ────────►  │   Prod   │  ────────────►  │  Inari   │
│ (local)  │   key+pwd  │ (remote) │    FIDO2 auth   │ (local)  │
│          │            │          │                  │          │
│ YubiKey  │            │          │                  │ sudo +   │
│ present  │            │          │                  │ YubiKey  │
│ here     │            │          │                  │ touch    │
└──────────┘            └──────────┘                  └──────────┘
     ▲                                                      │
     │                                                      │
     └──────────── output flows back ◄──────────────────────┘
```
