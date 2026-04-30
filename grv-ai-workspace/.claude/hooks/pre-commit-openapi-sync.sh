#!/usr/bin/env bash
# Hook: pre-commit-openapi-sync
# Evento: git pre-commit
# Propósito: Si hay cambios en controllers Java y existe openapi.yaml, recordar actualizarlo.
# Bloquea: NO (exit 0 siempre — solo warning)

# Obtener archivos en staging
STAGED_FILES=$(git diff --cached --name-only 2>/dev/null || true)

if [ -z "$STAGED_FILES" ]; then
  exit 0
fi

# --- Detectar controllers Java modificados ---
CONTROLLERS_MODIFIED=$(echo "$STAGED_FILES" | grep -E '.*Controller\.java$' || true)

if [ -z "$CONTROLLERS_MODIFIED" ]; then
  exit 0
fi

# --- Buscar openapi.yaml en paths comunes del proyecto ---
OPENAPI_PATHS=(
  "openapi.yaml"
  "openapi.yml"
  "src/main/resources/openapi.yaml"
  "src/main/resources/openapi.yml"
  "docs/openapi.yaml"
  "docs/openapi.yml"
  "api/openapi.yaml"
)

OPENAPI_EXISTS=false
OPENAPI_FILE=""
for PATH_CANDIDATE in "${OPENAPI_PATHS[@]}"; do
  if [ -f "$PATH_CANDIDATE" ]; then
    OPENAPI_EXISTS=true
    OPENAPI_FILE="$PATH_CANDIDATE"
    break
  fi
done

# --- Verificar si openapi.yaml también fue modificado ---
OPENAPI_MODIFIED=false
if echo "$STAGED_FILES" | grep -qE '(openapi\.yaml|openapi\.yml)'; then
  OPENAPI_MODIFIED=true
fi

# --- Emitir warning según el caso ---
echo "" >&2
echo "🔍 [openapi-sync] Controllers modificados detectados:" >&2
echo "$CONTROLLERS_MODIFIED" | sed 's/^/   /' >&2
echo "" >&2

if [ "$OPENAPI_EXISTS" = true ]; then
  if [ "$OPENAPI_MODIFIED" = false ]; then
    echo "⚠️  [openapi-sync] Existe '$OPENAPI_FILE' pero no fue actualizado en este commit." >&2
    echo "   Si los cambios en los controllers afectan el contrato de la API:" >&2
    echo "   → Actualizá el openapi.yaml con: /api-doc-sync" >&2
    echo "   → O generá uno nuevo desde el código con: /openapi-from-scratch" >&2
    echo "   → Luego validá con: /openapi-validator" >&2
    echo "   Si el cambio no afecta el contrato, podés ignorar este warning." >&2
  else
    echo "✅ [openapi-sync] openapi.yaml también fue actualizado en este commit." >&2
  fi
else
  echo "ℹ️  [openapi-sync] No se encontró openapi.yaml en este servicio." >&2
  echo "   Si querés documentar la API, generá el contrato con: /openapi-from-scratch" >&2
fi

echo "" >&2

# Siempre exit 0: este hook solo advierte, no bloquea
exit 0
