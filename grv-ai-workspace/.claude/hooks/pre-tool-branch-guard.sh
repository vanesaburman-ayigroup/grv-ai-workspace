#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# pre-tool-branch-guard.sh
# -----------------------------------------------------------------------------
# Propósito: advertir o bloquear cambios hechos por herramientas en ramas protegidas.
# Dispara en: PreTool / antes de herramientas que pueden modificar archivos.
# Modo: warn por default; blocking con GRV_BRANCH_GUARD_MODE=block.
# -----------------------------------------------------------------------------

set -euo pipefail

MODE="${GRV_BRANCH_GUARD_MODE:-warn}"
DISABLED="${GRV_BRANCH_GUARD_DISABLED:-false}"
PROTECTED_PATTERN="${GRV_BRANCH_GUARD_PROTECTED:-^(main|master|develop|release/.+)$}"
MUTATING_TOOLS_PATTERN="${GRV_BRANCH_GUARD_TOOLS:-^(Edit|MultiEdit|Write|NotebookEdit|Bash|Task)$}"

if [[ "$DISABLED" == "true" ]] || [[ "$DISABLED" == "1" ]]; then
  exit 0
fi

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  exit 0
fi

BRANCH="$(git branch --show-current 2>/dev/null || true)"
if [[ -z "$BRANCH" ]] || [[ ! "$BRANCH" =~ $PROTECTED_PATTERN ]]; then
  exit 0
fi

PAYLOAD="$(cat || true)"
TOOL_NAME="${1:-}"

if [[ -z "$TOOL_NAME" ]] && [[ -n "$PAYLOAD" ]] && command -v python3 >/dev/null 2>&1; then
  TOOL_NAME="$(PAYLOAD="$PAYLOAD" python3 - <<'PY' 2>/dev/null || true
import json
import os

try:
    payload = json.loads(os.environ.get("PAYLOAD", ""))
except (json.JSONDecodeError, TypeError, ValueError):
    payload = {}

print(payload.get("tool_name") or payload.get("tool") or "")
PY
)"
fi

if [[ -n "$TOOL_NAME" ]] && [[ ! "$TOOL_NAME" =~ $MUTATING_TOOLS_PATTERN ]]; then
  exit 0
fi

echo ""
echo "🛡️  grv-ai-workspace: estás en una rama protegida ($BRANCH)."
echo "   Crear una rama de trabajo antes de editar evita commits accidentales en main/develop."
echo "   Ejemplo: git switch -c feat/<descripcion-corta>"

if [[ "$MODE" == "block" ]] || [[ "$MODE" == "blocking" ]]; then
  echo "   Modo blocking: herramienta bloqueada. Usar GRV_BRANCH_GUARD_DISABLED=true para saltear."
  echo ""
  exit 1
fi

echo "   Warn mode: no se bloquea la herramienta."
echo ""

exit 0
