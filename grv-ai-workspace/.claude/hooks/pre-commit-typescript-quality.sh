#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# pre-commit-typescript-quality.sh
# -----------------------------------------------------------------------------
# Propósito: ejecutar los scripts existentes de lint y typecheck cuando hay
# cambios TypeScript staged.
# Dispara en: pre-commit.
# Modo: warn por default; blocking con GRV_TS_CHECK_MODE=block.
# -----------------------------------------------------------------------------

set -euo pipefail

MODE="${GRV_TS_CHECK_MODE:-warn}"
TS_PATTERN='\.(ts|tsx)$'
STAGED=$(git diff --cached --name-only --diff-filter=ACM | grep -E "$TS_PATTERN" || true)

if [[ -z "$STAGED" ]]; then
  exit 0
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "⚠️  grv-ai-workspace: no se pudo verificar scripts TypeScript porque falta python3."
  exit 0
fi

declare -A PACKAGE_ROOTS=()

find_package_root() {
  local file="$1"
  local dir
  dir="$(dirname "$file")"

  while [[ "$dir" != "." && "$dir" != "/" ]]; do
    if [[ -f "$dir/package.json" ]]; then
      echo "$dir"
      return 0
    fi
    dir="$(dirname "$dir")"
  done

  if [[ -f "package.json" ]]; then
    echo "."
  fi
}

while IFS= read -r file; do
  [[ -n "$file" ]] || continue
  root="$(find_package_root "$file" || true)"
  [[ -n "${root:-}" ]] && PACKAGE_ROOTS["$root"]=1
done <<< "$STAGED"

if [[ ${#PACKAGE_ROOTS[@]} -eq 0 ]]; then
  echo "⚠️  grv-ai-workspace: hay TypeScript staged, pero no se encontró package.json cercano."
  exit 0
fi

has_script() {
  local root="$1"
  local script="$2"
  local output
  local status

  set +e
  output="$(
    python3 - "$root/package.json" "$script" 2>&1 <<'PY'
import json
import sys

try:
    with open(sys.argv[1], encoding="utf-8") as fh:
        package = json.load(fh)
except Exception as exc:
    print(f"No se pudo leer {sys.argv[1]}: {exc}", file=sys.stderr)
    sys.exit(2)

scripts = package.get("scripts") or {}
sys.exit(0 if sys.argv[2] in scripts else 1)
PY
  )"
  status=$?
  set -e

  if [[ $status -eq 2 ]]; then
    echo "⚠️  grv-ai-workspace: $output"
  fi

  return "$status"
}

run_script() {
  local root="$1"
  local script="$2"

  if [[ -f "$root/pnpm-lock.yaml" ]] && command -v pnpm >/dev/null 2>&1; then
    (cd "$root" && pnpm run "$script")
  elif [[ -f "$root/yarn.lock" ]] && command -v yarn >/dev/null 2>&1; then
    (cd "$root" && yarn run "$script")
  elif [[ -f "$root/bun.lockb" ]] && command -v bun >/dev/null 2>&1; then
    (cd "$root" && bun run "$script")
  elif command -v npm >/dev/null 2>&1; then
    (cd "$root" && npm run "$script")
  else
    echo "⚠️  grv-ai-workspace: no hay package manager disponible para correr $script en $root."
    return 0
  fi
}

FAILED=0
for root in "${!PACKAGE_ROOTS[@]}"; do
  for script in lint typecheck; do
    if has_script "$root" "$script"; then
      echo "🔎 grv-ai-workspace: corriendo $script en $root por cambios TypeScript staged."
      if ! run_script "$root" "$script"; then
        FAILED=1
        echo "⚠️  grv-ai-workspace: $script falló en $root."
      fi
    else
      echo "ℹ️  grv-ai-workspace: $root no define npm script '$script'; se omite."
    fi
  done
done

if [[ $FAILED -eq 1 ]] && [[ "$MODE" == "block" || "$MODE" == "blocking" ]]; then
  echo "❌ Commit bloqueado por TypeScript quality checks. Usar GRV_TS_CHECK_MODE=warn para modo no bloqueante."
  exit 1
fi

exit 0
