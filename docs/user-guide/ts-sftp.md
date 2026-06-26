# ts-sftp -- SFTP Sessions with Consent

`ts-sftp` wraps `sftp` with Touchstone's three-pane consent UI. The human reviews the SFTP connection target, authenticates, and the session output is captured and returned to the caller.

## Usage

```bash
ts-sftp [sftp-args...] user@host
```

All standard `sftp` arguments are passed through.

## Mode

**Captured** -- session output is written to a temp file and returned to the caller after the session ends.

## Examples

### Open an SFTP session

```bash
ts-sftp admin@prod
```

### Connect with a specific key

```bash
ts-sftp -i ~/.ssh/deploy_key deployer@prod
```

### Connect to a non-standard port

```bash
ts-sftp -P 2222 user@host
```

### Batch mode with a command file

```bash
ts-sftp -b transfer-commands.txt user@host
```

Where `transfer-commands.txt` contains:

```
cd /var/log
get app.log
get error.log
bye
```

The code review pane will show the contents of `transfer-commands.txt` with line numbers, so you can review exactly which files will be transferred.

### Automated file retrieval

```bash
echo "get /etc/nginx/nginx.conf /tmp/nginx.conf" | ts-sftp user@host
```

## What the Code Review Pane Shows

- The full `sftp` command line
- If a batch file (`-b`) is specified, the batch file contents are displayed with line numbers
- Otherwise, binary resolution for `sftp`

## Authentication

Authentication works identically to `ts-ssh` -- all SSH authentication methods are supported since SFTP runs over SSH. See the [ts-ssh documentation](ts-ssh.md) for details.
