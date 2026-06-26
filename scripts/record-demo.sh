#!/usr/bin/env bash
# ── Touchstone Demo Recorder ────────────────────────────────────────
# Records a WezTerm window via ffmpeg x11grab.
#
# Usage:
#   ./scripts/record-demo.sh <name> <ts-command...>
#
# Example:
#   ./scripts/record-demo.sh sudo ts-sudo whoami
#   ./scripts/record-demo.sh ssh ts-ssh seanlum@visionlighter.mitonet.arpa whoami
#   ./scripts/record-demo.sh run ts-run echo "hello"
#
# Records to: outputs/<name>.mp4
# Press q in the recording terminal to stop.

set -euo pipefail

NAME="${1:?Usage: record-demo.sh <name> <ts-command...>}"
shift
CMD=("$@")

OUTDIR="$(cd "$(dirname "$0")/.." && pwd)/outputs"
mkdir -p "$OUTDIR"
OUTFILE="$OUTDIR/${NAME}.mp4"

echo ""
echo "  Touchstone Demo Recorder"
echo "  ────────────────────────────────────────"
echo "  Recording: ${CMD[*]}"
echo "  Output:    $OUTFILE"
echo ""
echo "  Steps:"
echo "    1. Press Enter to start recording + launch the command"
echo "    2. Authenticate in the WezTerm window (password + YubiKey)"
echo "    3. When done, the recording stops automatically"
echo ""
read -rp "  Press Enter to begin..."

# Launch the touchstone command in background
DONEFILE=$(mktemp /tmp/ts-rec-XXXXXX.done)
rm -f "$DONEFILE"

(
  cd "$(dirname "$0")/.."
  ./bin/"${CMD[@]}" 2>/dev/null
  touch "$DONEFILE"
) &
CMD_PID=$!

# Wait for WezTerm window to appear
sleep 2

# Find the WezTerm window geometry
WIN_ID=$(xdotool search --class "touchstone-" 2>/dev/null | head -1 || true)

if [ -z "$WIN_ID" ]; then
  echo "  Could not find Touchstone window. Falling back to full-screen capture."
  # Full screen capture of primary display
  GEOMETRY="1920x1200"
  OFFSET="+0,0"
else
  # Get window geometry
  eval "$(xdotool getwindowgeometry --shell "$WIN_ID")"
  GEOMETRY="${WIDTH}x${HEIGHT}"
  OFFSET="+${X},${Y}"
  echo "  Found window: ${GEOMETRY} at ${OFFSET}"
fi

echo "  Recording... (will stop when command finishes)"
echo ""

# Record until the command finishes
ffmpeg -y -video_size "$GEOMETRY" -framerate 30 \
  -f x11grab -i ":0${OFFSET}" \
  -c:v libx264 -preset fast -crf 23 -pix_fmt yuv420p \
  "$OUTFILE" &
FFMPEG_PID=$!

# Wait for the touchstone command to finish
wait $CMD_PID 2>/dev/null || true

# Give a moment for the final frame
sleep 1

# Stop recording
kill "$FFMPEG_PID" 2>/dev/null || true
wait "$FFMPEG_PID" 2>/dev/null || true

rm -f "$DONEFILE"

echo ""
echo "  Recorded: $OUTFILE"
echo "  Duration: $(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$OUTFILE" 2>/dev/null | cut -d. -f1)s"
echo ""
