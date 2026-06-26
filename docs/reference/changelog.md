# Changelog

## v0.1.0 — 2026-06-26

Initial release.

### Features

- **ts-sudo** — Elevated commands with hardware-bound consent (captured mode)
- **ts-ssh** — Remote access with consent review (captured mode)
- **ts-scp** — Secure file transfer with consent review (captured mode)
- **ts-sftp** — SFTP sessions with consent review (captured mode)
- **ts-run** — Interactive command runner for commands with prompts (interactive mode)
- **Three-pane WezTerm UI** — Execution / Code Review / Inspector
- **Inspector shell** — Pre-loaded helpers: inspect, deps, perms, show_env
- **Dynamic WezTerm Lua config** — Terminator-style keybindings, dark theme, mouse-follows-focus
- **PAM + FIDO2/YubiKey integration** — Hardware-bound human consent at every privilege boundary
- **Cross-host authentication** — Proven through double-hop reverse SSH with PAM + FIDO2
- **NixOS module** — Flake-based installation
- **Generic Linux installer** — make install / make uninstall for any distro
- **Portable** — #!/usr/bin/env bash, no distro-specific dependencies

### Tested Scenarios

- `ts-sudo whoami` → `root`
- `ts-ssh user@host whoami` → remote user returned
- `ts-run ssh -t user@remote "ssh -t localuser@local 'sudo whoami'"` → double-hop reverse PAM auth → `root`
- `make check` → all dependencies green

### Known Behaviors

- FIDO2 timing on chained multi-hop auth: first touch may require retry (documented in docs/security/cross-host-auth.md)
- WezTerm on Wayland/GNOME requires `WAYLAND_DISPLAY=""` for window decorations (applied automatically)
