#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# post-edit-test-check.sh
# -----------------------------------------------------------------------------
# Se dispara después de que Claude edita un archivo de test. Verifica
# señales de anti-patrones: tests que testean implementación en lugar
# de comportamiento.
#
# Señales de alerta:
# - Mocks excesivos (> 5 en un solo test)
# - Asserts sobre métodos privados (verify en mocks internos)
# - Tests que matchean la implementación literal (nombres tipo "verify X calls Y")
# - Ausencia de given/when/then o equivalente
#
# Warn mode. No bloquea.
# -----------------------------------------------------------------------------

set -euo pipefail

FILE="${1:-}"

if [[ -z "$FILE" ]]; then
  exit 0
fi

# Solo archivos de test
if [[ ! "$FILE" =~ (Test|Spec|\.test\.|\.spec\.) ]]; then
  exit 0
fi

WARNINGS=()

# Contar mocks (Java/Mockito)
MOCK_COUNT=$(grep -cE '@Mock|mock\(|Mockito\.when|Mockito\.verify' "$FILE" 2>/dev/null || echo 0)
if [[ $MOCK_COUNT -gt 8 ]]; then
  WARNINGS+=("Alto número de mocks ($MOCK_COUNT). Posible test de implementación.")
fi

# Falta de estructura given/when/then o arrange/act/assert
if ! grep -qiE '// ?given|// ?when|// ?then|// ?arrange|// ?act|// ?assert' "$FILE"; then
  WARNINGS+=("No se detectó estructura given/when/then o arrange/act/assert.")
fi

# Assertions sobre internals
if grep -qE 'verify\(.*\)\.(get|set|is|has)[A-Z]' "$FILE"; then
  WARNINGS+=("Verificaciones sobre getters/setters. Posible test acoplado a implementación.")
fi

if [[ ${#WARNINGS[@]} -gt 0 ]]; then
  echo ""
  echo "⚠️  grv-ai-workspace: señales de test acoplado a implementación en $FILE"
  for w in "${WARNINGS[@]}"; do
    echo "   - $w"
  done
  echo ""
  echo "   Ver: skills/engineering/functional-test-author"
  echo ""
fi

exit 0
