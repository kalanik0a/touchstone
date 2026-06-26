# ts-scp -- Secure File Transfer with Consent

`ts-scp` wraps `scp` with Touchstone's three-pane consent UI. The human reviews the file transfer operation, authenticates, and the transfer proceeds with output captured and returned to the caller.

## Usage

```bash
ts-scp [scp-args...] source dest
```

Requires at least two arguments (source and destination). All standard `scp` arguments are passed through.

## Mode

**Captured** -- transfer progress and any errors are captured and returned to the caller.

## Examples

### Copy a local file to a remote host

```bash
ts-scp ./config.yaml admin@prod:/etc/app/config.yaml
```

### Copy a remote file to local

```bash
ts-scp admin@prod:/var/log/app.log ./app.log
```

### Recursive directory copy

```bash
ts-scp -r ./deploy/ admin@prod:/opt/app/
```

### Copy with a specific key

```bash
ts-scp -i ~/.ssh/deploy_key ./release.tar.gz deployer@prod:/tmp/
```

### Preserve permissions and timestamps

```bash
ts-scp -p ./script.sh admin@host:/usr/local/bin/
```

### Copy between two remote hosts

```bash
ts-scp admin@host1:/data/backup.sql admin@host2:/data/backup.sql
```

### Limit bandwidth

```bash
ts-scp -l 1000 ./large-file.iso user@host:/tmp/
```

## What the Code Review Pane Shows

Since `scp` is a binary (not a script), the code review pane shows:

- The full command line being executed
- Binary resolution: `scp` resolved to its path (e.g., `/run/current-system/sw/bin/scp`)
- File type information from `file(1)`

This lets you verify the exact source and destination paths before authorizing the transfer.

## Authentication

Authentication works identically to `ts-ssh` -- password prompts, key passphrases, and FIDO2 touch all appear in the execution pane. See the [ts-ssh documentation](ts-ssh.md) for details on each authentication method.
