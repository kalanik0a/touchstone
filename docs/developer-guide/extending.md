# Extending Touchstone

Adding new `ts-*` tools to Touchstone is straightforward. Each tool is a thin shell script that sources the core library and calls one of two launcher functions.

## Anatomy of a Tool

Every Touchstone tool follows this pattern:

```bash
#!/usr/bin/env bash
# ts-<name> -- <description>
# SPDX-License-Identifier: MIT
set -euo pipefail
TOUCHSTONE_LIB="$(cd "$(dirname "$0")/../lib" && pwd)"
source "$TOUCHSTONE_LIB/touchstone-core.sh"
[ $# -eq 0 ] && { echo "Usage: ts-<name> <command> [args...]" >&2; exit 1; }
ts_launch_captured "<label>" <prefix> "$@"
```

The variables:

| Variable | Purpose |
|----------|---------|
| `<name>` | The tool name (used in filename and usage message) |
| `<label>` | Short identifier for temp file names and WezTerm window class |
| `<prefix>` | The command prefix prepended to the user's arguments (e.g., `sudo`, `ssh`) |

## Choosing a Mode

- **`ts_launch_captured`** -- output is captured to a file and returned to the caller. Use this when the AI agent needs to read the command output.
- **`ts_launch_interactive`** -- output is displayed live in the terminal. Use this when the user needs to interact with the command (prompts, confirmations, live progress).

## Step-by-Step: Adding a New Tool

### Example: ts-docker

A tool for running Docker commands with privilege consent.

**1. Create the script**

Create `bin/ts-docker`:

```bash
#!/usr/bin/env bash
# ts-docker -- Docker commands with hardware-bound consent
# SPDX-License-Identifier: MIT
set -euo pipefail
TOUCHSTONE_LIB="$(cd "$(dirname "$0")/../lib" && pwd)"
source "$TOUCHSTONE_LIB/touchstone-core.sh"
[ $# -eq 0 ] && { echo "Usage: ts-docker <command> [args...]" >&2; exit 1; }
ts_launch_captured "docker" docker "$@"
```

**2. Make it executable**

```bash
chmod +x bin/ts-docker
```

**3. Test it**

```bash
./bin/ts-docker ps
```

A three-pane WezTerm window should open. The code review pane shows the `docker` binary resolution. Authenticate, and the output of `docker ps` is returned.

**4. Add to Makefile**

The existing Makefile already handles all `bin/ts-*` files via a wildcard:

```makefile
@for tool in bin/ts-*; do \
    name=$$(basename $$tool); \
    ...
done
```

No Makefile changes are needed -- `make install` will pick up the new tool automatically.

**5. Add to NixOS module (optional)**

If you use the NixOS flake, add the tool to `module.nix`:

```nix
environment.systemPackages = [
    (mkTool "ts-sudo"   "captured"    "sudo ")
    (mkTool "ts-ssh"    "captured"    "ssh ")
    (mkTool "ts-scp"    "captured"    "scp ")
    (mkTool "ts-sftp"   "captured"    "sftp ")
    (mkTool "ts-docker" "captured"    "docker ")   # new
    (mkTool "ts-run"    "interactive" "")
];
```

## Example: Interactive Tool

For commands that require user interaction (e.g., `ts-deploy` for interactive deployment scripts):

```bash
#!/usr/bin/env bash
# ts-deploy -- Interactive deployment with hardware-bound consent
# SPDX-License-Identifier: MIT
set -euo pipefail
TOUCHSTONE_LIB="$(cd "$(dirname "$0")/../lib" && pwd)"
source "$TOUCHSTONE_LIB/touchstone-core.sh"
[ $# -eq 0 ] && { echo "Usage: ts-deploy <script> [args...]" >&2; exit 1; }
ts_launch_interactive "deploy" "$@"
```

Note that interactive tools do **not** prepend a command prefix -- the user provides the full command. The caller receives only the exit code, not the output.

## Argument Validation

For tools that require specific argument counts or formats, add validation before calling the launcher:

```bash
# ts-scp requires at least source and destination
[ $# -lt 2 ] && { echo "Usage: ts-scp [scp-args...] source dest" >&2; exit 1; }
```

## Testing

After creating a new tool, verify it works:

```bash
# Captured mode: check that output is returned
output=$(./bin/ts-docker version)
echo "$output"  # should contain Docker version info

# Interactive mode: check that the window opens and closes cleanly
./bin/ts-deploy echo "hello"
echo $?  # should be 0
```

Check that temp files are cleaned up:

```bash
ls /tmp/ts-docker-* 2>/dev/null  # should return nothing after execution
```
