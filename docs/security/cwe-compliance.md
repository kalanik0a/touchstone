# CWE Compliance Matrix

Touchstone has been audited through three independent security passes against 32 CWE categories. All findings were remediated and verified.

## Audit Summary

| Pass | Findings | Fixed | Auditor |
|------|----------|-------|---------|
| First | 13 (2 CRITICAL, 4 HIGH, 3 MEDIUM, 2 LOW, 2 INFO) | All 13 | Claude Opus 4.6 |
| Second | 10 (0 CRITICAL, 0 HIGH, 3 MEDIUM, 5 LOW, 2 INFO) | All 10 | Claude Opus 4.6 |
| Third | 1 (0 CRITICAL, 0 HIGH, 0 MEDIUM, 1 LOW, 0 INFO) | 1 | Claude Opus 4.6 |
| **Total** | **24 unique findings** | **24/24 fixed** | |

Additionally, automated SAST scanning was performed with 5 tools:

| Scanner | Result |
|---------|--------|
| ShellCheck 0.11.0 | Clean (5 info-level false positives — dynamic source paths) |
| Semgrep 1.161.0 (auto + security-audit + bash rulesets) | 0 findings |
| detect-secrets | 0 secrets |
| Gitleaks 8.30.1 | No leaks (162KB scanned) |
| Trivy 0.69.3 (vuln + secret + misconfig) | Clean |

## CWE Compliance Table

**32 CWEs checked. 32 PASS. 0 FAIL.**

| CWE ID | Name | Status | Mitigation |
|--------|------|--------|------------|
| CWE-20 | Improper Input Validation | PASS | Label validated via `^[a-zA-Z0-9_-]+$` regex. Arg count checked in all wrappers. Arguments transported via NUL-delimited file, never parsed. |
| CWE-22 | Path Traversal | PASS | Label regex excludes `/` and `..`. `mktemp -d` with random suffix. `TOUCHSTONE_LIB` resolved via `cd && pwd` canonicalization. |
| CWE-59 | Improper Link Resolution Before File Access | PASS | `mktemp -d` creates unique 0700 directory atomically. All temp files inside private dir. No predictable paths. |
| CWE-78 | OS Command Injection | PASS | Quoted heredocs (`<< 'DELIM'`) prevent shell expansion. Arguments via NUL-delimited file + `readarray -d ''`, never interpolated into scripts. `env -u` strips internal vars before privileged command execution. |
| CWE-88 | Improper Neutralization of Argument Delimiters | PASS | NUL-delimited `readarray -d ''` preserves argument boundaries. `"${CMD_ARGS[@]}"` expansion maintains discrete args. |
| CWE-94 | Improper Control of Generation of Code | PASS | All heredocs single-quote delimited. User data never enters script bodies. |
| CWE-96 | Improper Neutralization of Directives in Statically Saved Code | PASS | Generated scripts read input from data files at runtime, not at generation time. |
| CWE-116 | Improper Encoding or Escaping of Output | PASS | NUL-delimiter approach avoids encoding issues. Output to terminal only. |
| CWE-200 | Exposure of Sensitive Information | PASS | `umask 077`. `env -u` strips TS_* vars before privileged execution. Inspector `show_env` filters TOKEN/SECRET/KEY/PASSWORD/CREDENTIAL/AUTH patterns. `_TS_ORIG_PATH` not exported. |
| CWE-250 | Execution with Unnecessary Privileges | PASS | Touchstone never runs as root. Delegates to sudo/PAM. No suid bits. |
| CWE-269 | Improper Privilege Management | PASS | Privilege escalation delegated entirely to sudo and PAM. |
| CWE-276 | Incorrect Default Permissions | PASS | `umask 077` before all file creation. Explicit `chmod 0700` on all generated scripts. `mktemp -d` creates 0700 directories. |
| CWE-284 | Improper Access Control | PASS | 0700 tmpdir restricts access to owning user. PAM handles authentication. |
| CWE-326 | Inadequate Encryption Strength | PASS | N/A — ephemeral temp files protected by filesystem permissions, no crypto needed. |
| CWE-362 | Race Condition | PASS | Per-invocation unique tmpdir via `mktemp -d`. No shared state between concurrent invocations. |
| CWE-367 | TOCTOU Race Condition | PASS | `mktemp -d` atomically creates unique directory. Sentinel files inside 0700 dir prevent external manipulation. |
| CWE-377 | Insecure Temporary File | PASS | `mktemp -d` + `umask 077` + `trap cleanup EXIT INT TERM HUP`. |
| CWE-426 | Untrusted Search Path | PASS | PATH explicitly set to known system directories. Original PATH preserved only as unexported local variable. |
| CWE-427 | Uncontrolled Search Path Element | PASS | PATH is set, not inherited. Hardened PATH inherited by child processes via environment. |
| CWE-434 | Unrestricted Upload of File with Dangerous Type | PASS | Scripts generated from hardcoded templates only. No user content in script bodies. |
| CWE-459 | Incomplete Cleanup | PASS | `trap "_ts_cleanup ..." EXIT INT TERM HUP` on both launchers. `rm -rf` on private tmpdir. |
| CWE-494 | Download of Code Without Integrity Check | PASS | N/A — no code download. All scripts generated locally. |
| CWE-502 | Deserialization of Untrusted Data | PASS | NUL-delimited format — simplest possible serialization with no parsing ambiguity. |
| CWE-532 | Insertion of Sensitive Information into Log File | PASS | No log files written. Inspector filters sensitive env vars. |
| CWE-561 | Dead Code | PASS | All functions called. No unreachable code paths. Prior dead code (`ESCAPED_ARGS`) removed. |
| CWE-668 | Exposure of Resource to Wrong Sphere | PASS | `env -u` strips TS_* vars in both WezTerm and fallback paths. `_TS_ORIG_PATH` not exported. `WEZTERM_CONFIG_FILE` stripped before privileged execution. |
| CWE-693 | Protection Mechanism Failure | PASS | Defense-in-depth: umask + mktemp-d + chmod + quoted heredocs + NUL args + env-u + label validation + hardened PATH + trap cleanup. |
| CWE-732 | Incorrect Permission Assignment for Critical Resource | PASS | All critical resources created with restrictive permissions (0700 dir, 0700 scripts). |
| CWE-754 | Improper Check for Unusual Conditions | PASS | `set -euo pipefail`. Launch failure detection via `.started` sentinel (5s timeout). Completion timeout. Default RC=1 for missing RC file. |
| CWE-755 | Improper Handling of Exceptional Conditions | PASS | Error paths produce clear stderr messages and nonzero exits. Trap ensures cleanup on all exit paths. |
| CWE-798 | Use of Hard-coded Credentials | PASS | No credentials anywhere in the codebase. Auth delegated to PAM/FIDO2. |
| CWE-913 | Improper Control of Dynamically-Managed Code Resources | PASS | No `eval`, no `source` of user content, no dynamic code from untrusted sources. |

## Additional Standards Alignment

| Standard | Relevance |
|----------|-----------|
| OWASP Agentic AI Top 10 (2025) | Touchstone mitigates agent privilege escalation, the #1 reported incident type |
| MITRE ATT&CK T1548 | Abuse Elevation Control Mechanism — Touchstone adds human consent + hardware verification |
| MITRE ATLAS | AI agent threat modeling — Touchstone provides the physical trust anchor |
| NIST SP 800-207 (ZTA) | Zero Trust Architecture — Touchstone enforces "never trust, always verify" at the OS privilege boundary |
| OWASP ASVS v4 | V2 (Authentication), V4 (Access Control) — PAM + FIDO2 + consent UI |

## Known Acceptable Risks

| Risk | Severity | Rationale |
|------|----------|-----------|
| SIGKILL cannot be trapped | Inherent | All trap-based cleanup is limited by this kernel constraint. Temp files persist but are in 0700 dir with no persistent secrets. |
| `readarray -d ''` requires bash 4.4+ | Low | NixOS ships bash 5.3. Traditional distros with bash < 4.4 would need the `while IFS= read -r -d ''` alternative. Documented in troubleshooting. |
| X11 weaker isolation than Wayland | Low | `WAYLAND_DISPLAY=""` forces X11 for window decoration support. Documented. Users on Wayland-only setups can remove this override once WezTerm's Wayland decorations are fixed upstream. |
| Inspector shell provides full bash access | By design | The inspector is for the human operator to investigate commands. It runs as the invoking user (not root). Over-restricting it would defeat its purpose. |
