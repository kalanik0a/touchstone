# ts-run -- Interactive Command Runner with Consent

`ts-run` wraps any command with Touchstone's three-pane consent UI in **interactive mode**. The user sees live output, can respond to prompts and confirmations, and the caller receives only the exit code.

## Usage

```bash
ts-run <command> [args...]
```

## Mode

**Interactive** -- the command runs live in the execution pane with full TTY access. The user sees all output in real time and can type responses to prompts, confirmations, and interactive menus. The calling process (e.g., Claude Code) receives only the exit code, not the output.

## Examples

### Build and install

```bash
ts-run make install
```

The code review pane shows the Makefile contents with line numbers. You can search for the `install` target with `/install` in the code review pane before authorizing.

### Initialize a project

```bash
ts-run npm init
```

npm will prompt for package name, version, description, etc. You answer each prompt live in the execution pane.

### Configure a build

```bash
ts-run ./configure --prefix=/usr/local
```

The code review pane shows the `configure` script source. Long configure scripts are scrollable with line numbers.

### Run an installer

```bash
ts-run bash install.sh
```

The code review pane shows `install.sh` contents. If the installer asks for confirmation ("Continue? [y/N]"), you respond directly in the execution pane.

### Docker operations

```bash
ts-run docker compose up -d
ts-run docker exec -it mycontainer bash
```

### Interactive tools

```bash
ts-run python3 setup.py develop
ts-run cargo build --release
ts-run nix build
```

## Interactive Mode vs. Captured Mode

| Aspect | Interactive (`ts-run`) | Captured (`ts-sudo`, `ts-ssh`, etc.) |
|--------|------------------------|--------------------------------------|
| Output visibility | User sees live output in the execution pane | Output redirected to temp file, not visible during execution |
| User interaction | User can type responses to prompts | User only enters PAM credentials |
| What caller receives | Exit code only | Full stdout/stderr + exit code |
| Use case | Commands with prompts, confirmations, progress output | Commands where the AI agent needs the output |
| Pane cleanup | User presses Enter after command finishes | Panes close automatically |

### When to use `ts-run`

- The command has interactive prompts (yes/no, configuration questions, menu selections)
- The command produces progress output the user should monitor (build progress, downloads)
- The command needs a real TTY (interactive shells, curses-based UIs)
- The AI agent does not need the command output -- it only needs to know if it succeeded

### When to use `ts-sudo` / `ts-ssh` instead

- The AI agent needs to process the command output (log contents, system status, config files)
- The command is non-interactive (runs and produces output without prompting)

## How Interactive Mode Works

1. A WezTerm window opens with three panes.
2. The command runs directly in the execution pane's TTY -- no output redirection.
3. The user sees all output in real time and can type input.
4. After the command exits, the execution pane displays `Done. Press Enter to close.`
5. The user presses Enter. The code review and inspector panes are killed.
6. The exit code is written to a temp file and returned to the caller.
7. All temp files are cleaned up.

The calling process blocks until the user presses Enter after the command completes. It receives the exit code (0 for success, non-zero for failure) but no output content.
