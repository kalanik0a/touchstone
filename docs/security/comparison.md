# Comparison

Touchstone occupies a specific niche: hardware-bound human consent for AI agent privilege escalation. This document compares Touchstone to related tools and explains where it fits relative to existing solutions.

## vs polkit / pkexec

polkit (PolicyKit) is the standard privilege authorization framework on Linux desktops. When an application needs elevated privileges, polkit displays a dialog for the user to authenticate.

| Aspect | polkit/pkexec | Touchstone |
|--------|---------------|------------|
| Code review | No -- shows only the application name and a description string | Yes -- three-pane UI with full source code, searchable |
| Hardware binding | No -- password only (unless PAM is separately configured) | Yes -- PAM + FIDO2 by design |
| Agent awareness | No -- designed for desktop applications, not AI agents | Yes -- designed specifically for AI agent consent |
| Inspector tools | No | Yes -- `deps`, `perms`, `show_env`, full shell |
| Output capture | No -- the application handles its own I/O | Yes -- captured mode returns output to calling agent |
| Integration | D-Bus based, requires .policy XML files | Shell-based, works with any process |

polkit solves a different problem: authorizing known desktop applications to perform predefined privileged operations. It trusts that the application description accurately represents what will happen. Touchstone does not trust the caller's description -- it shows the literal code.

## vs Claude Code Permission Modes

Claude Code has built-in permission management with approval prompts for potentially dangerous operations. In its default mode, Claude asks for user approval before running commands. In "auto-approve" modes, it uses ML classifiers to judge command safety.

| Aspect | Claude Code Permissions | Touchstone |
|--------|------------------------|------------|
| Authentication | Software only (click "approve") | Hardware (PAM + FIDO2 physical touch) |
| Code review | Shows the command string | Three-pane UI with source, inspector, deps |
| Bypass resistance | Agent or prompt injection could influence the ML classifier | Hardware touch cannot be bypassed by software |
| Scope | All commands (not just privileged) | Privileged commands only (sudo, ssh, etc.) |
| Integration | Built into Claude Code | Agent-agnostic (works with any agent) |
| Approval method | Click in terminal | Separate window + password + YubiKey |
| Works offline | Yes | Yes |

These are complementary, not competing. Claude Code permissions handle the broad surface of all commands. Touchstone handles the narrow, high-stakes surface of privileged commands with hardware attestation.

**Recommended configuration:** Use Claude Code's permissions for general command approval, AND use Touchstone for all `sudo`/`ssh` operations. Two independent consent layers.

## vs Enterprise IAM (OAuth, SPIFFE, OPA)

Enterprise Identity and Access Management systems handle machine-to-machine authorization at scale:

| Aspect | Enterprise IAM | Touchstone |
|--------|----------------|------------|
| Scope | Cloud services, APIs, microservices | Local OS privileges |
| Identity model | Machine identity (tokens, certificates) | Human identity (password + physical key) |
| Policy engine | Centralized (OPA, Cedar, IAM policies) | None -- human makes the decision |
| Scale | Thousands of agents/services | Single operator at a workstation |
| Audit | Centralized logging, SIEM integration | Local (temp files, PAM logs) |
| Human in the loop | Optional (policies can auto-approve) | Always required |

Enterprise IAM answers: "Is this agent identity permitted to perform this class of action?"

Touchstone answers: "Did a human physically authorize this specific action?"

These operate at different layers of the stack (see [architecture.md](../developer-guide/architecture.md)). An organization could use both: IAM to control which agents can reach a workstation, and Touchstone to ensure a human approves each privileged command on that workstation.

## vs sudo Alone

Standard `sudo` authenticates the user and grants elevated privileges. It does not provide code transparency or agent-specific features.

| Aspect | sudo | Touchstone + sudo |
|--------|------|-------------------|
| Authentication | Password (or NOPASSWD) | Password + FIDO2 |
| Code visibility | Shows nothing -- just a password prompt | Three-pane UI with source code review |
| Agent output capture | N/A -- output goes to the calling shell | Captured mode writes output to file, returns to agent |
| Inspection tools | None | Inspector pane with `deps`, `perms`, `show_env` |
| Separate window | No -- runs inline | Yes -- dedicated WezTerm window |
| Audit | sudoers log, auth.log | Same (Touchstone delegates to sudo) |

Touchstone does not replace `sudo`. It wraps `sudo` with a consent UI and hardware authentication layer. Under the hood, `ts-sudo` still calls `sudo`, which still invokes PAM, which still checks sudoers rules.

## vs gksudo / kdesudo (Deprecated)

`gksudo` and `kdesudo` were graphical sudo frontends for GNOME and KDE. They showed a dialog box for password entry. Both are deprecated and removed from modern distributions.

Touchstone differs in every significant way: three-pane code review (not just a password dialog), FIDO2 support, agent output capture, and active development targeting AI agent use cases.

## Summary Matrix

| Feature | polkit | Claude Perms | Enterprise IAM | sudo | Touchstone |
|---------|--------|-------------|----------------|------|------------|
| Code review | -- | Command string | -- | -- | Full source + inspector |
| Hardware auth | -- | -- | Varies | PAM-dependent | FIDO2 required |
| Agent-aware | -- | Yes | Yes | -- | Yes |
| Output capture | -- | Yes | N/A | -- | Yes |
| Human required | Yes | Optional | Optional | Yes | Always |
| Separate window | Dialog | Inline | N/A | Inline | Three-pane WezTerm |
| Open source | Yes | No | Varies | Yes | Yes (MIT) |
