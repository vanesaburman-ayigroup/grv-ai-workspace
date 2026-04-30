#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# post-edit-test-check.sh — Claude Code PostToolUse hook (Edit|Write)
# -----------------------------------------------------------------------------
# Advierte sobre señales de tests acoplados a implementación después de
# editar un archivo de test. No bloquea.
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

# Solo archivos de test
if ! echo "$FILE_PATH" | grep -qE '(Test|Spec|\.test\.|\.spec\.)' 2>/dev/null; then
  exit 0
fi

if [[ ! -f "$FILE_PATH" ]]; then
  exit 0
fi

WARNINGS=()

# Contar mocks (Java/Mockito)
MOCK_COUNT=$(grep -cE '@Mock|mock\(|Mockito\.when|Mockito\.verify' "$FILE_PATH" 2>/dev/null || echo 0)
if [[ $MOCK_COUNT -gt 8 ]]; then
  WARNINGS+=("Alto número de mocks ($MOCK_COUNT). Posible test de implementación.")
fi

# Falta de estructura given/when/then o arrange/act/assert
if ! grep -qiE '// ?given|// ?when|// ?then|// ?arrange|// ?act|// ?assert' "$FILE_PATH" 2>/dev/null; then
  WARNINGS+=("No se detectó estructura given/when/then o arrange/act/assert.")
fi

# Assertions sobre internals
if grep -qE 'verify\(.*\)\.(get|set|is|has)[A-Z]' "$FILE_PATH" 2>/dev/null; then
  WARNINGS+=("Verificaciones sobre getters/setters. Posible test acoplado a implementación.")
fi

if [[ ${#WARNINGS[@]} -gt 0 ]]; then
  echo "Señales de test acoplado a implementación en $(basename "$FILE_PATH"):"
  for w in "${WARNINGS[@]}"; do
    echo "  - $w"
  done
fi

exit 0
