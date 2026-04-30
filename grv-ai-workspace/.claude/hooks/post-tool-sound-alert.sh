#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# post-tool-sound-alert.sh
# -----------------------------------------------------------------------------
# Propósito: reproducir alertas sonoras agradables para eventos de Claude Code.
# Dispara en: PostTool o comando manual.
# Modo: opt-in; activar con `.claude/hooks/post-tool-sound-alert.sh on`.
# -----------------------------------------------------------------------------

set -euo pipefail

CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/grv-ai-workspace"
STATE_FILE="$CONFIG_DIR/sound-alert.enabled"
SOUND_DIR="${TMPDIR:-/tmp}/grv-ai-workspace-sounds"
COMMAND="${1:-hook}"

mkdir -p "$CONFIG_DIR" "$SOUND_DIR"

is_enabled() {
  [[ -f "$STATE_FILE" ]] && [[ "$(cat "$STATE_FILE" 2>/dev/null)" == "true" ]]
}

case "$COMMAND" in
  on|enable)
    echo "true" > "$STATE_FILE"
    echo "🔔 Sound alerts activadas."
    exit 0
    ;;
  off|disable)
    echo "false" > "$STATE_FILE"
    echo "🔕 Sound alerts desactivadas."
    exit 0
    ;;
  status)
    if is_enabled; then
      echo "🔔 Sound alerts activadas."
    else
      echo "🔕 Sound alerts desactivadas."
    fi
    exit 0
    ;;
  test)
    echo "true" > "$STATE_FILE"
    COMMAND="play"
    shift || true
    EVENT="${1:-complete}"
    ;;
esac

if ! is_enabled; then
  exit 0
fi

PAYLOAD="$(cat || true)"
EVENT="${2:-${GRV_SOUND_EVENT:-}}"

if [[ "$COMMAND" == "play" ]]; then
  EVENT="${EVENT:-${2:-complete}}"
elif [[ -z "$EVENT" ]] && [[ -n "$PAYLOAD" ]] && command -v python3 >/dev/null 2>&1; then
  EVENT="$(PAYLOAD="$PAYLOAD" python3 - <<'PY' 2>/dev/null || true
import json
import os

try:
    payload = json.loads(os.environ.get("PAYLOAD", ""))
except Exception:
    payload = {}

tool = (payload.get("tool_name") or payload.get("tool") or "").lower()
message = json.dumps(payload, ensure_ascii=False).lower()

if "skill" in tool or "skill" in message:
    print("skill")
elif tool == "task" or "subagent" in message or "subagente" in message:
    print("subagent")
elif "plan" in message:
    print("plan")
elif "error" in message or "permission" in message or "needs_attention" in message:
    print("attention")
elif tool:
    print("complete")
else:
    print("")
PY
)"
fi

if [[ -z "$EVENT" ]]; then
  exit 0
fi

sound_spec() {
  case "$1" in
    attention) echo "660:0.14 0:0.04 880:0.18" ;;
    complete) echo "523:0.10 659:0.10 784:0.18" ;;
    plan) echo "392:0.10 523:0.12 659:0.16" ;;
    skill) echo "587:0.08 740:0.08 880:0.14" ;;
    subagent) echo "440:0.08 554:0.10 659:0.14" ;;
    *) echo "523:0.10 659:0.10 784:0.18" ;;
  esac
}

make_sound() {
  local event="$1"
  local file="$SOUND_DIR/$event.wav"

  if [[ -f "$file" ]]; then
    echo "$file"
    return 0
  fi

  if ! command -v python3 >/dev/null 2>&1; then
    return 1
  fi

  EVENT="$event" SPEC="$(sound_spec "$event")" FILE="$file" python3 - <<'PY' >/dev/null 2>&1
import math
import os
import struct
import wave

spec = os.environ["SPEC"].split()
path = os.environ["FILE"]
rate = 44100
amplitude = 12000

frames = bytearray()
for part in spec:
    freq_s, dur_s = part.split(":")
    freq = float(freq_s)
    duration = float(dur_s)
    samples = int(rate * duration)
    for i in range(samples):
        if freq == 0:
            value = 0
        else:
            envelope = min(1.0, i / max(1, rate * 0.02), (samples - i) / max(1, rate * 0.03))
            value = int(amplitude * envelope * math.sin(2 * math.pi * freq * i / rate))
        frames.extend(struct.pack("<h", value))

with wave.open(path, "wb") as fh:
    fh.setnchannels(1)
    fh.setsampwidth(2)
    fh.setframerate(rate)
    fh.writeframes(frames)
PY

  echo "$file"
}

play_sound() {
  local file="$1"

  if command -v afplay >/dev/null 2>&1; then
    afplay "$file" >/dev/null 2>&1 &
  elif command -v paplay >/dev/null 2>&1; then
    paplay "$file" >/dev/null 2>&1 &
  elif command -v pw-play >/dev/null 2>&1; then
    pw-play "$file" >/dev/null 2>&1 &
  elif command -v aplay >/dev/null 2>&1; then
    aplay "$file" >/dev/null 2>&1 &
  elif command -v ffplay >/dev/null 2>&1; then
    ffplay -nodisp -autoexit "$file" >/dev/null 2>&1 &
  elif command -v play >/dev/null 2>&1; then
    play "$file" >/dev/null 2>&1 &
  else
    printf '\a'
  fi
}

FILE="$(make_sound "$EVENT" || true)"
if [[ -n "$FILE" ]]; then
  play_sound "$FILE"
else
  printf '\a'
fi

exit 0
