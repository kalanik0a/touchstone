#!/usr/bin/env bash
# ── Touchstone Policy Engine ──────────────────────────────────────
# Pattern-based policy decision point (PDP) for consent requests.
# Evaluates commands against deny/warn rules BEFORE the consent
# window opens. Known-bad patterns never reach the human reviewer.
#
# Policy files: ~/.touchstone/policy.conf (user), lib/default-policy.conf (builtin)
# Format: action:pattern:description
#   action: deny | warn
#   pattern: shell glob matched against the full command string
#   description: human-readable reason
#
# Standards: NIST 800-207 PDP/PEP, CISA ZTMM Advanced
# SPDX-License-Identifier: MIT

_TS_POLICY_RULE=""  # Set by _ts_policy_check on match
_TS_USER_POLICY="${HOME}/.touchstone/policy.conf"
_TS_DEFAULT_POLICY="${TOUCHSTONE_LIB}/default-policy.conf"

# ── Policy Check ──────────────────────────────────────────────────
# Returns 0 if command is allowed, 1 if denied.
# Sets _TS_POLICY_RULE to the matching rule on deny.
#
# [NIST 800-207] Policy Decision Point — evaluated before every
# consent request. Deny decisions are logged and never reach
# the authentication boundary.

_ts_policy_check() {
  local cmd_string=""
  cmd_string=$(printf '%s ' "$@")
  _TS_POLICY_RULE=""

  # Load and evaluate policy files (user overrides come first)
  local policy_file
  for policy_file in "$_TS_USER_POLICY" "$_TS_DEFAULT_POLICY"; do
    [ -f "$policy_file" ] || continue

    while IFS=: read -r action pattern description; do
      # Skip comments and blank lines
      case "$action" in
        '#'*|'') continue ;;
      esac

      # [CWE-78] Pattern is used with bash case/glob only, never eval'd
      # shellcheck disable=SC2254
      case "$cmd_string" in
        $pattern|$pattern\ *)
          case "$action" in
            deny)
              _TS_POLICY_RULE="${action}:${pattern}:${description}"
              printf '\033[1;31m[POLICY DENY]\033[0m %s\n' "$description" >&2
              printf '\033[2m  Rule: %s\033[0m\n' "$pattern" >&2
              printf '\033[2m  Command: %s\033[0m\n' "$cmd_string" >&2
              return 1
              ;;
            warn)
              printf '\033[1;33m[POLICY WARN]\033[0m %s\n' "$description" >&2
              printf '\033[2m  Rule: %s\033[0m\n' "$pattern" >&2
              # Warn but allow — continue to consent window
              ;;
          esac
          ;;
      esac
    done < "$policy_file"
  done

  return 0
}

# ── Policy Management ─────────────────────────────────────────────

_ts_policy_list() {
  echo "=== Active Policy Rules ==="
  echo ""

  if [ -f "$_TS_USER_POLICY" ]; then
    printf '\033[1;36mUser policy:\033[0m %s\n' "$_TS_USER_POLICY"
    grep -v '^#' "$_TS_USER_POLICY" 2>/dev/null | grep -v '^$' | while IFS=: read -r action pattern description; do
      case "$action" in
        deny) printf '  \033[1;31m%-5s\033[0m %-40s %s\n' "$action" "$pattern" "$description" ;;
        warn) printf '  \033[1;33m%-5s\033[0m %-40s %s\n' "$action" "$pattern" "$description" ;;
      esac
    done
    echo ""
  fi

  if [ -f "$_TS_DEFAULT_POLICY" ]; then
    printf '\033[1;36mBuiltin policy:\033[0m %s\n' "$_TS_DEFAULT_POLICY"
    grep -v '^#' "$_TS_DEFAULT_POLICY" 2>/dev/null | grep -v '^$' | while IFS=: read -r action pattern description; do
      case "$action" in
        deny) printf '  \033[1;31m%-5s\033[0m %-40s %s\n' "$action" "$pattern" "$description" ;;
        warn) printf '  \033[1;33m%-5s\033[0m %-40s %s\n' "$action" "$pattern" "$description" ;;
      esac
    done
  fi
}
