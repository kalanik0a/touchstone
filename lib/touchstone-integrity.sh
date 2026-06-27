#!/usr/bin/env bash
# ── Touchstone Output Integrity ───────────────────────────────────
# Signing and verification of captured command output.
# Delegates to the active signing backend.
#
# Standards: NIST 800-53 SI-7 (Software/Information Integrity)
# SPDX-License-Identifier: MIT

_ts_sign_output() {
  _ts_backend_sign_output "$@"
}

_ts_verify_output() {
  _ts_backend_verify_output "$@"
}
