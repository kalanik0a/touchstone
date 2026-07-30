#!/usr/bin/env bash
# Regression: an existing empty HMAC file must be atomically regenerated.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

_TS_HMAC_KEY="$TMP/hmac.key"
_TS_OPENSSL="$(command -v openssl)"
: > "$_TS_HMAC_KEY"
chmod 0644 "$_TS_HMAC_KEY"

# shellcheck source=../lib/backends/signing-local.sh
source "$ROOT/lib/backends/signing-local.sh"
_ts_backend_sign_init

test -s "$_TS_HMAC_KEY"
test "$(wc -c < "$_TS_HMAC_KEY")" -eq 65
test "$(stat -c '%a' "$_TS_HMAC_KEY")" = "400"
printf '%s\n' 'empty-key regeneration: PASS'
