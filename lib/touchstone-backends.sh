#!/usr/bin/env bash
# ── Touchstone Backend Loader ──────────────────────────────────────
# Loads pluggable backends for signing, identity, and roles.
# Defaults to standalone (civilian) backends.
#
# Config: ~/.touchstone/config.conf
# Format: key=value (no spaces around =)
#
# SPDX-License-Identifier: MIT

_TS_CONFIG="${HOME}/.touchstone/config.conf"
_TS_BACKENDS_DIR="${TOUCHSTONE_LIB}/backends"

# ── Load Configuration ─────────────────────────────────────────────

_ts_load_config() {
  local signing_backend="local"
  local identity_backend="process"
  local roles_backend="single"

  # Read config if it exists
  if [ -f "$_TS_CONFIG" ]; then
    while IFS='=' read -r key value; do
      case "$key" in
        '#'*|'') continue ;;
        signing_backend)  signing_backend="$value" ;;
        identity_backend) identity_backend="$value" ;;
        roles_backend)    roles_backend="$value" ;;
      esac
    done < "$_TS_CONFIG"
  fi

  # Load backends — fail hard if specified backend doesn't exist
  local backend_file

  backend_file="${_TS_BACKENDS_DIR}/signing-${signing_backend}.sh"
  if [ -f "$backend_file" ]; then
    source "$backend_file"
  else
    echo "Touchstone: signing backend '${signing_backend}' not found at ${backend_file}" >&2
    return 1
  fi

  backend_file="${_TS_BACKENDS_DIR}/identity-${identity_backend}.sh"
  if [ -f "$backend_file" ]; then
    source "$backend_file"
  else
    echo "Touchstone: identity backend '${identity_backend}' not found at ${backend_file}" >&2
    return 1
  fi

  backend_file="${_TS_BACKENDS_DIR}/roles-${roles_backend}.sh"
  if [ -f "$backend_file" ]; then
    source "$backend_file"
  else
    echo "Touchstone: roles backend '${roles_backend}' not found at ${backend_file}" >&2
    return 1
  fi
}
