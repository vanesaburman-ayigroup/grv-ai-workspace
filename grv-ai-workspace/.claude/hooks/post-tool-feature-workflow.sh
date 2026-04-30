#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# post-tool-feature-workflow.sh
# -----------------------------------------------------------------------------
# Propósito: recordar checks de cierre al terminar una implementación de feature.
# Dispara en: PostTool o comando manual (`done`, `feature-done`, `checklist`).
# Modo: warn; no bloquea.
# -----------------------------------------------------------------------------

set -euo pipefail

COMMAND="${1:-hook}"
DISABLED="${GRV_FEATURE_WORKFLOW_DISABLED:-false}"

if [[ "$DISABLED" == "true" ]] || [[ "$DISABLED" == "1" ]]; then
  exit 0
fi

PAYLOAD=""
if [[ ! -t 0 ]]; then
  PAYLOAD="$(cat || true)"
fi

should_emit() {
  case "$COMMAND" in
    done|feature-done|checklist)
      return 0
      ;;
  esac

  if [[ -z "$PAYLOAD" ]] || ! command -v python3 >/dev/null 2>&1; then
    return 1
  fi

  PAYLOAD="$PAYLOAD" python3 - <<'PY' >/dev/null 2>&1
import json
import os
import re
import sys

try:
    payload = json.loads(os.environ.get("PAYLOAD", ""))
except (json.JSONDecodeError, TypeError, ValueError):
    payload = {}

texts = []

def walk(value, depth=0):
    if depth > 8:
        return
    if isinstance(value, str):
        texts.append(value.lower())
    elif isinstance(value, dict):
        for item in value.values():
            walk(item, depth + 1)
    elif isinstance(value, list):
        for item in value:
            walk(item, depth + 1)

walk(payload)
text = " ".join(texts)
feature = re.search(r"\b(feature|implementaci[oó]n|funcionalidad)\b", text)
done = re.search(r"\b(done|complete|completed|finished|terminad[oa]|implementad[oa])\b", text)
sys.exit(0 if feature and done else 1)
PY
}

if ! should_emit; then
  exit 0
fi

CHANGED_FILES=""
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  CHANGED_FILES="$(git diff --name-only --diff-filter=ACM && git diff --cached --name-only --diff-filter=ACM)"
fi

echo ""
echo "✅ grv-ai-workspace: checklist de cierre de feature"
echo "   - Si hay TypeScript, corré/validá lint + typecheck del MFE. El hook pre-commit-typescript-quality los ejecuta si existen scripts."

if echo "$CHANGED_FILES" | grep -E '(^|/)(db/)?migration/.*\.sql$|\.sql$' >/dev/null 2>&1; then
  echo "   - Hay SQL/migraciones en el diff: corré el skill mariadb-migration-review con contexto de servicio y objetivo de negocio."
else
  echo "   - Si la feature requiere SQL, corré el skill mariadb-migration-review antes del commit/MR."
fi

echo "   - Actualizá o pedí el skill changelog-keeper antes de cerrar la feature/release."
echo "   - Si quedan pasos de rollout, deuda o decisiones abiertas, usá /plan para dejar el próximo tramo explícito."
echo ""

exit 0
