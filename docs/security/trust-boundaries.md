# Trust Boundaries

Touchstone establishes four trust boundaries between an AI agent's command request and operating system privilege execution. Each boundary has a specific verification method and failure mode.

## Boundary Map

```
+===============================================+
|  AI Agent (untrusted)                         |
|  - May be jailbroken, prompt-injected,        |
|    or operating on malicious instructions      |
+===============================================+
                    |
          Boundary 1: Software
          (agent must call ts-* tools)
                    |
+===============================================+
|  Touchstone (consent layer)                   |
|  - Generates temp scripts                      |
|  - Opens WezTerm three-pane window             |
|  - Manages output capture and cleanup          |
+===============================================+
                    |
          Boundary 2: Visual
          (human sees code in review pane)
                    |
+===============================================+
|  Human Operator (trusted)                     |
|  - Reviews code in code review pane            |
|  - Investigates with inspector pane            |
|  - Makes authorization decision               |
+===============================================+
                    |
          Boundary 3: Authentication
          (password + FIDO2 hardware touch)
                    |
+===============================================+
|  PAM (authentication framework)               |
|  - pam_unix: password verification             |
|  - pam_u2f: FIDO2 challenge-response           |
|  - Returns allow/deny                          |
+===============================================+
                    |
          Boundary 4: Execution
          (kernel enforces privilege)
                    |
+===============================================+
|  Operating System Kernel                      |
|  - setuid, capabilities, namespaces            |
|  - Process isolation                           |
|  - File system permissions                     |
+===============================================+
```

## Boundary 1: Agent to Touchstone (Software Boundary)

**What is verified:** The agent uses `ts-*` tools instead of direct privilege commands.

**Verification method:** Configuration. The agent's environment must be set up so that `ts-sudo` is the path to elevated execution, not raw `sudo`.

**Trust assertion:** The agent cannot execute privileged commands without invoking Touchstone.

**Failure mode:** If the agent has access to `sudo` directly, this boundary does not exist. Touchstone is bypassed entirely.

**Hardening:**

- Remove `sudo` from the agent's `PATH`.
- Alias `sudo` to `ts-sudo` in the agent's shell environment.
- Use Claude Code's permission system to allow only `ts-*` commands.

```json
{
  "permissions": {
    "allow": ["Bash(ts-sudo *)", "Bash(ts-ssh *)"],
    "deny": ["Bash(sudo *)", "Bash(ssh *)"]
  }
}
```

**Strength:** Weak (configuration-dependent). This boundary relies on operational discipline, not cryptographic enforcement.

## Boundary 2: Touchstone to Human (Visual Boundary)

**What is verified:** The human can see exactly what code will be executed.

**Verification method:** The code review pane displays:

- The full command line with arguments.
- The literal source code of any script file referenced in the arguments.
- The Makefile contents if the command is a `make` target.
- Binary resolution paths (`which`) and file types if no source is found.

**Trust assertion:** The human knows what will be executed before authorizing it.

**Failure mode:** The human does not read the code review pane, or the code is obfuscated in a way that defeats human review.

**Hardening:**

- Use the inspector pane (`deps`, `perms`, `show_env`) to investigate suspicious commands.
- The WezTerm window is a physical interrupt -- it demands attention by appearing on screen.
- Inactive pane dimming (brightness 0.7) makes the execution pane visually distinct from review panes.

**Strength:** Medium. Depends on human diligence. The UI is designed to make review easy, but it cannot force reading.

## Boundary 3: Human to PAM (Authentication Boundary)

**What is verified:** The person at the keyboard is an authorized user with possession of the hardware authenticator.

**Verification method:** Two-factor authentication via PAM:

1. **Knowledge factor:** password (verified by `pam_unix`).
2. **Possession factor:** physical FIDO2 key touch (verified by `pam_u2f`).

**Trust assertion:** Only someone who knows the password AND physically possesses the YubiKey can authorize execution.

**Failure mode:**

- Password is compromised (keylogger, shoulder surfing, credential stuffing).
- YubiKey is stolen or cloned (FIDO2 keys are designed to resist cloning).
- Both factors are compromised simultaneously.

**Hardening:**

- Configure `pam_u2f` as `required`, not `sufficient`, so hardware touch is mandatory -- not an alternative to password.
- Use a strong, unique password.
- Keep the YubiKey on your person.

**Strength:** Strong. FIDO2 hardware authentication is resistant to phishing, replay attacks, and remote compromise. The attacker must be physically present with the key.

## Boundary 4: PAM to OS (Execution Boundary)

**What is verified:** The kernel enforces the privilege transition.

**Verification method:** The kernel's security mechanisms:

- `setuid` bit on the `sudo` binary.
- Linux capabilities (`CAP_SYS_ADMIN`, etc.).
- Process UID/GID transitions.
- SELinux/AppArmor policies (if configured).

**Trust assertion:** The privilege grant is enforced by the kernel, not by userspace code.

**Failure mode:** Kernel vulnerability, compromised `sudo` binary, or misconfigured security policies.

**Hardening:**

- Keep the kernel and `sudo` updated.
- Enable SELinux or AppArmor.
- Minimize sudoers rules (principle of least privilege).

**Strength:** Strong (assuming uncompromised kernel). This boundary is provided by the OS, not by Touchstone.

## Trust Boundary Summary

| Boundary | Type | Verified By | Strength | Touchstone's Role |
|----------|------|-------------|----------|-------------------|
| 1. Agent to Touchstone | Software/config | PATH, permissions | Weak | Provides the `ts-*` interface |
| 2. Touchstone to Human | Visual/cognitive | Code review pane | Medium | Generates the review UI |
| 3. Human to PAM | Cryptographic | Password + FIDO2 | Strong | Delegates to PAM stack |
| 4. PAM to OS | Kernel | setuid, capabilities | Strong | Not involved (OS layer) |

## Defense in Depth

No single boundary is sufficient. The security model depends on all four boundaries functioning together:

- Boundary 1 ensures the agent cannot bypass consent.
- Boundary 2 ensures the human is informed.
- Boundary 3 ensures the human is authenticated.
- Boundary 4 ensures the privilege is enforced.

If Boundary 1 fails (agent bypasses `ts-*`), Boundaries 2 and 3 are never invoked. This is why Boundary 1, despite being the weakest, is operationally critical.

If Boundary 2 fails (human does not read the code), Boundary 3 still requires authentication -- but the human is authorizing something they did not review. This is the social engineering attack surface.

If Boundary 3 fails (credentials compromised), the attacker still needed to bypass Boundary 2 (be physically present at the terminal) unless the PAM stack is remotely exploitable.

Boundary 4 is the backstop. Even if all Touchstone boundaries fail, the OS kernel enforces privilege separation.
