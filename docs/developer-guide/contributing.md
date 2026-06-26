# Contributing

Contributions to Touchstone are welcome. This document covers the development workflow, code standards, and review process.

## Getting Started

### Clone and Verify

```bash
git clone https://github.com/kalanik0a/touchstone.git
cd touchstone
make check
```

`make check` verifies that all dependencies (WezTerm, PAM, bash, less) are available on your system.

### Run Locally Without Installing

All tools work from the source tree without `make install`:

```bash
./bin/ts-sudo whoami
./bin/ts-run echo "hello"
```

The `bin/ts-*` scripts resolve `TOUCHSTONE_LIB` relative to their own location, so no system installation is needed for development.

## Branching Model

1. Fork the repository.
2. Create a feature branch from `main`:
   ```bash
   git checkout -b feature/ts-docker
   ```
3. Make your changes.
4. Test locally (see below).
5. Push and open a pull request against `main`.

## Code Standards

### Shell Scripts

- All scripts use `#!/usr/bin/env bash` (not `#!/bin/bash` -- NixOS does not have `/bin/bash`).
- All scripts set `set -euo pipefail` at the top.
- Use `local` for function-scoped variables.
- Quote all variable expansions: `"$VAR"`, not `$VAR`.
- Use `$(command)` instead of backticks.
- Keep tools thin -- business logic belongs in `lib/touchstone-core.sh`, not in `bin/ts-*`.

### Lua (WezTerm Config)

- Follow the existing structure in `lib/wezterm-config.lua`.
- Comment sections with `-- ── Section Name ──` headers.
- Do not add external Lua dependencies -- the config must work with WezTerm's built-in Lua runtime.

### Commit Messages

Use concise, imperative-mood commit messages:

```
Add ts-docker tool for container privilege consent
Fix pane focus order after split
Update WezTerm config for inactive pane dimming
```

## Testing

### Manual Testing

There are no automated tests (yet). Test manually:

```bash
# Test captured mode -- verify output is returned
output=$(./bin/ts-sudo whoami)
[ "$output" = "root" ] && echo "PASS" || echo "FAIL: got '$output'"

# Test interactive mode -- verify window opens and closes
./bin/ts-run echo "test"
echo "Exit code: $?"

# Test temp file cleanup
ls /tmp/ts-sudo-* 2>/dev/null && echo "FAIL: temp files remain" || echo "PASS: clean"

# Test fallback (no wezterm)
PATH=$(echo "$PATH" | tr ':' '\n' | grep -v wezterm | tr '\n' ':') ./bin/ts-sudo whoami
```

### Dependency Check

```bash
make check
```

### Full Validation

Run `make check` and test each tool:

```bash
make check
./bin/ts-sudo whoami
./bin/ts-ssh localhost whoami
./bin/ts-run ls -la /root
```

## Pull Request Process

1. Ensure `make check` passes on your system.
2. Test all modified tools manually.
3. Update documentation if you add new tools, flags, or behavior.
4. Open a PR with a clear description of what changed and why.
5. A maintainer will review and may request changes.

### PR Checklist

- [ ] `make check` passes
- [ ] New tool follows the standard `bin/ts-*` pattern
- [ ] `#!/usr/bin/env bash` used (not `/bin/bash`)
- [ ] `set -euo pipefail` is present
- [ ] Temp files are cleaned up after execution
- [ ] Documentation updated if applicable
- [ ] Tested on at least one Linux distribution

## Project Structure

```
touchstone/
  bin/
    ts-sudo          # Captured mode: sudo
    ts-ssh           # Captured mode: ssh
    ts-scp           # Captured mode: scp
    ts-sftp          # Captured mode: sftp
    ts-run           # Interactive mode: any command
  lib/
    touchstone-core.sh   # Core launcher logic (all shared functions)
    wezterm-config.lua   # WezTerm dynamic configuration
  docs/
    getting-started/     # Prerequisites, installation
    developer-guide/     # Architecture, extending, integrations
    security/            # Threat model, trust boundaries, PAM/FIDO2
    reference/           # CLI reference, configuration, troubleshooting
  flake.nix              # NixOS flake definition
  module.nix             # NixOS module (declares tools as system packages)
  Makefile               # Install, uninstall, check targets
  LICENSE                # MIT
  README.md              # Project overview
```

## Reporting Issues

Open an issue with:

- Your distribution and version.
- WezTerm version (`wezterm --version`).
- The exact command that failed.
- Any error output.
- Whether you have FIDO2 configured.

## License

By contributing, you agree that your contributions are licensed under the MIT License.
