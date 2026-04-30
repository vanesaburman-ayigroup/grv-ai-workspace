#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# pre-edit-secrets.sh — Claude Code PreToolUse hook (Edit|Write)
# -----------------------------------------------------------------------------
# Bloquea ediciones que contengan posibles secretos hardcodeados.
# Exit 2 = bloquear la operación. Stdout se muestra como motivo.
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

# Ignorar archivos que no aplican
if [[ "$FILE_PATH" == *.env.example ]] || [[ "$FILE_PATH" == *.md ]] || \
   [[ "$FILE_PATH" == *.jpg ]] || [[ "$FILE_PATH" == *.png ]] || \
   [[ "$FILE_PATH" == *.pdf ]] || [[ "$FILE_PATH" == *.yaml ]] || \
   [[ "$FILE_PATH" == *.yml ]]; then
  exit 0
fi

CONTENT=$($PYTHON -c "
import sys, json
d = json.load(sys.stdin).get('tool_input', {})
parts = []
for key in ('new_string', 'content'):
    v = d.get(key, '')
    if v:
        parts.append(v)
print('\n'.join(parts))
" <<< "$INPUT" 2>/dev/null || echo "")

if [[ -z "$CONTENT" ]]; then
  exit 0
fi

PATTERNS=(
  'password\s*=\s*["'"'"'][^"'"'"']{8,}'
  'passwd\s*=\s*["'"'"'][^"'"'"']{8,}'
  'api[_-]?key\s*[:=]\s*["'"'"'][^"'"'"']{16,}'
  'secret\s*[:=]\s*["'"'"'][^"'"'"']{16,}'
  'token\s*[:=]\s*["'"'"'][^"'"'"']{20,}'
  'AKIA[0-9A-Z]{16}'
  'BEGIN (RSA|DSA|EC|OPENSSH) PRIVATE KEY'
  'xox[baprs]-[0-9a-zA-Z]{10,}'
)

for pat in "${PATTERNS[@]}"; do
  if echo "$CONTENT" | grep -iEq "$pat" 2>/dev/null; then
    echo "Posible secreto detectado en: $FILE_PATH"
    echo "Patrón: $pat"
    echo "Edición bloqueada. Revisá el contenido antes de escribirlo."
    exit 2
  fi
done

exit 0
