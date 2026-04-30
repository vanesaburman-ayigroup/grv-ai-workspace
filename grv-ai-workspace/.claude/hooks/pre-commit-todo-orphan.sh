#!/usr/bin/env bash
# Hook: pre-commit-todo-orphan
# Evento: git pre-commit
# Propósito: Detectar TODO/FIXME/XXX sin ticket o fecha de vencimiento en archivos staged.
# Bloquea: NO (exit 0 — warn, no bloquea para no frenar trabajo urgente)
#
# Formato aceptado de TODO:
#   TODO [GRV-1234]: descripción
#   TODO by 2026-06-30: descripción
#   FIXME [GRV-1234]: descripción
#
# Formato NO aceptado (huérfano):
#   TODO: descripción
#   FIXME: algo

STAGED_FILES=$(git diff --cached --name-only 2>/dev/null || true)

if [ -z "$STAGED_FILES" ]; then
  exit 0
fi

# Filtrar a solo archivos de código (no yamls de contexto, no templates de docs)
CODE_FILES=$(echo "$STAGED_FILES" | grep -E '\.(java|ts|tsx|js|jsx|py|sh)$' || true)

if [ -z "$CODE_FILES" ]; then
  exit 0
fi

FOUND=false
declare -a FINDINGS

while IFS= read -r file; do
  # Saltar si el archivo no existe (eliminado)
  [ -f "$file" ] || continue

  # Buscar TODOs/FIXMEs/XXXs
  # Aceptados: [TICKET-123] o by YYYY-MM-DD
  # Rechazados: TODO: sin ticket ni fecha
  ORPHAN_TODOS=$(grep -n 'TODO\|FIXME\|XXX' "$file" 2>/dev/null | \
    grep -v '\[.*\]' | \
    grep -v 'by [0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}' | \
    grep -v 'TODO for promover\|TODO para promover' | \
    grep -v '^\s*#\s*TODO para promover' \
    || true)

  if [ -n "$ORPHAN_TODOS" ]; then
    FOUND=true
    while IFS= read -r line; do
      FINDINGS+=("  $file: $line")
    done <<< "$ORPHAN_TODOS"
  fi
done <<< "$CODE_FILES"

if [ "$FOUND" = true ]; then
  echo "" >&2
  echo "⚠️  [todo-orphan] TODOs/FIXMEs sin ticket ni fecha detectados en archivos staged:" >&2
  for finding in "${FINDINGS[@]}"; do
    echo "$finding" >&2
  done
  echo "" >&2
  echo "   Formato aceptado:" >&2
  echo "     // TODO [GRV-1234]: descripción del pendiente" >&2
  echo "     // FIXME [GRV-1234]: descripción" >&2
  echo "     // TODO by 2026-06-30: revisar cuando se resuelva X" >&2
  echo "" >&2
  echo "   Los TODOs sin ticket se pierden. Crearles un ticket o eliminarlos." >&2
  echo "" >&2
fi

# Exit 0: solo advertencia, no bloquea el commit
exit 0
