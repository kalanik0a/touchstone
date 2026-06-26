# Architecture

Touchstone is a hardware-bound privilege consent layer that sits between AI coding agents and operating system privilege mechanisms. This document describes the system architecture, component relationships, and data flow.

## Stack Position

Touchstone occupies a specific layer in the agentic security stack. It does not replace enterprise policy or agent identity -- it adds physical human consent between them and the OS.

```
+-----------------------------------------------+
|  Enterprise Policy (OPA, IAM, RBAC)            |
|  "Is this agent allowed to perform this class  |
|   of action?"                                  |
+-----------------------------------------------+
|  Agent Identity (OAuth 2.0, SPIFFE, x509)      |
|  "Which agent is making this request?"         |
+-----------------------------------------------+
|  >>> Touchstone (Consent Layer) <<<            |
|  "Did a human review the exact code and        |
|   authorize it with a hardware trust anchor?"  |
|                                                |
|  * Three-pane code review UI                   |
|  * PAM integration (password + FIDO2)          |
|  * File-based output capture                   |
|  * Agent-agnostic shell interface              |
+-----------------------------------------------+
|  Operating System (PAM, sudo, SSH, TTY)        |
|  Kernel-enforced privilege boundaries           |
+-----------------------------------------------+
```

Each layer is independent. Touchstone does not require enterprise IAM above it, and it does not modify the OS privilege model below it. It intercepts the path between an agent's shell call and the OS privilege mechanism.

## Component Diagram

The following shows the flow when an AI agent (e.g., Claude Code) calls `ts-sudo`:

```
 Claude Code (or any agent)
       |
       | shell exec: ts-sudo iptables -L
       v
 +-- bin/ts-sudo ----------------------------+
 |  - Validates arguments                     |
 |  - Resolves TOUCHSTONE_LIB                 |
 |  - Sources lib/touchstone-core.sh          |
 |  - Calls ts_launch_captured "sudo" sudo $@ |
 +--------------------------------------------+
       |
       v
 +-- lib/touchstone-core.sh -----------------+
 |                                            |
 |  ts_launch_captured():                     |
 |    1. Create temp files:                   |
 |       - OUTFILE  (.out)  stdout/stderr     |
 |       - RCFILE   (.rc)   exit code         |
 |       - DONEFILE (.done) completion signal |
 |       - MAIN_SCRIPT     main pane script   |
 |       - CODE_SCRIPT     code review script |
 |       - INSPECTOR_SCRIPT inspector script  |
 |                                            |
 |    2. Write code review pane script        |
 |       (_ts_write_code_review)              |
 |                                            |
 |    3. Write inspector pane script          |
 |       (_ts_write_inspector)                |
 |                                            |
 |    4. Write main execution script          |
 |       (splits panes, runs command,         |
 |        captures output, signals done)      |
 |                                            |
 |    5. Launch WezTerm:                      |
 |       WAYLAND_DISPLAY="" \                 |
 |       WEZTERM_CONFIG_FILE=wezterm-config   |
 |       wezterm start --always-new-process   |
 |                                            |
 |    6. Poll for DONEFILE (blocking loop)    |
 |                                            |
 |    7. Read OUTFILE, return exit code       |
 |    8. Clean up all temp files              |
 +--------------------------------------------+
       |
       v
 +-- WezTerm (three-pane window) ------------+
 |                                            |
 |  +----- Pane 0: Execution ---------------+ |
 |  | Command runs here.                     | |
 |  | PAM prompts for password + YubiKey.    | |
 |  | Output captured to OUTFILE.            | |
 |  +----------------------------------------+ |
 |  +----- Pane 1: Code Review -------------+ |
 |  | Source code displayed in less -R -N.   | |
 |  | Shows script, Makefile, or binary      | |
 |  | resolution. Scrollable, searchable.    | |
 |  +----------------------------------------+ |
 |  +----- Pane 2: Inspector ---------------+ |
 |  | Interactive bash shell with helpers:   | |
 |  |   inspect, deps, perms, show_env      | |
 |  | Full shell access for investigation.   | |
 |  +----------------------------------------+ |
 |                                            |
 +--------------------------------------------+
       |
       | PAM authentication
       v
 +-- PAM Stack --+     +-- FIDO2 ----------+
 | pam_unix      | --> | pam_u2f           |
 | (password)    |     | (YubiKey touch)   |
 +---------------+     +-------------------+
       |
       v
 +-- Kernel (execve, uid/gid, capabilities) -+
 |  Privilege granted. Command executes.      |
 +--------------------------------------------+
       |
       | Output written to OUTFILE
       | Exit code written to RCFILE
       | DONEFILE touched
       v
 +-- Caller (Claude Code) -------------------+
 |  Polling loop detects DONEFILE.            |
 |  Reads OUTFILE contents.                   |
 |  Returns exit code to agent conversation.  |
 +--------------------------------------------+
```

## File-Based Synchronization

Touchstone uses file-based IPC because it bridges two independent process trees: the calling agent's shell and the WezTerm window process.

| File | Purpose | Created By | Read By |
|------|---------|------------|---------|
| `OUTFILE` (.out) | Captured stdout + stderr | Main pane script | Caller after completion |
| `RCFILE` (.rc) | Exit code of the executed command | Main pane script | Caller after completion |
| `DONEFILE` (.done) | Completion signal (existence = done) | Main pane script | Caller polling loop |
| `MAIN_SCRIPT` (-main.sh) | Pane orchestration + command execution | touchstone-core.sh | WezTerm initial pane |
| `CODE_SCRIPT` (-code.sh) | Code review display logic | touchstone-core.sh | Code review pane |
| `INSPECTOR_SCRIPT` (-insp.sh) | Inspector shell + helpers | touchstone-core.sh | Inspector pane |

All temp files are created in `/tmp/` with `mktemp` and cleaned up after the caller reads the results. The `DONEFILE` is explicitly removed before launch (`rm -f "$DONEFILE"`) to avoid false positives from previous runs.

### Polling Loop

The caller blocks on a polling loop that checks for the existence of `DONEFILE`:

```bash
local WAIT=0
while [ ! -f "$DONEFILE" ] && [ "$WAIT" -lt 1500 ]; do
    sleep 0.2; WAIT=$((WAIT + 1))
done
```

- **Captured mode**: timeout is 1500 iterations * 0.2s = 300 seconds (5 minutes).
- **Interactive mode**: timeout is 9000 iterations * 0.2s = 1800 seconds (30 minutes).

## Two Modes

### Captured Mode

Used by `ts-sudo`, `ts-ssh`, `ts-scp`, `ts-sftp`.

- Command stdout and stderr are redirected to `OUTFILE`.
- After execution, the caller reads `OUTFILE` and prints it to stdout.
- The AI agent receives the command output in its conversation context.
- The WezTerm window closes automatically after execution.

### Interactive Mode

Used by `ts-run`.

- Command runs live in the terminal. Output is displayed directly to the user.
- The user can respond to prompts, confirmations, and interactive menus.
- After execution, a "Done. Press Enter to close." prompt holds the window open.
- The caller receives only the exit code -- no captured output.

## WezTerm Configuration

Touchstone ships a dedicated WezTerm Lua config (`lib/wezterm-config.lua`) that is loaded via the `WEZTERM_CONFIG_FILE` environment variable. This config is independent of the user's personal WezTerm configuration.

Key settings:

- Tab bar disabled (single-window, pane-only layout)
- Dark theme with visible pane dividers
- Inactive pane dimming (brightness 0.7)
- `Ctrl+1/2/3` keybindings for pane jumping
- Mouse click to focus pane
- No close confirmation prompt
- Window decorations left to the OS window manager (not `NONE` or `RESIZE`)

The `WAYLAND_DISPLAY=""` override forces X11 mode on Wayland compositors, ensuring the window gets full OS title bar decorations (close, minimize, maximize buttons, resize borders).

## Terminal Emulator Fallbacks

If WezTerm is not installed, Touchstone falls back to single-pane mode using (in order of preference):

1. Terminator
2. GNOME Terminal
3. xterm

In fallback mode, the code review and inspector panes are not available. The command runs in a single terminal window with output capture.
