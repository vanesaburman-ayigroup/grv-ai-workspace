#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# pre-commit-migration.sh
# -----------------------------------------------------------------------------
# Dispara el skill `mariadb-migration-review` cuando hay cambios en archivos
# de migración. No bloquea el commit por default — warn mode. Subir a blocking
# cuando el skill esté en production.
#
# Instalación: linkear a .git/hooks/pre-commit o combinarlo con otros via
# pre-commit framework (recomendado).
# -----------------------------------------------------------------------------

set -euo pipefail

MIGRATION_PATTERN='(^|/)db/migration/V[0-9]+__.*\.sql$'
STAGED=$(git diff --cached --name-only --diff-filter=ACM | grep -E "$MIGRATION_PATTERN" || true)

if [[ -z "$STAGED" ]]; then
  exit 0
fi

echo ""
echo "🔍 grv-ai-workspace: detectados cambios en migraciones"
echo "   Archivos:"
for f in $STAGED; do
  echo "   - $f"
done
echo ""
echo "   Se recomienda correr el skill mariadb-migration-review antes de commitear."
echo "   Ejemplo:"
echo "     claude skill run mariadb-migration-review --files $STAGED"
echo ""
echo "   (warn mode — el commit NO se bloquea. Subir a blocking cuando el skill"
echo "    esté en nivel production.)"
echo ""

exit 0
