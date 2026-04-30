#!/usr/bin/env bash
# Hook: post-edit-changelog-suggest
# Evento: PostToolUse (Edit, Write)
# Propósito: Si se edita código fuente sin que CHANGELOG.md esté en staging, sugerir actualizarlo.
# Bloquea: NO (exit 0 siempre — solo warning)

set -euo pipefail

TOOL_INPUT=$(cat)

FILE_PATH=$(echo "$TOOL_INPUT" | grep -o '"file_path":"[^"]*"' | head -1 | cut -d'"' -f4)

if [ -z "$FILE_PATH" ]; then
  exit 0
fi

# Solo analizar código fuente Java/TypeScript (no tests, no docs)
case "$FILE_PATH" in
  *.java|*.ts|*.tsx|*.js) ;;
  *) exit 0 ;;
esac

# Ignorar tests
case "$FILE_PATH" in
  */src/test/*|*/__tests__/*|*.test.*|*.spec.*) exit 0 ;;
esac

# Ignorar config, resources
case "$FILE_PATH" in
  */resources/*|*/config/*|*Application.java|*Config.java|*Configuration.java) exit 0 ;;
esac

# Ignorar archivos de workspace (no código de producto)
case "$FILE_PATH" in
  */skills/*|*/agents/*|*/templates/*|*/prompts/*|*/.claude/*) exit 0 ;;
esac

# --- Verificar si CHANGELOG.md fue modificado recientemente ---
# Buscar CHANGELOG.md en el directorio del módulo o en el raíz del proyecto
DIRNAME=$(dirname "$FILE_PATH")

# Buscar subiendo hasta 4 niveles desde el archivo editado
CHANGELOG_PATH=""
SEARCH_DIR="$DIRNAME"
for i in 1 2 3 4; do
  if [ -f "$SEARCH_DIR/CHANGELOG.md" ]; then
    CHANGELOG_PATH="$SEARCH_DIR/CHANGELOG.md"
    break
  fi
  PARENT=$(dirname "$SEARCH_DIR")
  if [ "$PARENT" = "$SEARCH_DIR" ]; then
    break
  fi
  SEARCH_DIR="$PARENT"
done

if [ -z "$CHANGELOG_PATH" ]; then
  # No hay CHANGELOG.md — no hacer nada
  exit 0
fi

# Verificar si CHANGELOG.md está en el staging área de git
CHANGELOG_STAGED=$(git diff --cached --name-only 2>/dev/null | grep -F "CHANGELOG.md" || true)

# Solo sugerir si:
# 1. Existe CHANGELOG.md
# 2. NO está en staging (es decir, no fue modificado en este ciclo)
# 3. El archivo editado es código de producción (no test, no config)
if [ -z "$CHANGELOG_STAGED" ]; then
  echo "" >&2
  echo "ℹ️  [changelog-suggest] Editaste $(basename "$FILE_PATH") pero CHANGELOG.md no fue actualizado." >&2
  echo "   Si este cambio es visible para el equipo, considerar agregar un entry." >&2
  echo "   Podés usar: /changelog-keeper para generar el entry desde los commits." >&2
  echo "" >&2
fi

exit 0
