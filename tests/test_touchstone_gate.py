#!/usr/bin/env python3
"""Unit and subprocess contract tests for both agent hook envelopes."""

from __future__ import annotations

import importlib.util
import json
import subprocess
import sys
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
HOOK = ROOT / "hooks" / "touchstone_gate.py"
SPEC = importlib.util.spec_from_file_location("touchstone_gate", HOOK)
assert SPEC and SPEC.loader
gate = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(gate)


class GateUnitTests(unittest.TestCase):
    def test_redirects_raw_privileged_programs(self) -> None:
        cases = {
            "sudo id": "ts-sudo",
            "ssh host uptime": "ts-ssh",
            "echo ok; scp a host:/tmp/a": "ts-scp",
            "env timeout 5 sftp host": "ts-sftp",
            "doas id": "ts-run",
            "su - root": "ts-run",
        }
        for command, wrapper in cases.items():
            with self.subTest(command=command):
                result = gate.decision_for(command)
                self.assertIsNotNone(result)
                reason = result["hookSpecificOutput"]["permissionDecisionReason"]
                self.assertIn(wrapper, reason)

    def test_allows_touchstone_and_unprivileged_commands(self) -> None:
        for command in (
            "ts-sudo id",
            "ts-ssh host uptime",
            "ts-rsudo host systemctl restart nginx",
            "git status",
            "curl https://example.com",
            "python3 -m pytest",
            "printf '%s' ssh",
        ):
            with self.subTest(command=command):
                self.assertIsNone(gate.decision_for(command))

    def test_extracts_shared_hook_shape(self) -> None:
        payload = {"tool_name": "Bash", "tool_input": {"command": "sudo id"}}
        self.assertEqual(gate.extract_command(payload), "sudo id")


class HarnessContractTests(unittest.TestCase):
    def run_hook(self, payload: object) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            [sys.executable, str(HOOK)],
            input=json.dumps(payload),
            text=True,
            capture_output=True,
            check=False,
        )

    def test_claude_pretooluse_contract(self) -> None:
        proc = self.run_hook(
            {
                "session_id": "claude-test",
                "hook_event_name": "PreToolUse",
                "tool_name": "Bash",
                "tool_input": {"command": "sudo id"},
            }
        )
        self.assertEqual(proc.returncode, 0)
        response = json.loads(proc.stdout)
        self.assertEqual(
            response["hookSpecificOutput"]["permissionDecision"], "deny"
        )

    def test_codex_pretooluse_contract(self) -> None:
        proc = self.run_hook(
            {
                "session_id": "codex-test",
                "turn_id": "turn-test",
                "hook_event_name": "PreToolUse",
                "tool_name": "Bash",
                "tool_input": {"command": "ssh test-host uptime"},
            }
        )
        self.assertEqual(proc.returncode, 0)
        response = json.loads(proc.stdout)
        self.assertEqual(
            response["hookSpecificOutput"]["hookEventName"], "PreToolUse"
        )

    def test_unprivileged_command_emits_no_output(self) -> None:
        proc = self.run_hook(
            {"tool_name": "Bash", "tool_input": {"command": "git status"}}
        )
        self.assertEqual(proc.returncode, 0)
        self.assertEqual(proc.stdout, "")


if __name__ == "__main__":
    unittest.main()
