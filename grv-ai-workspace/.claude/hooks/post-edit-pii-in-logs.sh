#!/usr/bin/env bash
# Hook: post-edit-pii-in-logs
# Evento: PostToolUse (Edit, Write)
# Propósito: Detectar PII en llamadas a logger (log.info, log.error, etc.)
# Bloquea: NO (exit 0 siempre — warning de alta señal)

set -euo pipefail

TOOL_INPUT=$(cat)

FILE_PATH=$(echo "$TOOL_INPUT" | grep -o '"file_path":"[^"]*"' | head -1 | cut -d'"' -f4)

if [ -z "$FILE_PATH" ]; then
  exit 0
fi

# Solo analizar Java (logs estructurados) y TypeScript/JS
case "$FILE_PATH" in
  *.java|*.ts|*.tsx|*.js) ;;
  *) exit 0 ;;
esac

# Ignorar archivos de test
case "$FILE_PATH" in
  */src/test/*|*/__tests__/*|*.test.*|*.spec.*) exit 0 ;;
esac

# Ignorar si el archivo no existe (fue eliminado)
if [ ! -f "$FILE_PATH" ]; then
  exit 0
fi

# --- Patrones de PII a detectar en líneas de log ---
# Buscar líneas que tengan TANTO una llamada a log COMO un campo de PII

PII_PATTERNS=(
  # Campos con DNI
  'log\.\(info\|warn\|error\|debug\|trace\).*[Dd][Nn][Ii]'
  'log\.\(info\|warn\|error\|debug\|trace\).*[Cc][Uu][Ii][Ll]'
  'log\.\(info\|warn\|error\|debug\|trace\).*[Cc][Uu][Ii][Tt]'
  # Nombres de persona en logs
  'log\.\(info\|warn\|error\|debug\|trace\).*[Nn]ombre.*[A-Z][a-z]'
  'log\.\(info\|warn\|error\|debug\|trace\).*[Aa]pellido'
  # Historia clínica / diagnóstico
  'log\.\(info\|warn\|error\|debug\|trace\).*historia.*clinica\|historia.*cl\xednca'
  'log\.\(info\|warn\|error\|debug\|trace\).*diagnostico\|diagn\xf3stico'
  # Dirección / domicilio
  'log\.\(info\|warn\|error\|debug\|trace\).*domicilio\|[Dd]irecci\xf3n\|[Dd]ireccion'
  # JavaScript: console.log con PII
  'console\.\(log\|info\|warn\|error\).*[Dd][Nn][Ii]'
  'console\.\(log\|info\|warn\|error\).*[Cc][Uu][Ii][Ll]'
)

FOUND=false
FINDINGS=()

for PATTERN in "${PII_PATTERNS[@]}"; do
  MATCHES=$(grep -n "$PATTERN" "$FILE_PATH" 2>/dev/null || true)
  if [ -n "$MATCHES" ]; then
    FOUND=true
    while IFS= read -r line; do
      FINDINGS+=("  $line")
    done <<< "$MATCHES"
  fi
done

if [ "$FOUND" = true ]; then
  echo "" >&2
  echo "⚠️  [pii-in-logs] Posible PII detectada en llamadas a logger en $(basename "$FILE_PATH"):" >&2
  for finding in "${FINDINGS[@]}"; do
    echo "$finding" >&2
  done
  echo "" >&2
  echo "   Los logs NO deben contener: DNI, CUIL, CUIT, nombre, apellido, domicilio, historia clínica." >&2
  echo "   Usar IDs internos (siniestroId, afiliadoId) en lugar de datos personales." >&2
  echo "   Ver: context/sensitive-tables.yaml y skills/engineering/observability-blueprint" >&2
  echo "" >&2
fi

exit 0
