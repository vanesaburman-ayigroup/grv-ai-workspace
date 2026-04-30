#!/usr/bin/env bash
# Hook: post-edit-test-suggestion
# Evento: PostToolUse (Edit, Write)
# Propósito: Si se edita código fuente sin test asociado, sugerir crear test.
# Bloquea: NO (exit 0 siempre — solo warning)

set -euo pipefail

# Leer el path del archivo editado desde el input JSON de Claude Code
# El hook recibe JSON por stdin con la estructura del tool use
TOOL_INPUT=$(cat)

# Extraer el path del archivo del JSON de input
FILE_PATH=$(echo "$TOOL_INPUT" | grep -o '"file_path":"[^"]*"' | head -1 | cut -d'"' -f4)

if [ -z "$FILE_PATH" ]; then
  exit 0
fi

# --- Filtros: ignorar archivos que no son código fuente ---

# Ignorar si no es Java ni TypeScript/JavaScript
case "$FILE_PATH" in
  *.java|*.ts|*.tsx|*.js|*.jsx) ;;  # continuar
  *) exit 0 ;;
esac

# Ignorar archivos en directorios de test
case "$FILE_PATH" in
  */src/test/*|*/__tests__/*|*.test.ts|*.test.tsx|*.test.js|*.spec.ts|*.spec.tsx|*.spec.js)
    exit 0 ;;
esac

# Ignorar archivos de configuración, no-código
case "$FILE_PATH" in
  */config/*|*/resources/*|*Application.java|*Config.java|*Configuration.java)
    exit 0 ;;
esac

# Ignorar si está en node_modules, target, build
case "$FILE_PATH" in
  */node_modules/*|*/target/*|*/build/*|*/dist/*)
    exit 0 ;;
esac

# --- Buscar archivo de test correspondiente ---

BASENAME=$(basename "$FILE_PATH")
DIRNAME=$(dirname "$FILE_PATH")
EXTENSION="${BASENAME##*.}"
CLASSNAME="${BASENAME%.*}"

TEST_EXISTS=false

if [[ "$EXTENSION" == "java" ]]; then
  # Java: buscar ClaseTest.java en src/test/
  # Convertir src/main/java a src/test/java en el path
  TEST_DIR="${DIRNAME/src\/main\/java/src\/test\/java}"
  TEST_FILE="$TEST_DIR/${CLASSNAME}Test.java"

  if [ -f "$TEST_FILE" ]; then
    TEST_EXISTS=true
  fi

  # También buscar en la misma ruta (a veces los tests están en el mismo módulo)
  if [ -f "${DIRNAME}/${CLASSNAME}Test.java" ]; then
    TEST_EXISTS=true
  fi
fi

if [[ "$EXTENSION" == "ts" || "$EXTENSION" == "tsx" || "$EXTENSION" == "js" || "$EXTENSION" == "jsx" ]]; then
  # TypeScript/JS: buscar *.test.ts, *.test.tsx, *.spec.ts, *.test.js
  for EXT in test.ts test.tsx spec.ts spec.tsx test.js spec.js; do
    if [ -f "${DIRNAME}/${CLASSNAME}.${EXT}" ] || \
       [ -f "${DIRNAME}/__tests__/${CLASSNAME}.${EXT}" ]; then
      TEST_EXISTS=true
      break
    fi
  done
fi

# --- Emitir warning si no hay test ---

if [ "$TEST_EXISTS" = false ]; then
  echo "⚠️  [test-suggestion] $(basename "$FILE_PATH") no tiene test asociado." >&2
  echo "   Considerá crear un test unitario con: /unit-test-author" >&2
  echo "   O un test funcional (contra spec) con: /functional-test-author" >&2
  echo "   Dudas sobre qué tipo de test usar: /test-coverage-strategy" >&2
fi

exit 0
