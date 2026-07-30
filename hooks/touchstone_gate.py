#!/usr/bin/env python3
"""Cross-harness Touchstone PreToolUse gate for Claude Code and Codex.

The hook is intentionally narrow: it redirects raw privilege/remote-access
commands to Touchstone. It does not police ordinary shell, filesystem, network,
or development activity. Both harnesses send JSON on stdin and accept the same
PreToolUse deny shape used here.
"""

from __future__ import annotations

import json
import re
import sys
from typing import Any


# Match a privileged program only at a shell command boundary, optionally behind
# common command wrappers. A ts-* executable does not match because '-' is part
# of the preceding token rather than a command boundary.
_SEPARATOR = r"(?:^|[;&|`\n]|\$\()"
_WRAPPER = (
    r"(?:\s*(?:env|xargs|nohup|nice|eval|exec|command|time|watch|"
    r"timeout(?:\s+[^\s;&|`]+)?)\s+)*"
)
_PRIVILEGED = r"(?P<program>sudo|ssh|scp|sftp|pkexec|doas|su)"
PRIVILEGED_COMMAND_RE = re.compile(
    _SEPARATOR + r"\s*" + _WRAPPER + _PRIVILEGED + r"(?:\s|$)"
)

WRAPPER_FOR = {
    "sudo": "ts-sudo",
    "ssh": "ts-ssh",
    "scp": "ts-scp",
    "sftp": "ts-sftp",
    "pkexec": "ts-run",
    "doas": "ts-run",
    "su": "ts-run",
}


def extract_command(payload: dict[str, Any]) -> str:
    """Return the shell command from the shared Claude/Codex hook envelope."""
    tool_input = payload.get("tool_input") or {}
    if not isinstance(tool_input, dict):
        return ""
    command = tool_input.get("command", "")
    return command if isinstance(command, str) else ""


def decision_for(command: str) -> dict[str, Any] | None:
    """Return a portable deny response, or None when the command may proceed."""
    match = PRIVILEGED_COMMAND_RE.search(command)
    if not match:
        return None
    program = match.group("program")
    wrapper = WRAPPER_FOR[program]
    reason = (
        f"Raw '{program}' is routed through Touchstone. Use {wrapper} so the "
        "operator can review the exact operation and authorize it with a "
        "physical YubiKey touch. Touchstone is the operator's consent tool; "
        "ordinary unprivileged work is not restricted by this hook."
    )
    return {
        "hookSpecificOutput": {
            "hookEventName": "PreToolUse",
            "permissionDecision": "deny",
            "permissionDecisionReason": reason,
        }
    }


def main() -> int:
    try:
        payload = json.load(sys.stdin)
    except (json.JSONDecodeError, OSError):
        # A malformed harness event is not a privileged command. Avoid wedging
        # the agent; the actual privilege boundary still lives in PAM/FIDO2.
        return 0
    if not isinstance(payload, dict):
        return 0
    decision = decision_for(extract_command(payload))
    if decision is not None:
        json.dump(decision, sys.stdout, separators=(",", ":"))
        sys.stdout.write("\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
