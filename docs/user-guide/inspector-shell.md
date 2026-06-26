# Inspector Shell

The inspector shell is the bottom pane in Touchstone's three-pane layout. It is a full bash shell pre-loaded with helper functions for investigating what a command does before you authorize it.

When the inspector pane opens, it prints a help menu and drops you into an interactive bash prompt:

```
  ┌─────────────────────────────────────────┐
  │  Touchstone Inspector -- sudo           │
  ├─────────────────────────────────────────┤
  │  inspect   -- view script source (less) │
  │  deps      -- show binary dependencies  │
  │  perms     -- file permissions & types   │
  │  show_env  -- environment variables      │
  │  man CMD   -- manual page for a command  │
  │  ?         -- show this menu again       │
  │                                          │
  │  Full shell -- run any command.          │
  │  Ctrl+1/2/3 to switch panes.            │
  └─────────────────────────────────────────┘

touchstone:/home/user$
```

## Built-in Commands

### inspect

View the script source file in `less` with line numbers. If the command being executed includes a script file path, `inspect` opens that file.

```bash
touchstone:~$ inspect
```

If no script file was detected (e.g., the command is a binary like `iptables`), it prints the command that was invoked:

```
No script file detected. Command: sudo iptables -L
```

### deps

Show the binary dependencies of the command. If a script file is detected, it extracts command names from the script and resolves each to its filesystem path:

```bash
touchstone:~$ deps
── Dependencies ──
  bash                 -> /run/current-system/sw/bin/bash
  rsync                -> /run/current-system/sw/bin/rsync
  ssh                  -> /run/current-system/sw/bin/ssh
  systemctl            -> /run/current-system/sw/bin/systemctl
```

If no script file is detected, it resolves the commands from the argument list.

### perms

Show file permissions and type information for the script and any resolved binaries:

```bash
touchstone:~$ perms
── Permissions ──
-rwxr-xr-x 1 root root 2048 Jun 20 10:00 ./deploy.sh

./deploy.sh: Bourne-Again shell script, ASCII text executable
-rwxr-xr-x 1 root root 186432 Jun 01 00:00 /run/current-system/sw/bin/rsync
```

### show_env

Display the current environment variables (sorted, filtered to exclude noisy variables like `LS_COLORS`). Opens in `less` for scrollable viewing:

```bash
touchstone:~$ show_env
── Environment ──
HOME=/home/user
PATH=/run/current-system/sw/bin:...
SHELL=/run/current-system/sw/bin/bash
USER=user
...
```

### ? (help)

Redisplay the help menu:

```bash
touchstone:~$ ?
```

### man

Standard `man` command -- not a Touchstone helper, but called out in the help menu since it is useful for investigating unfamiliar commands:

```bash
touchstone:~$ man iptables
touchstone:~$ man rsync
```

## Full Shell Access

The inspector is a real bash shell. You can run any command:

```bash
# Check what a binary actually is
touchstone:~$ file $(which iptables)
touchstone:~$ ldd $(which scp)

# Read files
touchstone:~$ cat /etc/pam.d/sudo
touchstone:~$ less /etc/ssh/sshd_config

# Check network state
touchstone:~$ ss -tlnp
touchstone:~$ ip addr

# Look at processes
touchstone:~$ ps aux | grep nginx

# Verify checksums
touchstone:~$ sha256sum /usr/local/bin/deploy.sh

# Check sudoers
touchstone:~$ sudo -l
```

The shell runs as your user, not as root. If you need elevated access in the inspector, you would use `sudo` within the inspector shell (which triggers its own PAM authentication).

## Prompt

The inspector shell uses a custom prompt to make it visually distinct:

```
touchstone:/current/working/directory$
```

The `touchstone` prefix is magenta, the directory path is blue.

## Lifecycle

The inspector shell is created when the Touchstone window opens and is killed automatically when the command in the execution pane finishes. You do not need to exit the inspector manually.
