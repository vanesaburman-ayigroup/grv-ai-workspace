#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# post-tool-cost-tracker.sh
# -----------------------------------------------------------------------------
# Propósito: registrar uso/costo reportado por Claude Code después de herramientas.
# Dispara en: PostTool.
# Modo: observability; nunca bloquea.
# -----------------------------------------------------------------------------

set -euo pipefail

LOG_DIR=".claude/logs"
LOG_FILE="$LOG_DIR/cost-tracker.jsonl"
COMMAND="${1:-log}"

mkdir -p "$LOG_DIR"

if [[ "$COMMAND" == "summary" ]]; then
  if [[ ! -f "$LOG_FILE" ]]; then
    echo "💸 grv-ai-workspace: no hay datos de costo todavía."
    exit 0
  fi

  python3 - "$LOG_FILE" <<'PY'
import json
import sys
from collections import defaultdict

totals = defaultdict(float)
count = 0

with open(sys.argv[1], encoding="utf-8") as fh:
    for line in fh:
        try:
            event = json.loads(line)
        except Exception:
            continue
        count += 1
        for key in ("input_tokens", "output_tokens", "total_tokens", "estimated_cost_usd", "reported_cost_usd"):
            value = event.get(key)
            if isinstance(value, (int, float)):
                totals[key] += value

print("💸 grv-ai-workspace: resumen de uso")
print(f"   Eventos registrados: {count}")
for key in ("input_tokens", "output_tokens", "total_tokens"):
    if totals[key]:
        print(f"   {key}: {int(totals[key])}")
if totals["reported_cost_usd"]:
    print(f"   Costo reportado: USD {totals['reported_cost_usd']:.4f}")
if totals["estimated_cost_usd"]:
    print(f"   Costo estimado:  USD {totals['estimated_cost_usd']:.4f}")
PY
  exit 0
fi

PAYLOAD="$(cat || true)"

PAYLOAD="$PAYLOAD" python3 - "$LOG_FILE" <<'PY' 2>/dev/null || true
import datetime as dt
import json
import os
import sys

try:
    MAX_RECURSION_DEPTH = int(os.environ.get("GRV_COST_TRACKER_MAX_DEPTH", "12"))
except ValueError:
    MAX_RECURSION_DEPTH = 12

log_file = sys.argv[1]
raw = os.environ.get("PAYLOAD", "")

try:
    payload = json.loads(raw) if raw.strip() else {}
except (json.JSONDecodeError, TypeError, ValueError):
    payload = {"raw": raw[:500]}

def find_number(value, names, depth=0):
    if depth > MAX_RECURSION_DEPTH:
        return None
    if isinstance(value, dict):
        for key, item in value.items():
            if key in names and isinstance(item, (int, float)):
                return item
            found = find_number(item, names, depth + 1)
            if found is not None:
                return found
    elif isinstance(value, list):
        for item in value:
            found = find_number(item, names, depth + 1)
            if found is not None:
                return found
    return None

input_tokens = find_number(payload, {"input_tokens", "prompt_tokens"})
output_tokens = find_number(payload, {"output_tokens", "completion_tokens"})
total_tokens = find_number(payload, {"total_tokens"})
reported_cost = find_number(payload, {"cost_usd", "total_cost_usd"})

if total_tokens is None and (input_tokens is not None or output_tokens is not None):
    total_tokens = (input_tokens or 0) + (output_tokens or 0)

input_rate = float(os.environ.get("GRV_COST_INPUT_USD_PER_MTOK", "0") or "0")
output_rate = float(os.environ.get("GRV_COST_OUTPUT_USD_PER_MTOK", "0") or "0")
estimated_cost = None
if input_rate or output_rate:
    estimated_cost = ((input_tokens or 0) * input_rate + (output_tokens or 0) * output_rate) / 1_000_000

event = {
    "timestamp": dt.datetime.now(dt.timezone.utc).isoformat(),
    "tool_name": payload.get("tool_name") or payload.get("tool"),
    "session_id": payload.get("session_id"),
    "input_tokens": input_tokens,
    "output_tokens": output_tokens,
    "total_tokens": total_tokens,
    "reported_cost_usd": reported_cost,
    "estimated_cost_usd": estimated_cost,
}

with open(log_file, "a", encoding="utf-8") as fh:
    fh.write(json.dumps(event, ensure_ascii=False, sort_keys=True) + "\n")

if reported_cost is not None:
    print(f"💸 grv-ai-workspace: costo reportado USD {reported_cost:.4f}")
elif estimated_cost is not None:
    print(f"💸 grv-ai-workspace: costo estimado USD {estimated_cost:.4f}")
PY

exit 0
