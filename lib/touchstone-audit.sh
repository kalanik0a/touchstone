#!/usr/bin/env bash
# ── Touchstone Audit Log ───────────────────────────────────────────
# Append-only structured audit trail for all consent events.
# Each record is HMAC-SHA256 signed for tamper evidence.
#
# DB: ~/.touchstone/audit.db (SQLite, WAL mode)
# Key: ~/.touchstone/hmac.key (generated on first use)
#
# Standards: NIST 800-53 AU-2, AU-3, AU-8, AU-9, AU-12
# SPDX-License-Identifier: MIT

# ── Configuration ──────────────────────────────────────────────────

_TS_AUDIT_DIR="${HOME}/.touchstone"
_TS_AUDIT_DB="${_TS_AUDIT_DIR}/audit.db"
_TS_HMAC_KEY="${_TS_AUDIT_DIR}/hmac.key"

# ── Initialization ─────────────────────────────────────────────────
# [AU-9] DB and key created with restrictive permissions.

_ts_audit_init() {
  # Require resolved tool paths from touchstone-core.sh
  if [ -z "${_TS_OPENSSL:-}" ] || [ -z "${_TS_SQLITE3:-}" ]; then
    echo "Touchstone: openssl or sqlite3 not found in PATH at startup" >&2
    echo "  Install: nix-env -iA nixpkgs.openssl nixpkgs.sqlite" >&2
    return 1
  fi

  if [ ! -d "$_TS_AUDIT_DIR" ]; then
    mkdir -p "$_TS_AUDIT_DIR"
    chmod 0700 "$_TS_AUDIT_DIR"
  fi

  # Initialize signing backend (generates key if needed)
  _ts_backend_sign_init

  # Create DB and schema if needed
  if [ ! -f "$_TS_AUDIT_DB" ]; then
    "$_TS_SQLITE3" "$_TS_AUDIT_DB" << 'SCHEMA'
PRAGMA journal_mode=WAL;
PRAGMA foreign_keys=ON;

-- [AU-3] Consent event records with full attribution
CREATE TABLE IF NOT EXISTS consent_events (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    timestamp   TEXT    NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%S.000','now','localtime')),
    event_type  TEXT    NOT NULL,
    agent_id    TEXT    NOT NULL DEFAULT 'unknown',
    session_id  TEXT    NOT NULL,
    username    TEXT    NOT NULL,
    tool        TEXT    NOT NULL,
    command_hash TEXT,
    command_preview TEXT,
    code_hash   TEXT,
    exit_code   INTEGER,
    hostname    TEXT,
    tty         TEXT,
    ppid        INTEGER,
    policy_rule TEXT,
    hmac        TEXT    NOT NULL
);

-- [AU-12] Index for efficient temporal queries
CREATE INDEX IF NOT EXISTS idx_consent_timestamp ON consent_events(timestamp);
CREATE INDEX IF NOT EXISTS idx_consent_agent ON consent_events(agent_id);
CREATE INDEX IF NOT EXISTS idx_consent_type ON consent_events(event_type);
CREATE INDEX IF NOT EXISTS idx_consent_session ON consent_events(session_id);

-- [AU-9] Prevent casual deletion — trigger blocks DELETE
CREATE TRIGGER IF NOT EXISTS prevent_delete
BEFORE DELETE ON consent_events
BEGIN
    SELECT RAISE(ABORT, 'Touchstone audit log is append-only. Records cannot be deleted.');
END;

-- [AU-9] Prevent modification — trigger blocks UPDATE on critical fields
CREATE TRIGGER IF NOT EXISTS prevent_update
BEFORE UPDATE ON consent_events
BEGIN
    SELECT RAISE(ABORT, 'Touchstone audit log records are immutable.');
END;
SCHEMA
    chmod 0600 "$_TS_AUDIT_DB"
  fi
}

# ── Agent Identity Resolution ──────────────────────────────────────
# [NIST 800-207 §3] Identify the calling agent process.
# Checks TS_AGENT_ID env var first, then resolves from parent process.

_ts_resolve_agent_id() {
  _ts_backend_resolve_identity
}

# ── Generate Session ID ───────────────────────────────────────────

_ts_generate_session_id() {
  _ts_backend_generate_session_id
}

# ── HMAC Signing ───────────────────────────────────────────────────
# [AU-9] Each record is signed with HMAC-SHA256.
# Tampering with any field invalidates the signature.

_ts_hmac_sign() {
  local data="$1"
  _ts_backend_sign_record "$data"
}

# ── Command Hashing ───────────────────────────────────────────────

_ts_hash_command() {
  printf '%s\0' "$@" | sha256sum | cut -d' ' -f1
}

# ── Log a Consent Event ───────────────────────────────────────────
# [AU-2] Records: who, what, when, where, outcome.
#
# Usage: _ts_audit_log <event_type> <tool> <session_id> <agent_id> \
#                       <exit_code> <policy_rule> <args...>
#
# event_type: launched | completed | policy_deny | timeout | abandoned | error

_ts_audit_log() {
  local event_type="$1"
  local tool="$2"
  local session_id="$3"
  local agent_id="$4"
  local exit_code="${5:-}"
  local policy_rule="${6:-}"
  shift 6

  # Build command preview (first 200 chars, sanitized)
  local cmd_preview=""
  cmd_preview=$(printf '%s ' "$@" | head -c 200)

  # Hash the full command
  local cmd_hash=""
  cmd_hash=$(_ts_hash_command "$@")

  # Hash any script/source file found in args
  # [CWE-703] A file arg unreadable by the invoking user (e.g. a root-only
  # config passed to ts-sudo) must not abort the launch under set -e/pipefail
  # — record an explicit marker instead of a hash.
  local code_hash=""
  for arg in "$@"; do
    if [ -f "$arg" ]; then
      code_hash=$(sha256sum "$arg" 2>/dev/null | cut -d' ' -f1) \
        || code_hash="unreadable-by-invoker"
      break
    fi
  done

  # For make targets, hash the Makefile
  if [ "${1:-}" = "make" ] || [ "${1:-}" = "sudo" -a "${2:-}" = "make" ]; then
    for mf in Makefile makefile GNUmakefile; do
      if [ -f "$mf" ]; then
        code_hash=$(sha256sum "$mf" 2>/dev/null | cut -d' ' -f1) \
          || code_hash="unreadable-by-invoker"
        break
      fi
    done
  fi

  local current_user current_host current_tty current_ppid
  current_user=$(id -un)
  current_host=$(hostname)
  current_tty=$(tty 2>/dev/null || echo "none")
  current_ppid="$PPID"

  # Build the data string for HMAC (all fields concatenated)
  local ts
  ts=$(date '+%Y-%m-%dT%H:%M:%S.%3N')
  local hmac_data="${ts}|${event_type}|${agent_id}|${session_id}|${current_user}|${tool}|${cmd_hash}|${exit_code}|${current_host}|${policy_rule}"
  local hmac
  hmac=$(_ts_hmac_sign "$hmac_data")

  # [CWE-89] All values sanitized via tr before interpolation
  "$_TS_SQLITE3" "$_TS_AUDIT_DB" "INSERT INTO consent_events \
    (timestamp, event_type, agent_id, session_id, username, tool, \
     command_hash, command_preview, code_hash, exit_code, hostname, \
     tty, ppid, policy_rule, hmac) \
    VALUES \
    ('${ts}', '$(printf '%s' "$event_type" | tr -cd 'a-z_')', \
     '$(printf '%s' "$agent_id" | tr -cd 'a-zA-Z0-9._-')', \
     '$(printf '%s' "$session_id" | tr -cd 'a-f0-9')', \
     '$(printf '%s' "$current_user" | tr -cd 'a-zA-Z0-9._-')', \
     '$(printf '%s' "$tool" | tr -cd 'a-zA-Z0-9._-')', \
     '$(printf '%s' "$cmd_hash" | tr -cd 'a-f0-9')', \
     '$(printf '%s' "$cmd_preview" | tr -cd 'a-zA-Z0-9 /.=_-')', \
     '$(printf '%s' "$code_hash" | tr -cd 'a-f0-9')', \
     $([ -n "$exit_code" ] && echo "$exit_code" || echo "NULL"), \
     '$(printf '%s' "$current_host" | tr -cd 'a-zA-Z0-9._-')', \
     '$(printf '%s' "$current_tty" | tr -cd 'a-zA-Z0-9/._-')', \
     ${current_ppid}, \
     '$(printf '%s' "$policy_rule" | tr -cd 'a-zA-Z0-9 :._*/-')', \
     '${hmac}')" 2>/dev/null || true
}

# ── Verify Audit Log Integrity ────────────────────────────────────
# [AU-9] Walk all records, recompute HMAC, flag mismatches.

_ts_audit_verify() {
  local failures=0
  local total=0

  while IFS='|' read -r id ts event agent session user tool cmd_hash exit_code host policy_rule stored_hmac; do
    total=$((total + 1))
    local hmac_data="${ts}|${event}|${agent}|${session}|${user}|${tool}|${cmd_hash}|${exit_code}|${host}|${policy_rule}"
    local computed
    computed=$(_ts_hmac_sign "$hmac_data")

    if [ "$computed" != "$stored_hmac" ]; then
      printf '\033[1;31mTAMPERED\033[0m record #%d: %s %s %s\n' "$id" "$ts" "$event" "$tool" >&2
      failures=$((failures + 1))
    fi
  done < <("$_TS_SQLITE3" -separator '|' "$_TS_AUDIT_DB" \
    "SELECT id, timestamp, event_type, agent_id, session_id, username, tool, \
            command_hash, exit_code, hostname, policy_rule, hmac \
     FROM consent_events ORDER BY id")

  if [ "$failures" -eq 0 ]; then
    printf '\033[1;32mINTEGRITY OK\033[0m: %d records verified.\n' "$total"
  else
    printf '\033[1;31mINTEGRITY FAILURE\033[0m: %d of %d records have invalid HMACs.\n' "$failures" "$total" >&2
    return 1
  fi
}

# ── Query Helpers ──────────────────────────────────────────────────

_ts_audit_recent() {
  local limit="${1:-20}"
  "$_TS_SQLITE3" -header -column "$_TS_AUDIT_DB" \
    "SELECT id, timestamp, event_type, agent_id, tool, command_preview, exit_code \
     FROM consent_events ORDER BY id DESC LIMIT $limit"
}

_ts_audit_stats() {
  echo "=== Touchstone Audit Statistics ==="
  "$_TS_SQLITE3" -header -column "$_TS_AUDIT_DB" \
    "SELECT event_type, COUNT(*) as count FROM consent_events GROUP BY event_type"
  echo ""
  "$_TS_SQLITE3" -header -column "$_TS_AUDIT_DB" \
    "SELECT agent_id, COUNT(*) as count FROM consent_events GROUP BY agent_id ORDER BY count DESC"
  echo ""
  "$_TS_SQLITE3" "$_TS_AUDIT_DB" \
    "SELECT 'Total records: ' || COUNT(*) || ', First: ' || MIN(timestamp) || ', Last: ' || MAX(timestamp) FROM consent_events"
}
