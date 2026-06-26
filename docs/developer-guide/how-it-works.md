# How It Works

This document traces the complete execution flow from an AI agent requesting a privileged command to the authorized output being returned.

## End-to-End Flow

### 1. Agent Calls a Touchstone Tool

An AI coding agent (Claude Code, Codex, etc.) executes a shell command:

```bash
ts-sudo iptables -t nat -L POSTROUTING -n
```

The agent treats this exactly like any other shell command. It has no awareness of Touchstone's internal mechanics.

### 2. Tool Script Bootstraps

The `bin/ts-sudo` script runs:

```bash
#!/usr/bin/env bash
set -euo pipefail
TOUCHSTONE_LIB="$(cd "$(dirname "$0")/../lib" && pwd)"
source "$TOUCHSTONE_LIB/touchstone-core.sh"
[ $# -eq 0 ] && { echo "Usage: ts-sudo <command> [args...]" >&2; exit 1; }
ts_launch_captured "sudo" sudo "$@"
```

It resolves the path to `lib/`, sources `touchstone-core.sh`, and calls `ts_launch_captured` with the label `"sudo"` and the full command `sudo iptables -t nat -L POSTROUTING -n`.

### 3. Core Creates Temp Files

`ts_launch_captured` creates six temp files in `/tmp/`:

```
/tmp/ts-sudo-XXXXXX.out       # stdout/stderr capture
/tmp/ts-sudo-XXXXXX.rc        # exit code
/tmp/ts-sudo-XXXXXX.done      # completion signal
/tmp/ts-sudo-XXXXXX-main.sh   # main pane orchestration script
/tmp/ts-sudo-XXXXXX-code.sh   # code review pane script
/tmp/ts-sudo-XXXXXX-insp.sh   # inspector pane script
```

The `DONEFILE` is explicitly removed to prevent false completion signals from previous runs.

### 4. Code Review Script Is Generated

`_ts_write_code_review` writes a bash script that:

1. Prints the full command line with syntax highlighting.
2. Attempts to find source code to display:
   - If any argument is `make`, it looks for `Makefile`/`makefile`/`GNUmakefile` and shows the full file with line numbers.
   - If any argument is a file path, it displays that file with `cat -n`.
   - Otherwise, it resolves each argument with `which` and shows the binary path + `file` output.
3. Pipes everything through `less -R -N` with a custom prompt.
4. Runs `sleep infinity` to keep the pane alive until killed.

### 5. Inspector Script Is Generated

`_ts_write_inspector` writes a bash script that provides an interactive audit shell with:

- `inspect` -- view the script source in `less`
- `deps` -- list binary dependencies and their paths
- `perms` -- show file permissions and types
- `show_env` -- display environment variables
- `?` -- show the help menu

The inspector drops the user into `bash --norc --noprofile -i` with a custom prompt (`touchstone:path$`).

### 6. Main Script Is Generated

The main script is generated inline. It:

1. Splits the WezTerm window into three panes using `wezterm cli split-pane`.
2. Activates the top pane (execution pane).
3. Runs the actual command with output redirected to `OUTFILE`.
4. Writes the exit code to `RCFILE`.
5. Kills the code review and inspector panes.
6. Touches `DONEFILE` to signal completion.

```bash
#!/usr/bin/env bash
CODE_PANE=$(wezterm cli split-pane --bottom --percent 50 -- bash /tmp/ts-sudo-XXXXXX-code.sh sudo sudo iptables ...)
wezterm cli activate-pane --pane-id "$CODE_PANE" 2>/dev/null || true
INSP_PANE=$(wezterm cli split-pane --bottom --percent 40 -- bash /tmp/ts-sudo-XXXXXX-insp.sh sudo sudo iptables ...)
wezterm cli activate-pane-direction up 2>/dev/null || true
wezterm cli activate-pane-direction up 2>/dev/null || true

sudo iptables -t nat -L POSTROUTING -n > /tmp/ts-sudo-XXXXXX.out 2>&1
echo $? > /tmp/ts-sudo-XXXXXX.rc

wezterm cli kill-pane --pane-id "$CODE_PANE" 2>/dev/null || true
wezterm cli kill-pane --pane-id "$INSP_PANE" 2>/dev/null || true
touch /tmp/ts-sudo-XXXXXX.done
sleep 0.3
```

### 7. WezTerm Launches

The core launches WezTerm with specific environment overrides:

```bash
WAYLAND_DISPLAY="" WEZTERM_CONFIG_FILE="$TOUCHSTONE_WEZ_CONFIG" \
    wezterm start --always-new-process --class "touchstone-sudo" -- bash "$MAIN_SCRIPT"
```

- `WAYLAND_DISPLAY=""` -- forces X11 mode so the window gets full OS decorations (title bar, close/min/max buttons).
- `WEZTERM_CONFIG_FILE` -- points to Touchstone's own Lua config, not the user's personal config.
- `--always-new-process` -- prevents reuse of an existing WezTerm server process. Each Touchstone window is fully independent.
- `--class "touchstone-sudo"` -- sets the X11 window class for window manager rules.

### 8. Pane Layout Establishes

The main script runs inside WezTerm's initial pane (pane 0). It immediately splits:

1. `wezterm cli split-pane --bottom --percent 50` creates pane 1 (code review) below pane 0.
2. `wezterm cli split-pane --bottom --percent 40` creates pane 2 (inspector) below pane 1.
3. Focus is moved back to pane 0 (execution) via two `activate-pane-direction up` calls.

The result is a vertical stack:

```
+---------- Pane 0: Execution (top, 50%) -----------+
|                                                     |
+---------- Pane 1: Code Review (middle, 30%) -------+
|                                                     |
+---------- Pane 2: Inspector (bottom, 20%) ----------+
|                                                     |
+-----------------------------------------------------+
```

### 9. Command Executes with PAM Authentication

The command runs in pane 0. For `ts-sudo`, this means `sudo` invokes PAM:

1. `pam_unix` prompts for the user's password.
2. If configured, `pam_u2f` prompts for a FIDO2 touch ("Please touch the device").
3. The user physically touches their YubiKey.
4. PAM grants (or denies) the privilege.
5. The command executes (or fails).

During this time, the user can:

- Switch to pane 1 (`Ctrl+2`) to review the exact code.
- Switch to pane 2 (`Ctrl+3`) to run `inspect`, `deps`, `perms`, or any shell command.
- Return to pane 0 (`Ctrl+1`) to complete authentication.

### 10. Output Is Captured and Window Closes

After the command completes:

1. stdout/stderr are already written to `OUTFILE` (via redirection in step 6).
2. The exit code is written to `RCFILE`.
3. The code review and inspector panes are killed.
4. `DONEFILE` is touched.
5. A 0.3s sleep gives the OS time to flush, then the window closes.

### 11. Caller Reads Results

Back in the original process, the polling loop detects `DONEFILE`:

```bash
while [ ! -f "$DONEFILE" ] && [ "$WAIT" -lt 1500 ]; do
    sleep 0.2; WAIT=$((WAIT + 1))
done
```

The caller then:

1. Reads `OUTFILE` and prints it to stdout (so the agent receives the output).
2. Reads `RCFILE` for the exit code.
3. Deletes all six temp files.
4. Returns the exit code.

### 12. Agent Receives Output

The AI agent now has the command output in its conversation context:

```
Chain POSTROUTING (policy ACCEPT)
target     prot opt source               destination
MASQUERADE  all  --  10.10.10.0/24       0.0.0.0/0
```

The agent can parse this output, reason about it, and continue its task.

## Interactive Mode Differences

When `ts-run` is used instead:

- The command runs **without output redirection** -- output goes directly to the terminal in pane 0.
- After execution, a "Done. Press Enter to close." prompt keeps the window open.
- The user presses Enter to signal completion.
- `DONEFILE` is touched, and the caller unblocks.
- The caller receives **only the exit code**, not the output.
- The polling timeout is 30 minutes instead of 5 minutes, accommodating long interactive sessions.

## Sequence Summary

```
Agent                Touchstone             WezTerm              PAM/OS
  |                     |                     |                    |
  |-- ts-sudo cmd ----->|                     |                    |
  |                     |-- create temps ---->|                    |
  |                     |-- write scripts --->|                    |
  |                     |-- wezterm start --->|                    |
  |                     |                     |-- split panes     |
  |                     |                     |-- show code review |
  |                     |                     |-- show inspector   |
  |                     |                     |-- run command ---->|
  |                     |                     |                    |-- password?
  |                     |                     |<-- password -------|
  |                     |                     |                    |-- touch key?
  |                     |                     |<-- touch ----------|
  |                     |                     |                    |-- granted
  |                     |                     |<-- output ---------|
  |                     |                     |-- write outfile    |
  |                     |                     |-- write rcfile     |
  |                     |                     |-- touch donefile   |
  |                     |<-- poll detects ----|                    |
  |<-- output + rc -----|                     |                    |
  |                     |-- cleanup temps     |                    |
```
