#!/usr/bin/env bash
# ── Touchstone Core ──────────────────────────────────────────────────
# Hardware-bound privilege consent for AI coding agents.
# Three-pane WezTerm UI with PAM + FIDO2 integration.
#
# This file contains the shared launcher logic used by all touchstone
# tools (ts-sudo, ts-ssh, ts-scp, ts-sftp, ts-run).
#
# SPDX-License-Identifier: MIT

set -euo pipefail

# ── Security Hardening ───────────────────────────────────────────────
# [CWE-200, CWE-377] All temp files owner-only
umask 077

# [CWE-426] Restrict PATH to known-safe system directories
# [CWE-668] _TS_ORIG_PATH is NOT exported — only used by inspector pane
_TS_ORIG_PATH="${PATH}"
PATH="/run/wrappers/bin:/run/current-system/sw/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

# Resolve lib directory (where this script and assets live)
TOUCHSTONE_LIB="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOUCHSTONE_WEZ_CONFIG="${TOUCHSTONE_LIB}/wezterm-config.lua"

# ── Temp Directory ───────────────────────────────────────────────────
# [CWE-367, CWE-59] Single private temp dir per invocation.
# mktemp -d creates mode 0700 with umask 077. All temp files go here.
# Eliminates symlink attacks and TOCTOU races on individual files.

_ts_mktmpdir() {
  local label="$1"
  mktemp -d "/tmp/ts-${label}-XXXXXX"
}

# ── Cleanup ──────────────────────────────────────────────────────────
# [CWE-459] Signal-safe cleanup. Registered via trap in both launchers.

_ts_cleanup() {
  local tmpdir="$1"
  [ -d "$tmpdir" ] && rm -rf "$tmpdir"
}

# ── Label Validation ─────────────────────────────────────────────────
# [CWE-78, CWE-88] Prevent injection via LABEL parameter.

_ts_validate_label() {
  local label="$1"
  if [[ ! "$label" =~ ^[a-zA-Z0-9_-]+$ ]]; then
    echo "Touchstone: invalid label '$label'" >&2
    return 1
  fi
}

# ── Args File ────────────────────────────────────────────────────────
# [CWE-78] Write arguments to a NUL-delimited file instead of
# interpolating them into heredocs. The generated scripts read
# args back with readarray, avoiding eval/expansion chains.

_ts_write_args_file() {
  local argsfile="$1"; shift
  printf '%s\0' "$@" > "$argsfile"
}

# ── Code Review Pane ─────────────────────────────────────────────────

_ts_write_code_review() {
  local REVIEW_FILE="$1" LABEL="$2"; shift 2
  cat > "$REVIEW_FILE" << 'CODEEOF'
#!/usr/bin/env bash
LABEL="$1"; shift

{
  printf '\033[1;36m── %s ─── Code Review ──────────────────────\033[0m\n\n' "$LABEL"

  printf '\033[1;33m$\033[0m '
  for arg in "$@"; do
    case "$arg" in
      *\ *|*\**|*\?*) printf "'%s' " "$arg" ;;
      *) printf '%s ' "$arg" ;;
    esac
  done
  printf '\n\n'

  FOUND=0

  if [ "$1" = "make" ] || [ "$1" = "sudo" -a "${2:-}" = "make" ]; then
    MAKE_ARGS=("$@")
    TARGET=""
    for arg in "${MAKE_ARGS[@]}"; do
      case "$arg" in
        make|sudo|--no-print-directory) ;;
        *=*|-*) ;;
        *)
          if [ -z "$TARGET" ] && [ "$arg" != "make" ] && [ "$arg" != "sudo" ]; then
            TARGET="$arg"
          fi ;;
      esac
    done
    for mf in Makefile makefile GNUmakefile; do
      if [ -f "$mf" ]; then
        FOUND=1
        printf '\033[2m── Makefile: %s → target: %s ──\033[0m\n\n' "$mf" "$TARGET"
        cat -n "$mf"
        break
      fi
    done
  fi

  if [ "$FOUND" -eq 0 ]; then
    for arg in "$@"; do
      if [ -f "$arg" ]; then
        FOUND=1
        printf '\033[2m── %s ──\033[0m\n\n' "$arg"
        cat -n "$arg"
        break
      fi
    done
  fi

  if [ "$FOUND" -eq 0 ]; then
    printf '\033[2m── No script source found. Command resolution: ──\033[0m\n\n'
    for arg in "$@"; do
      LOC=$(which "$arg" 2>/dev/null || echo "")
      if [ -n "$LOC" ]; then
        printf '  %s → %s\n' "$arg" "$LOC"
        file "$LOC" 2>/dev/null | sed 's/^/    /'
      fi
    done
  fi

  printf '\n\033[2m── Ctrl+1 (exec) | Ctrl+2 (code) | Ctrl+3 (inspect) ──\033[0m\n'
} | less -R -N --prompt="[Touchstone Code Review] line %lt  q=dismiss  /=search"

sleep infinity
CODEEOF
  chmod 0700 "$REVIEW_FILE"
}

# ── Inspector Shell ──────────────────────────────────────────────────

_ts_write_inspector() {
  local INSPECTOR_FILE="$1" LABEL="$2"; shift 2
  cat > "$INSPECTOR_FILE" << 'INSPEOF'
#!/usr/bin/env bash
LABEL="$1"; shift
SCRIPT_PATH=""
CMD_ARGS=("$@")

for arg in "${CMD_ARGS[@]}"; do
  if [ -f "$arg" ]; then SCRIPT_PATH="$arg"; break; fi
done

inspect() {
  if [ -n "$SCRIPT_PATH" ]; then
    less -R -N "$SCRIPT_PATH"
  else
    printf '\033[33mNo script file detected. Command: %s\033[0m\n' "${CMD_ARGS[*]}"
  fi
}

deps() {
  printf '\033[1;36m── Dependencies ──\033[0m\n'
  if [ -n "$SCRIPT_PATH" ]; then
    grep -oE '^\s*(sudo\s+)?[a-zA-Z_][a-zA-Z0-9_-]*' "$SCRIPT_PATH" 2>/dev/null \
      | sed 's/^\s*//' | sed 's/^sudo\s*//' \
      | sort -u | while read -r cmd; do
        LOC=$(which "$cmd" 2>/dev/null || echo "not found")
        printf '  %-20s → %s\n' "$cmd" "$LOC"
      done
  else
    for arg in "${CMD_ARGS[@]}"; do
      LOC=$(which "$arg" 2>/dev/null || echo "")
      [ -n "$LOC" ] && printf '  %-20s → %s\n' "$arg" "$LOC"
    done
  fi
}

perms() {
  printf '\033[1;36m── Permissions ──\033[0m\n'
  if [ -n "$SCRIPT_PATH" ]; then
    ls -la "$SCRIPT_PATH"
    printf '\n'
    file "$SCRIPT_PATH"
  fi
  for arg in "${CMD_ARGS[@]}"; do
    LOC=$(which "$arg" 2>/dev/null || echo "")
    [ -n "$LOC" ] && ls -la "$LOC"
  done
}

show_env() {
  printf '\033[1;36m── Environment (sensitive vars filtered) ──\033[0m\n'
  env | sort | grep -vE '^(LS_COLORS|LESS_TERMCAP|.*TOKEN.*|.*SECRET.*|.*KEY.*|.*PASSWORD.*|.*CREDENTIAL.*|.*AUTH.*)=' | less -R
}

show_help() {
  printf '\n'
  printf '  \033[1;36m┌─────────────────────────────────────────┐\033[0m\n'
  printf '  \033[1;36m│\033[0m  \033[1mTouchstone Inspector — %s\033[0m\n' "$LABEL"
  printf '  \033[1;36m├─────────────────────────────────────────┤\033[0m\n'
  printf '  \033[1;36m│\033[0m  \033[1;33minspect\033[0m   — view script source (less)    \033[1;36m│\033[0m\n'
  printf '  \033[1;36m│\033[0m  \033[1;33mdeps\033[0m      — show binary dependencies     \033[1;36m│\033[0m\n'
  printf '  \033[1;36m│\033[0m  \033[1;33mperms\033[0m     — file permissions & types      \033[1;36m│\033[0m\n'
  printf '  \033[1;36m│\033[0m  \033[1;33mshow_env\033[0m  — environment variables         \033[1;36m│\033[0m\n'
  printf '  \033[1;36m│\033[0m  \033[1;33mman CMD\033[0m   — manual page for a command     \033[1;36m│\033[0m\n'
  printf '  \033[1;36m│\033[0m  \033[1;33m?\033[0m         — show this menu again          \033[1;36m│\033[0m\n'
  printf '  \033[1;36m│\033[0m                                           \033[1;36m│\033[0m\n'
  printf '  \033[1;36m│\033[0m  \033[2mFull shell — run any command.\033[0m              \033[1;36m│\033[0m\n'
  printf '  \033[1;36m│\033[0m  \033[2mCtrl+1/2/3 to switch panes.\033[0m                \033[1;36m│\033[0m\n'
  printf '  \033[1;36m└─────────────────────────────────────────┘\033[0m\n'
  printf '\n'
}

alias '?=show_help'
export -f inspect deps perms show_env show_help
export SCRIPT_PATH CMD_ARGS LABEL

PS1='\[\033[1;35m\]touchstone\[\033[0m\]:\[\033[1;34m\]\w\[\033[0m\]\$ '

show_help
exec bash --norc --noprofile -i
INSPEOF
  chmod 0700 "$INSPECTOR_FILE"
}

# ── Three-Pane Launcher: Captured Mode ───────────────────────────────
# Output captured to file and returned to caller.
# Used by: ts-sudo, ts-ssh, ts-scp, ts-sftp

ts_launch_captured() {
  local LABEL="$1"; shift
  _ts_validate_label "$LABEL"

  local TS_TMPDIR
  TS_TMPDIR=$(_ts_mktmpdir "$LABEL")

  # [CWE-459] Cleanup on any exit — normal, error, or signal
  trap "_ts_cleanup '$TS_TMPDIR'" EXIT INT TERM HUP

  local OUTFILE="$TS_TMPDIR/output"
  local RCFILE="$TS_TMPDIR/rc"
  local DONEFILE="$TS_TMPDIR/done"
  local MAIN_SCRIPT="$TS_TMPDIR/main.sh"
  local CODE_SCRIPT="$TS_TMPDIR/code.sh"
  local INSPECTOR_SCRIPT="$TS_TMPDIR/insp.sh"
  local ARGS_FILE="$TS_TMPDIR/args"

  _ts_write_args_file "$ARGS_FILE" "$@"
  _ts_write_code_review "$CODE_SCRIPT" "$LABEL" "$@"
  _ts_write_inspector "$INSPECTOR_SCRIPT" "$LABEL" "$@"

  if command -v wezterm &>/dev/null; then
    # [CWE-78] Quoted heredoc — no shell expansion inside.
    # [CWE-668] TS_* env vars stripped before executing the privileged command
    #           via env -u, preventing output/RC file tampering and PATH leak.
    cat > "$MAIN_SCRIPT" << 'MAINEOF'
#!/usr/bin/env bash
# Read args from NUL-delimited file
readarray -d '' CMD_ARGS < "$TS_ARGS_FILE"

# Signal that the terminal launched successfully
touch "$TS_DONEFILE.started"

CODE_PANE=$(wezterm cli split-pane --bottom --percent 50 -- bash "$TS_CODE_SCRIPT" "$TS_LABEL" "${CMD_ARGS[@]}")
wezterm cli activate-pane --pane-id "$CODE_PANE" 2>/dev/null || true
INSP_PANE=$(wezterm cli split-pane --bottom --percent 40 -- bash "$TS_INSP_SCRIPT" "$TS_LABEL" "${CMD_ARGS[@]}")
wezterm cli activate-pane-direction up 2>/dev/null || true
wezterm cli activate-pane-direction up 2>/dev/null || true

# Store paths before stripping env, then execute with clean environment
_out="$TS_OUTFILE" _rc="$TS_RCFILE" _done="$TS_DONEFILE"
env -u TS_ARGS_FILE -u TS_OUTFILE -u TS_RCFILE -u TS_DONEFILE \
    -u TS_LABEL -u TS_CODE_SCRIPT -u TS_INSP_SCRIPT \
    -u _TS_ORIG_PATH -u WEZTERM_CONFIG_FILE \
    "${CMD_ARGS[@]}" > "$_out" 2>&1
echo $? > "$_rc"

wezterm cli kill-pane --pane-id "$CODE_PANE" 2>/dev/null || true
wezterm cli kill-pane --pane-id "$INSP_PANE" 2>/dev/null || true
touch "$_done"
sleep 0.3
MAINEOF
    chmod 0700 "$MAIN_SCRIPT"

    # Pass paths via env vars — no heredoc interpolation
    WAYLAND_DISPLAY="" \
      WEZTERM_CONFIG_FILE="$TOUCHSTONE_WEZ_CONFIG" \
      TS_LABEL="$LABEL" \
      TS_ARGS_FILE="$ARGS_FILE" \
      TS_CODE_SCRIPT="$CODE_SCRIPT" \
      TS_INSP_SCRIPT="$INSPECTOR_SCRIPT" \
      TS_OUTFILE="$OUTFILE" \
      TS_RCFILE="$RCFILE" \
      TS_DONEFILE="$DONEFILE" \
      wezterm start --always-new-process --class "touchstone-$LABEL" -- bash "$MAIN_SCRIPT"

    # [CWE-755] Detect launch failure — if started sentinel doesn't appear in 5s, wezterm failed
    local WAIT=0
    while [ ! -f "$DONEFILE.started" ] && [ "$WAIT" -lt 25 ]; do
      sleep 0.2; WAIT=$((WAIT + 1))
    done
    if [ ! -f "$DONEFILE.started" ]; then
      echo "Touchstone: terminal emulator failed to start" >&2
      return 1
    fi

    # Wait for command completion
    WAIT=0
    while [ ! -f "$DONEFILE" ] && [ "$WAIT" -lt 1500 ]; do
      sleep 0.2; WAIT=$((WAIT + 1))
    done

    if [ ! -f "$DONEFILE" ]; then
      echo "Touchstone: command did not complete (terminal closed or timeout)" >&2
    fi
  else
    # Fallback: single-pane terminal, args via env var
    local FALLBACK_SCRIPT="$TS_TMPDIR/fallback.sh"
    cat > "$FALLBACK_SCRIPT" << 'FBEOF'
#!/usr/bin/env bash
readarray -d '' CMD_ARGS < "$TS_ARGS_FILE"
_out="$TS_OUTFILE" _rc="$TS_RCFILE"
env -u TS_ARGS_FILE -u TS_OUTFILE -u TS_RCFILE -u _TS_ORIG_PATH \
    "${CMD_ARGS[@]}" > "$_out" 2>&1
echo $? > "$_rc"
sleep 0.3
FBEOF
    chmod 0700 "$FALLBACK_SCRIPT"

    if command -v terminator &>/dev/null; then
      TS_ARGS_FILE="$ARGS_FILE" TS_OUTFILE="$OUTFILE" TS_RCFILE="$RCFILE" \
        terminator --title "Touchstone: $LABEL" -x bash "$FALLBACK_SCRIPT" 2>/dev/null
    elif command -v gnome-terminal &>/dev/null; then
      TS_ARGS_FILE="$ARGS_FILE" TS_OUTFILE="$OUTFILE" TS_RCFILE="$RCFILE" \
        gnome-terminal --title "Touchstone: $LABEL" --wait -- bash "$FALLBACK_SCRIPT"
    elif command -v xterm &>/dev/null; then
      TS_ARGS_FILE="$ARGS_FILE" TS_OUTFILE="$OUTFILE" TS_RCFILE="$RCFILE" \
        xterm -title "Touchstone: $LABEL" -e bash "$FALLBACK_SCRIPT"
    else
      echo "Touchstone: no supported terminal emulator found (need wezterm, terminator, gnome-terminal, or xterm)" >&2
      return 1
    fi
  fi

  [ -f "$OUTFILE" ] && cat "$OUTFILE"
  local RC=1
  [ -f "$RCFILE" ] && RC=$(cat "$RCFILE")
  # Cleanup handled by trap
  return "$RC"
}

# ── Three-Pane Launcher: Interactive Mode ────────────────────────────
# Command runs live in terminal. User sees output, can respond to prompts.
# Caller receives exit code only.
# Used by: ts-run

ts_launch_interactive() {
  local LABEL="$1"; shift
  _ts_validate_label "$LABEL"

  local TS_TMPDIR
  TS_TMPDIR=$(_ts_mktmpdir "$LABEL")

  trap "_ts_cleanup '$TS_TMPDIR'" EXIT INT TERM HUP

  local RCFILE="$TS_TMPDIR/rc"
  local DONEFILE="$TS_TMPDIR/done"
  local MAIN_SCRIPT="$TS_TMPDIR/main.sh"
  local CODE_SCRIPT="$TS_TMPDIR/code.sh"
  local INSPECTOR_SCRIPT="$TS_TMPDIR/insp.sh"
  local ARGS_FILE="$TS_TMPDIR/args"

  _ts_write_args_file "$ARGS_FILE" "$@"
  _ts_write_code_review "$CODE_SCRIPT" "$LABEL" "$@"
  _ts_write_inspector "$INSPECTOR_SCRIPT" "$LABEL" "$@"

  if command -v wezterm &>/dev/null; then
    cat > "$MAIN_SCRIPT" << 'MAINEOF'
#!/usr/bin/env bash
readarray -d '' CMD_ARGS < "$TS_ARGS_FILE"

touch "$TS_DONEFILE.started"

CODE_PANE=$(wezterm cli split-pane --bottom --percent 50 -- bash "$TS_CODE_SCRIPT" "$TS_LABEL" "${CMD_ARGS[@]}")
wezterm cli activate-pane --pane-id "$CODE_PANE" 2>/dev/null || true
INSP_PANE=$(wezterm cli split-pane --bottom --percent 40 -- bash "$TS_INSP_SCRIPT" "$TS_LABEL" "${CMD_ARGS[@]}")
wezterm cli activate-pane-direction up 2>/dev/null || true
wezterm cli activate-pane-direction up 2>/dev/null || true

# Strip TS_* env vars before executing privileged command
_rc="$TS_RCFILE" _done="$TS_DONEFILE"
env -u TS_ARGS_FILE -u TS_RCFILE -u TS_DONEFILE \
    -u TS_LABEL -u TS_CODE_SCRIPT -u TS_INSP_SCRIPT \
    -u _TS_ORIG_PATH -u WEZTERM_CONFIG_FILE \
    "${CMD_ARGS[@]}"
echo $? > "$_rc"

wezterm cli kill-pane --pane-id "$CODE_PANE" 2>/dev/null || true
wezterm cli kill-pane --pane-id "$INSP_PANE" 2>/dev/null || true
printf '\n\033[2mDone. Press Enter to close.\033[0m\n'
read -r
touch "$_done"
MAINEOF
    chmod 0700 "$MAIN_SCRIPT"

    WAYLAND_DISPLAY="" \
      WEZTERM_CONFIG_FILE="$TOUCHSTONE_WEZ_CONFIG" \
      TS_LABEL="$LABEL" \
      TS_ARGS_FILE="$ARGS_FILE" \
      TS_CODE_SCRIPT="$CODE_SCRIPT" \
      TS_INSP_SCRIPT="$INSPECTOR_SCRIPT" \
      TS_RCFILE="$RCFILE" \
      TS_DONEFILE="$DONEFILE" \
      wezterm start --always-new-process --class "touchstone-$LABEL" -- bash "$MAIN_SCRIPT"

    local WAIT=0
    while [ ! -f "$DONEFILE.started" ] && [ "$WAIT" -lt 25 ]; do
      sleep 0.2; WAIT=$((WAIT + 1))
    done
    if [ ! -f "$DONEFILE.started" ]; then
      echo "Touchstone: terminal emulator failed to start" >&2
      return 1
    fi

    local WAIT=0
    while [ ! -f "$DONEFILE" ] && [ "$WAIT" -lt 9000 ]; do
      sleep 0.2; WAIT=$((WAIT + 1))
    done
  else
    local FALLBACK_SCRIPT="$TS_TMPDIR/fallback.sh"
    cat > "$FALLBACK_SCRIPT" << 'FBEOF'
#!/usr/bin/env bash
readarray -d '' CMD_ARGS < "$TS_ARGS_FILE"
_rc="$TS_RCFILE"
env -u TS_ARGS_FILE -u TS_RCFILE -u _TS_ORIG_PATH \
    "${CMD_ARGS[@]}"
echo $? > "$_rc"
printf '\nDone. Press Enter.\n'
read -r
FBEOF
    chmod 0700 "$FALLBACK_SCRIPT"

    if command -v terminator &>/dev/null; then
      TS_ARGS_FILE="$ARGS_FILE" TS_RCFILE="$RCFILE" \
        terminator --title "Touchstone: $LABEL" -x bash "$FALLBACK_SCRIPT" 2>/dev/null
    elif command -v gnome-terminal &>/dev/null; then
      TS_ARGS_FILE="$ARGS_FILE" TS_RCFILE="$RCFILE" \
        gnome-terminal --title "Touchstone: $LABEL" --wait -- bash "$FALLBACK_SCRIPT"
    elif command -v xterm &>/dev/null; then
      TS_ARGS_FILE="$ARGS_FILE" TS_RCFILE="$RCFILE" \
        xterm -title "Touchstone: $LABEL" -e bash "$FALLBACK_SCRIPT"
    else
      echo "Touchstone: no supported terminal emulator found" >&2
      return 1
    fi
  fi

  local RC=1
  [ -f "$RCFILE" ] && RC=$(cat "$RCFILE")
  return "$RC"
}
