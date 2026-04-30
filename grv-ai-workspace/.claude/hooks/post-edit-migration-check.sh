#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# post-edit-migration-check.sh — Claude Code PostToolUse hook (Edit|Write)
# -----------------------------------------------------------------------------
# Advierte cuando se edita un archivo de migración SQL para que se corra
# el skill mariadb-migration-review. No bloquea.
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

# Patrón de archivos de migración (soporta / y \)
if echo "$FILE_PATH" | grep -qE '(db[/\\]migration[/\\]V[0-9]+__.*\.sql|\.sql$)' 2>/dev/null; then
  # Solo matchear si parece una migración Flyway-style o está en carpeta migration
  if echo "$FILE_PATH" | grep -qiE '(migration|migrate|flyway|V[0-9]+__)' 2>/dev/null; then
    echo "Detectado cambio en archivo de migración: $(basename "$FILE_PATH")"
    echo "Se recomienda correr el skill mariadb-migration-review antes de mergear."
  fi
fi

exit 0
