# Security Policy

## Reporting a Vulnerability

If you discover a security vulnerability in Touchstone, please report it responsibly.

**Do NOT open a public GitHub issue for security vulnerabilities.**

Instead, email: **kalanik0a@proton.me**

Include:
- Description of the vulnerability
- Steps to reproduce
- Potential impact
- Suggested fix (if any)

You will receive an acknowledgment within 48 hours. Critical vulnerabilities will be patched and disclosed within 7 days.

## Scope

Touchstone is a consent and transparency layer — it does not replace PAM, sudo, SSH, or FIDO2. Vulnerabilities in those upstream components should be reported to their respective maintainers.

In scope for Touchstone:
- Bypassing the consent UI (executing privileged commands without the three-pane window appearing)
- Temp file races or information leaks in /tmp/ts-* files
- Argument injection through crafted command strings
- WezTerm Lua config injection
- Captured output being accessible to unauthorized processes

Out of scope:
- PAM configuration weaknesses (report to your distro or pam_u2f maintainers)
- WezTerm vulnerabilities (report to wez/wezterm)
- FIDO2/YubiKey firmware issues (report to Yubico)
- OS kernel privilege escalation (report to your kernel vendor)

## Supported Versions

| Version | Supported |
|---------|-----------|
| 0.1.x   | Yes       |
