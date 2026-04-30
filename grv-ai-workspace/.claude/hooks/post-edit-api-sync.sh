#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# post-edit-api-sync.sh — Claude Code PostToolUse hook (Edit|Write)
# -----------------------------------------------------------------------------
# Advierte cuando se edita un controller Spring Boot para revisar si
# Swagger/OpenAPI necesita actualización. No bloquea.
# -----------------------------------------------------------------------------

set -euo pipefail

INPUT=$(cat)

PYTHON=$(command -v python 2>/dev/null || command -v python3 2>/dev/null || echo "")
if [[ -z "$PYTHON" ]]; then
  exit 0
fi

FILE_PATH=$($PYTHON -c "
import sys, json
d = json.load(sys.stdin).get('tool_input', {})
print(d.get('file_path', ''))
" <<< "$INPUT" 2>/dev/null || echo "")

if [[ -z "$FILE_PATH" ]]; then
  exit 0
fi

if echo "$FILE_PATH" | grep -qE 'Controller\.(java|kt)$' 2>/dev/null; then
  echo "Detectado cambio en controller: $(basename "$FILE_PATH")"
  echo "Revisar si Swagger/OpenAPI necesita actualización."
fi

exit 0
