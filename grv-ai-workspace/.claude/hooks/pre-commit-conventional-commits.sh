#!/usr/bin/env bash
# Hook: pre-commit-conventional-commits (commit-msg)
# Evento: git commit-msg (NO pre-commit — ver nota abajo)
# Propósito: Validar que el mensaje de commit siga Conventional Commits.
# Bloquea: SÍ (exit 1 si el formato es incorrecto)
#
# INSTALACIÓN: Este script debe registrarse como hook commit-msg, NO como pre-commit.
# Ver scripts/install-hooks.sh para la instalación automática.
#
# Uso manual: cp .claude/hooks/pre-commit-conventional-commits.sh .git/hooks/commit-msg
#             chmod +x .git/hooks/commit-msg

# El hook commit-msg recibe el path al archivo con el mensaje como $1
COMMIT_MSG_FILE="${1:-.git/COMMIT_EDITMSG}"

if [ ! -f "$COMMIT_MSG_FILE" ]; then
  exit 0
fi

COMMIT_MSG=$(cat "$COMMIT_MSG_FILE")
FIRST_LINE=$(echo "$COMMIT_MSG" | head -1)

# Patrón de Conventional Commits:
# type(scope)!: description
# type!: description
# type: description
#
# Tipos aceptados en GRV:
VALID_TYPES="feat|fix|chore|docs|test|refactor|style|perf|ci|build|revert|wip"

# Regex para validar la primera línea
CONVENTIONAL_PATTERN="^(${VALID_TYPES})(\([a-zA-Z0-9_-]+\))?(!)?: .+"

# Casos especiales permitidos:
# - Merge commits
# - Revert commits generados por git
# - Commits de merge de rama automáticos
if echo "$FIRST_LINE" | grep -qE "^Merge (branch|pull request|remote-tracking)" ; then
  exit 0
fi

if echo "$FIRST_LINE" | grep -qE "^Revert \"" ; then
  exit 0
fi

# Validar formato
if ! echo "$FIRST_LINE" | grep -qE "$CONVENTIONAL_PATTERN"; then
  echo "" >&2
  echo "❌ [conventional-commits] El mensaje de commit no sigue el formato requerido." >&2
  echo "" >&2
  echo "   Mensaje actual: $FIRST_LINE" >&2
  echo "" >&2
  echo "   Formato requerido: <tipo>(<scope opcional>): <descripción>" >&2
  echo "" >&2
  echo "   Tipos válidos: feat, fix, chore, docs, test, refactor, style, perf, ci, build, revert" >&2
  echo "" >&2
  echo "   Ejemplos:" >&2
  echo "     feat: agregar endpoint de prestaciones por siniestro" >&2
  echo "     fix(wssiniestralidad): corregir cálculo de días ILT para accidente in-itinere" >&2
  echo "     chore!: actualizar versión de Spring Boot (breaking: requiere JDK 17)" >&2
  echo "     docs: agregar openapi.yaml al servicio de facturación" >&2
  echo "" >&2
  echo "   Para breaking changes: agregar '!' antes de ':' o incluir 'BREAKING CHANGE:' en el cuerpo." >&2
  echo "" >&2
  exit 1
fi

# Advertir si el subject es muy largo (max 72 caracteres recomendado)
SUBJECT_LEN=${#FIRST_LINE}
if [ "$SUBJECT_LEN" -gt 72 ]; then
  echo "⚠️  [conventional-commits] La primera línea tiene $SUBJECT_LEN caracteres. Se recomienda máximo 72." >&2
fi

exit 0
