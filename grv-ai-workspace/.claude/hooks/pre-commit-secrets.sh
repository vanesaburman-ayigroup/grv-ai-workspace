#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# pre-commit-secrets.sh
# -----------------------------------------------------------------------------
# Detector básico de secretos antes del commit. Bloquea si encuentra algo
# obvio (API keys, tokens, passwords hardcoded).
#
# Para paranoia real, complementar con `gitleaks` o `trufflehog` en CI.
# -----------------------------------------------------------------------------

set -euo pipefail

STAGED=$(git diff --cached --name-only --diff-filter=ACM)

if [[ -z "$STAGED" ]]; then
  exit 0
fi

PATTERNS=(
  'password\s*=\s*["\x27][^"\x27]{8,}'
  'passwd\s*=\s*["\x27][^"\x27]{8,}'
  'api[_-]?key\s*[:=]\s*["\x27][^"\x27]{16,}'
  'secret\s*[:=]\s*["\x27][^"\x27]{16,}'
  'token\s*[:=]\s*["\x27][^"\x27]{20,}'
  'AKIA[0-9A-Z]{16}'
  'BEGIN (RSA|DSA|EC|OPENSSH) PRIVATE KEY'
  'xox[baprs]-[0-9a-zA-Z]{10,}'
)

FOUND=0
for file in $STAGED; do
  # Ignorar archivos binarios, docs, ejemplos
  if [[ "$file" == *.env.example ]] || [[ "$file" == *.md ]] || [[ "$file" == *.jpg ]] || [[ "$file" == *.png ]] || [[ "$file" == *.pdf ]]; then
    continue
  fi
  for pat in "${PATTERNS[@]}"; do
    if git diff --cached "$file" | grep -E "^\+" | grep -iE "$pat" > /dev/null 2>&1; then
      echo ""
      echo "🚨 Posible secreto detectado en: $file"
      echo "   Patrón: $pat"
      FOUND=1
    fi
  done
done

if [[ $FOUND -eq 1 ]]; then
  echo ""
  echo "❌ Commit bloqueado. Revisar los archivos señalados."
  echo "   Si es un falso positivo, usar --no-verify (con cuidado)."
  echo ""
  exit 1
fi

exit 0
