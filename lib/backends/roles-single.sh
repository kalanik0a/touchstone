#!/usr/bin/env bash
# ── Roles Backend: Single Operator ─────────────────────────────────
# Default backend. One role: operator. No separation of duties.
# Suitable for standalone / civilian deployments.
#
# Enterprise alternative: roles-pam-group.sh (PAM group RBAC)
# SPDX-License-Identifier: MIT

# Roles:
#   operator  — can approve consent requests
#   auditor   — can read audit logs (read-only)
#   admin     — can modify policy rules
#
# In single-operator mode, the current user has all roles.

_ts_backend_check_role() {
  local required_role="${1:-operator}"
  # Single operator: always authorized
  return 0
}

_ts_backend_get_role() {
  echo "operator"
}
