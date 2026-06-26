# Integrations

Touchstone is agent-agnostic. Any process that can execute shell commands can use Touchstone tools. This document covers integration patterns for AI coding agents, IDEs, CI/CD pipelines, and potential future interfaces.

## Claude Code

Claude Code is the primary integration target. Claude Code's Bash tool executes shell commands and returns stdout/stderr to the conversation.

### How It Works

1. Claude Code decides it needs to run a privileged command.
2. It calls `ts-sudo` (or any `ts-*` tool) via the Bash tool.
3. Touchstone opens a three-pane WezTerm window on the user's display.
4. The user reviews the code, authenticates with password + YubiKey.
5. The command output is captured and returned to Claude Code's conversation.

### Example

Claude Code's Bash tool executes:

```bash
ts-sudo iptables -t nat -L POSTROUTING -n
```

The output flows back to Claude:

```
Chain POSTROUTING (policy ACCEPT)
target     prot opt source               destination
MASQUERADE  all  --  10.10.10.0/24       0.0.0.0/0
```

Claude can now reason about the firewall rules and continue its task.

### Configuration for Claude Code

Add Touchstone tools to Claude Code's allowed commands in your project's `.claude/settings.json` or user settings:

```json
{
  "permissions": {
    "allow": [
      "Bash(ts-sudo *)",
      "Bash(ts-ssh *)",
      "Bash(ts-scp *)",
      "Bash(ts-sftp *)",
      "Bash(ts-run *)"
    ]
  }
}
```

This allows Claude Code to call Touchstone tools without per-invocation approval, since Touchstone itself enforces human consent with hardware authentication.

### Interactive Commands

For commands that require user interaction (deploy scripts, database migrations with confirmations):

```bash
ts-run make deploy-production
```

Claude Code receives only the exit code. The user handles all interactive prompts directly in the WezTerm window.

## OpenAI Codex / Google Gemini

Any AI agent that can shell out can use Touchstone. The integration pattern is identical:

```bash
# Codex executes:
ts-sudo systemctl restart nginx

# Gemini executes:
ts-ssh admin@prod "cat /var/log/syslog | tail -50"
```

No agent-specific code is needed. Touchstone is a shell-level tool, not an SDK integration.

## MCP Server (Future)

Touchstone could be exposed as an MCP (Model Context Protocol) server, providing tools directly to AI agents over the MCP transport.

### Potential Tool Definitions

```json
{
  "tools": [
    {
      "name": "touchstone_sudo",
      "description": "Execute a command with elevated privileges. Opens a consent window requiring human review and hardware authentication.",
      "inputSchema": {
        "type": "object",
        "properties": {
          "command": { "type": "string", "description": "Command to execute with sudo" }
        },
        "required": ["command"]
      }
    },
    {
      "name": "touchstone_ssh",
      "description": "Execute a command on a remote host via SSH with consent review.",
      "inputSchema": {
        "type": "object",
        "properties": {
          "target": { "type": "string", "description": "user@host" },
          "command": { "type": "string", "description": "Remote command" }
        },
        "required": ["target", "command"]
      }
    }
  ]
}
```

### Benefits Over Shell Integration

- Structured input/output (JSON instead of raw text)
- Tool discovery (agents can enumerate available Touchstone capabilities)
- Metadata (execution time, auth method used, exit code as structured data)
- Transport independence (stdio, HTTP, WebSocket)

### Implementation Notes

An MCP server would wrap the existing shell tools. The underlying consent mechanism (WezTerm, PAM, FIDO2) is unchanged. The MCP layer adds structured transport, not new security properties.

## VS Code Extension Integration

AI-powered VS Code extensions (Copilot, Continue, Cline) that need system-level access could depend on Touchstone:

```typescript
// Hypothetical VS Code extension integration
import { exec } from 'child_process';

async function privilegedCommand(cmd: string): Promise<string> {
    return new Promise((resolve, reject) => {
        exec(`ts-sudo ${cmd}`, (error, stdout, stderr) => {
            if (error) reject(error);
            else resolve(stdout);
        });
    });
}
```

The WezTerm window opens on the user's desktop. The extension does not need to handle authentication -- Touchstone manages the entire consent flow.

## CI/CD Pipelines

Touchstone's interactive mode (`ts-run`) enables human-gated deployment steps:

```yaml
# GitHub Actions (self-hosted runner with display access)
deploy:
  runs-on: self-hosted
  steps:
    - name: Deploy with human approval
      run: ts-run make deploy-production
      env:
        DISPLAY: ":0"
```

The deployment script pauses at the Touchstone consent window. A human reviews the deployment code, authenticates, and the pipeline continues.

### Requirements for CI/CD

- The runner must have access to a display (X11 or Wayland) for the WezTerm window.
- A FIDO2 key must be physically accessible to the operator.
- This is intentionally designed for **attended deployments** -- unattended pipelines should use traditional secret management and approval gates.

## Integration Patterns Summary

| Integration | Mode | Agent Receives | Auth Required |
|-------------|------|----------------|---------------|
| Claude Code (captured) | `ts-sudo`, `ts-ssh` | Full output | Password + FIDO2 |
| Claude Code (interactive) | `ts-run` | Exit code only | Password + FIDO2 |
| Codex / Gemini | Any `ts-*` tool | Same as above | Password + FIDO2 |
| MCP Server (future) | Structured JSON | Typed response | Password + FIDO2 |
| VS Code Extension | `child_process.exec` | stdout string | Password + FIDO2 |
| CI/CD (self-hosted) | `ts-run` | Exit code | Password + FIDO2 |
