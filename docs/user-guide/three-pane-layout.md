# Three-Pane Layout

Every Touchstone command opens a dedicated WezTerm window with three vertically stacked panes. This layout gives the human full visibility into what is being executed before, during, and after authorization.

```
┌──────────────────────────────────────────┐
│  Execution Pane (Ctrl+1)                 │
│  Command runs here. PAM prompts appear.  │
├──────────────────────────────────────────┤
│  Code Review Pane (Ctrl+2)               │
│  Literal source code in less -R -N       │
├──────────────────────────────────────────┤
│  Inspector Pane (Ctrl+3)                 │
│  Bash shell with helper functions        │
└──────────────────────────────────────────┘
```

## Execution Pane (Top)

The top pane is where the command actually runs. This is the only pane where authentication happens.

**What appears here:**

- Password prompts from PAM (`[sudo] password for user:`)
- FIDO2/YubiKey touch requests (`Please touch the device.`)
- Command output (in captured mode, redirected to file; in interactive mode, displayed live)
- The `Done. Press Enter to close.` message after interactive commands finish

**In captured mode** (`ts-sudo`, `ts-ssh`, `ts-scp`, `ts-sftp`): output is redirected to a temp file. You see the PAM prompts but not the command output itself. The output is returned to the calling process after completion.

**In interactive mode** (`ts-run`): output displays live. You can type responses to prompts directly in this pane.

## Code Review Pane (Middle)

The middle pane shows the literal source code being executed, displayed in `less` with line numbers and ANSI color support.

**What it shows depends on the command:**

### Scripts

If any argument is a file path to an existing file, the pane displays that file's contents with line numbers:

```
── ./deploy.sh ──

     1  #!/usr/bin/env bash
     2  set -euo pipefail
     3  echo "Deploying to production..."
     4  rsync -avz ./build/ prod:/var/www/
     5  ssh prod "sudo systemctl restart app"
```

### Makefile targets

If the command is `make` (or `sudo make`), the pane displays the Makefile contents. The target name is shown in the header:

```
── Makefile: Makefile -> target: install ──

     1  PREFIX ?= /usr/local
     2  BINDIR  = $(PREFIX)/bin
     3  ...
```

### Binaries

If no script file is found in the arguments, the pane shows binary resolution -- where each command resolves to on the filesystem and its file type:

```
── No script source found. Command resolution: ──

  iptables -> /run/current-system/sw/bin/iptables
    /run/current-system/sw/bin/iptables: ELF 64-bit LSB pie executable...
```

### Navigation within the code review pane

The code review pane runs `less` with these features:

- **Line numbers** -- every line is numbered (`-N` flag)
- **Search** -- press `/` and type a pattern to search forward, `?` to search backward
- **Scroll** -- arrow keys, Page Up/Down, `g` (top), `G` (bottom)
- **Quit** -- press `q` to dismiss the code review (the pane remains open with `sleep infinity`)

The `less` prompt shows: `[Touchstone Code Review] line 42  q=dismiss  /=search`

## Inspector Pane (Bottom)

The bottom pane is a full bash shell pre-loaded with helper functions for investigating the command. See [inspector-shell.md](inspector-shell.md) for the complete reference.

**Key points:**

- It is a real bash shell -- you can run any command (`ls`, `cat`, `grep`, `man`, whatever you need)
- Helper functions are pre-loaded: `inspect`, `deps`, `perms`, `show_env`, `?`
- The help menu prints automatically when the pane opens
- Custom prompt: `touchstone:/current/dir$`

## How Panes Are Created

Touchstone uses `wezterm cli split-pane` to create the layout programmatically:

1. The WezTerm window opens with the execution pane as the initial pane.
2. `wezterm cli split-pane --bottom --percent 50` creates the code review pane below, taking 50% of the window.
3. `wezterm cli split-pane --bottom --percent 40` creates the inspector pane below the code review pane, taking 40% of the remaining space.
4. Focus is returned to the top pane (execution) using `wezterm cli activate-pane-direction up`.

The result is roughly a 30/35/35 vertical split, though the exact proportions depend on window size.

## How Panes Are Cleaned Up

### Captured mode (`ts-sudo`, `ts-ssh`, `ts-scp`, `ts-sftp`)

After the command completes:

1. The code review and inspector panes are killed with `wezterm cli kill-pane --pane-id`.
2. A done marker file is created.
3. The WezTerm window closes automatically (the execution pane's script has ended, and the other panes are killed).
4. The calling process detects the done marker and reads the captured output.

### Interactive mode (`ts-run`)

After the command completes:

1. The execution pane shows `Done. Press Enter to close.`
2. When the user presses Enter, the code review and inspector panes are killed.
3. The WezTerm window closes.
4. The calling process reads the exit code.

## Fallback (No WezTerm)

If WezTerm is not available, Touchstone falls back to a single-pane mode using whatever terminal emulator is available (terminator, gnome-terminal, xterm). The three-pane layout is a WezTerm-only feature.

## Window Configuration

Touchstone uses a dedicated WezTerm config (`lib/wezterm-config.lua`) that provides:

- Dark theme with visible pane dividers
- Tab bar disabled (single-window, pane-only layout)
- Inactive pane dimming (brightness 0.7) so the active pane is visually distinct
- Mouse click to focus pane
- OS-native window decorations (title bar, close/min/max buttons)
- Window class set to `touchstone-<tool>` for window manager rules
