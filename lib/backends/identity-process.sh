#!/usr/bin/env bash
# ── Identity Backend: Process Heuristic ────────────────────────────
# Default backend. Resolves agent identity from parent process tree.
# Suitable for standalone / civilian deployments.
#
# Enterprise alternative: identity-x509.sh (client certificate)
# SPDX-License-Identifier: MIT

_ts_backend_resolve_identity() {
  # Explicit agent ID takes priority
  if [ -n "${TS_AGENT_ID:-}" ]; then
    echo "$TS_AGENT_ID"
    return
  fi

  # Derive from parent process
  local pname=""
  if [ -f "/proc/${PPID}/comm" ]; then
    pname=$(cat "/proc/${PPID}/comm" 2>/dev/null || echo "unknown")
  fi

  # Heuristic: identify known agent process names
  case "$pname" in
    claude*|codex*|node|python*|electron*)
      echo "${pname}-${PPID}"
      ;;
    *)
      echo "manual-${PPID}"
      ;;
  esac
}

_ts_backend_generate_session_id() {
  "$_TS_OPENSSL" rand -hex 16
}
