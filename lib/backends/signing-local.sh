#!/usr/bin/env bash
# ── Signing Backend: Local HMAC-SHA256 ─────────────────────────────
# Default backend. Signs audit records with a local HMAC key.
# Suitable for standalone / civilian deployments.
#
# Enterprise alternative: signing-piv.sh (YubiKey PIV PKCS#11)
# SPDX-License-Identifier: MIT

_ts_backend_sign_init() {
  if [ ! -f "$_TS_HMAC_KEY" ]; then
    "$_TS_OPENSSL" rand -hex 32 > "$_TS_HMAC_KEY"
    chmod 0400 "$_TS_HMAC_KEY"
  fi
}

_ts_backend_sign_record() {
  local data="$1"
  echo -n "$data" | "$_TS_OPENSSL" dgst -sha256 -hmac "$(cat "$_TS_HMAC_KEY")" 2>/dev/null | awk '{print $NF}'
}

_ts_backend_sign_verify() {
  local data="$1" expected="$2"
  local computed
  computed=$(_ts_backend_sign_record "$data")
  [ "$computed" = "$expected" ]
}

_ts_backend_sign_output() {
  local outfile="$1" session_id="$2"
  [ -f "$outfile" ] || return 0
  [ -f "$_TS_HMAC_KEY" ] || return 0

  local sig file_hash
  sig=$(cat "$outfile" | "$_TS_OPENSSL" dgst -sha256 -hmac "$(cat "$_TS_HMAC_KEY")" 2>/dev/null | awk '{print $NF}')
  file_hash=$(sha256sum "$outfile" | cut -d' ' -f1)
  printf '%s|%s|%s\n' "$session_id" "$file_hash" "$sig" > "${outfile}.sig"
  chmod 0600 "${outfile}.sig"
}

_ts_backend_verify_output() {
  local outfile="$1"
  [ -f "$outfile" ] || { echo "Output file not found" >&2; return 1; }
  [ -f "${outfile}.sig" ] || { echo "Signature file not found" >&2; return 1; }

  local stored_session stored_hash stored_sig
  IFS='|' read -r stored_session stored_hash stored_sig < "${outfile}.sig"

  local current_hash current_sig
  current_hash=$(sha256sum "$outfile" | cut -d' ' -f1)
  [ "$current_hash" != "$stored_hash" ] && { printf '\033[1;31mINTEGRITY FAILURE\033[0m: hash mismatch\n' >&2; return 1; }

  current_sig=$(cat "$outfile" | "$_TS_OPENSSL" dgst -sha256 -hmac "$(cat "$_TS_HMAC_KEY")" 2>/dev/null | awk '{print $NF}')
  [ "$current_sig" != "$stored_sig" ] && { printf '\033[1;31mINTEGRITY FAILURE\033[0m: HMAC mismatch\n' >&2; return 1; }
  return 0
}
