# Touchstone

**Hardware-bound privilege consent for an AI coding agent.**

Touchstone is the trust anchor between an AI agent and operating-system privilege. When an agent (Claude Code, Codex, Gemini) needs to run `sudo`, `ssh`, `scp`, or `sftp` on this machine, it does not call those tools directly — it calls a Touchstone `ts-*` wrapper. The wrapper opens a three-pane terminal window where a human reviews the exact command and code, then authorizes execution with a physical YubiKey touch. Output is returned to the agent only *after* the human approves.

No agent gets root, remote access, or a privileged action without a human physically present, reviewing the command, and touching hardware.

---

## What this is

A set of thin bash wrappers (`bin/ts-*`) backed by a shared library (`lib/`). Each wrapper:

1. Resolves the library via `$(dirname "$0")/../lib` and sources `touchstone-core.sh`.
2. Runs the command string through the **policy engine** (deny / warn / allow).
3. If not denied, opens a **three-pane WezTerm consent window** (execution / code review / inspector).
4. The human reviews and authorizes at the OS auth boundary (`sudo` password + `pam_u2f` YubiKey touch).
5. Records the event, HMAC-signed, in an append-only **audit log**.

It does not replace PAM, sudo, SSH, or FIDO2 — it is a consent, transparency, and audit layer that sits in front of them.

## Threat model

Touchstone defends against a **steered agent running with your own uid**. On this machine the AI agent already runs as `kalanik0a` and can read/write your files, so classic confidentiality controls are theater: the agent is the universal bypass. Encrypting or hiding data from a process that runs as you accomplishes nothing.

The one thing the agent cannot do on its own is be *physically you*. Touchstone converts every privileged action into a request that only completes when a human:

- **reads the exact command** (in a window the agent does not control), and
- **touches a hardware key** (`pam_u2f` demands physical presence at each privilege boundary).

**The consent window is the real enforcement point (the PEP — Policy Enforcement Point).** The policy engine is a Policy Decision Point that filters known-bad commands *before* a human is ever asked, but everything that gets past it still stops dead at the human + YubiKey. Config files, the policy file, and even the audit DB are all writable by the agent's uid — so the design deliberately does **not** rely on their confidentiality. The hardware touch is the control that a steered agent cannot forge (NIST SP 800-207 PDP/PEP model).

What it does *not* defend against: a malicious human operator, YubiKey theft + coercion, or vulnerabilities in the upstream PAM/sudo/WezTerm/FIDO2 stack (see `SECURITY.md`).

## The wrappers

All live in `bin/`. Captured wrappers return stdout/stderr to the calling agent after approval; interactive runs live in the terminal and return only an exit code.

| Wrapper   | Mode        | What it gates |
|-----------|-------------|---------------|
| `ts-sudo` | captured    | Elevated commands — `sudo <cmd>`. Output returned to the agent. |
| `ts-ssh`  | captured    | Remote SSH access. |
| `ts-scp`  | captured    | Secure file copy. |
| `ts-sftp` | captured    | SFTP sessions. |
| `ts-run`  | interactive | Any command with live prompts/progress; user interacts directly. |
| `ts-audit`| —           | Query the audit log (recent / stats / verify integrity). |
| `ts-show` | —           | Display helper for audit/consent records. |

Captured wrappers call `ts_launch_captured`; `ts-run` calls `ts_launch_interactive` (both in `lib/touchstone-core.sh`). The privileged command is executed with all `TS_*` bookkeeping env vars stripped via `env -u ...` so the command cannot tamper with the output/return-code files or leak the original PATH.

## Policy engine

Policy files use one rule per line:

```
action:pattern:description
```

- **action** — `deny` | `warn` | `allow`
- **pattern** — a shell glob matched (via bash `case`, never `eval`) against the full command string
- **description** — human-readable reason, shown to the reviewer / logged

Semantics (`lib/touchstone-policy.sh`, `_ts_policy_check`):

| Action  | Effect |
|---------|--------|
| `deny`  | Request is refused **before** any consent window opens. Logged as `policy_deny`. The human is never asked. |
| `warn`  | A warning is printed, then evaluation continues to the consent window. Allowed-but-flagged. |
| `allow` | Stops policy evaluation and proceeds **straight to the consent window**. It does **not** bypass hardware consent — the human still reviews and touches the YubiKey. Added 2026-07-06. |

**Precedence:** the user policy `~/.touchstone/policy.conf` is read **first**, then the builtin `lib/default-policy.conf`. First match wins. This means a user `allow` rule can override a builtin `deny` (a PDP-level override) — but because `allow` still routes to the consent window, the human remains the enforcement point. Scope `allow` patterns as narrowly as possible (exact device, exact path) and date-stamp them. Example from the live user policy:

```
allow:*dd *of=/dev/sdf *:USB live-disk flash to /dev/sdf (NixOS recovery ISO, 2026-07-06)
```

The builtin policy (`lib/default-policy.conf`) ships denies for system destruction (`rm -rf /`, `mkfs`, `dd of=/dev/sd*`, `wipefs`), credential exfiltration (`cat /etc/shadow`, SSH private keys, the Touchstone `hmac.key`), dangerous permission changes, security-control tampering (`setenforce 0`, disabling auditd, flushing firewall rules), and piped remote code execution (`curl … | bash`). Warns cover `--no-verify`, force pushes, hard resets, `shutdown`/`reboot`, service stops, and force-kills.

## How consent works

When a request passes policy, `ts_launch_*` opens a WezTerm window (class `touchstone-<label>`) with three panes:

1. **Execution** — the command runs here; `sudo`/PAM prompts for password and the YubiKey touch; output appears live.
2. **Code review** — the literal source being run (script, Makefile target, or resolved binary path) shown in `less` with line numbers; scrollable and searchable.
3. **Inspector** — a bash shell preloaded with helpers (`inspect`, `deps`, `perms`, `show_env`, `man`) to investigate the command before authorizing. Sensitive env vars (`*TOKEN*`, `*SECRET*`, `*KEY*`, `*PASSWORD*`, …) are filtered out of `show_env`.

Panes are reached with `Ctrl+1` / `Ctrl+2` / `Ctrl+3`. The hardware touch is enforced by `pam_u2f` at the OS boundary, not by Touchstone itself — Touchstone just guarantees the human sees the real command at the moment they authorize. If WezTerm is unavailable, it falls back to a single-pane terminator/gnome-terminal/xterm window (no code-review or inspector pane).

## Audit

Every consent event is written to an append-only SQLite log at **`~/.touchstone/audit.db`** (WAL mode). Records capture: timestamp, event type (`launched` / `completed` / `policy_deny` / `timeout` / `error`), resolved agent id, session id, username, tool, command hash + 200-char preview, code hash (SHA-256 of any script/Makefile involved), exit code, hostname, tty, ppid, and matched policy rule. Each row is **HMAC-SHA256 signed** for tamper-evidence, and `DELETE`/`UPDATE` are blocked by SQLite triggers. Captured command output is also hashed + HMAC-signed to a `.sig` sidecar.

Query it with `ts-audit` (recent events, per-agent/per-type stats, and `verify` to recompute every HMAC and flag tampering).

Agent identity is resolved heuristically from the parent process (`identity-process.sh`): an explicit `TS_AGENT_ID` wins, otherwise `claude*`/`codex*`/`node`/`python*`/`electron*` parents are tagged `<name>-<pid>`, everything else `manual-<pid>`.

## Install

Two paths — a NixOS module (durable, pending) and a PATH bootstrap (current):

- **PATH bootstrap (current, in use):** the wrappers are added to `PATH` via `~/.bashrc` pointing at `~/Code/Skills/touchstone/bin`. Each wrapper self-resolves its library through `$(dirname "$0")/../lib`, so it works from any location as long as `bin/` and `lib/` stay siblings. Verified working (`ts-sudo whoami` → `root`).
- **NixOS module (`module.nix` + `flake.nix`) — pending durable install:** imports as `touchstone.nixosModules.default`, builds each `ts-*` via `pkgs.writeShellScriptBin`, pins `TOUCHSTONE_LIB` to the store path, and pulls in `openssl`, `sqlite`, and `zenity`. Not yet wired into the system flake.
- **Generic Linux:** `sudo make install` after installing WezTerm + `pam_u2f`/`libfido2` (see the Makefile).

Requirements: WezTerm (for the three-pane UI), PAM, bash/less/coreutils, `openssl` + `sqlite3` (audit), and a FIDO2/YubiKey with `pam_u2f` for the hardware trust anchor.

## Key files

| Path | Role |
|------|------|
| `bin/ts-sudo`, `ts-ssh`, `ts-scp`, `ts-sftp`, `ts-run` | User-facing wrappers; resolve lib, source core, launch. |
| `bin/ts-audit`, `bin/ts-show` | Audit-log query / record-display tools. |
| `lib/touchstone-core.sh` | Shared launcher: temp-dir handling, three-pane WezTerm build, code-review + inspector panes, env stripping, `ts_launch_captured` / `ts_launch_interactive`. |
| `lib/touchstone-policy.sh` | Policy engine (PDP): deny/warn/allow evaluation, user-before-builtin precedence. |
| `lib/default-policy.conf` | Builtin deny/warn ruleset. |
| `lib/touchstone-audit.sh` | SQLite audit schema, HMAC signing, event logging, integrity verify. |
| `lib/touchstone-integrity.sh` | Output signing/verification (delegates to signing backend). |
| `lib/touchstone-backends.sh` | Pluggable backend loader (signing / identity / roles) via `~/.touchstone/config.conf`. |
| `lib/backends/signing-local.sh` | Default local HMAC signing backend (generates `hmac.key`). |
| `lib/backends/identity-process.sh` | Default agent-identity resolver (parent-process heuristic). |
| `lib/backends/roles-single.sh` | Default single-operator roles backend. |
| `lib/backends/*.stub` | Enterprise backend stubs (x509 identity, PAM-group roles, PIV signing). |
| `lib/wezterm-config.lua` | WezTerm config for the consent window (keybindings, layout). |
| `module.nix` / `flake.nix` | NixOS install (pending durable use). |
| `~/.touchstone/policy.conf` | User policy overrides (agent-writable). |
| `~/.touchstone/audit.db` | Append-only HMAC-signed audit log. |
| `~/.touchstone/hmac.key` | Local HMAC signing key. |

## Known gotchas & open findings

- **`hmac.key` is currently 0 bytes (broken tamper-evidence).** `~/.touchstone/hmac.key` exists but is empty and world-readable (`0644`, not the intended `0400`). Because `signing-local.sh` only generates the key *if the file does not exist*, an empty file is never regenerated — so every audit HMAC is computed over an **empty key**. That makes the audit log's tamper-evidence effectively worthless: anyone (including a steered agent) can recompute valid HMACs and `ts-audit verify` will still pass. **Fix:** `rm ~/.touchstone/hmac.key` and let it regenerate (or `openssl rand -hex 32 > hmac.key && chmod 0400`). Consider having init reject a zero-byte key. (This does *not* undermine the primary control — hardware consent — but it does undermine after-the-fact audit integrity.)
- **`~/.touchstone/policy.conf` is agent-writable.** The agent runs as your uid, so it can add `allow` rules to its own policy file. This is *by design*: the policy engine is a convenience filter, not a security boundary. The consent window + YubiKey touch is the backstop — an `allow` rule the agent grants itself still cannot execute anything without the human physically authorizing it. Do not treat policy denies as a containment mechanism.
- **Consent window is the only real gate.** Everything upstream of the human (policy, config, identity heuristics, audit) runs at the agent's privilege level and should be assumed influenceable. Trust the hardware touch, not the software preflight.
- **NixOS module not yet durably installed** — the wrappers currently reach `PATH` via a `.bashrc` bootstrap; if `bin/` and `lib/` are ever separated, library resolution breaks.

## License

MIT — Sean Jeffery Kalanikoa Lum, 2026. See `LICENSE`.
