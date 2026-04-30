#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# pre-commit-api-sync.sh
# -----------------------------------------------------------------------------
# Detecta cambios en controllers Spring Boot y recuerda sincronizar Swagger.
# Warn mode. Integración con api-doc-sync skill.
# -----------------------------------------------------------------------------

set -euo pipefail

CONTROLLER_PATTERN='src/main/java/.*Controller\.java$'
STAGED=$(git diff --cached --name-only --diff-filter=ACM | grep -E "$CONTROLLER_PATTERN" || true)

if [[ -z "$STAGED" ]]; then
  exit 0
fi

echo ""
echo "🔍 grv-ai-workspace: detectados cambios en controllers"
echo "   Archivos:"
for f in $STAGED; do
  echo "   - $f"
done
echo ""
echo "   Revisar si Swagger/OpenAPI necesita actualización."
echo "   Skill recomendado: api-doc-sync"
echo "     claude skill run api-doc-sync --files $STAGED"
echo ""

exit 0
