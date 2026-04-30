#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# post-tool-auto-format.sh
# -----------------------------------------------------------------------------
# Propósito: ejecutar formateadores disponibles después de ediciones de Claude.
# Dispara en: PostTool / después de Edit, MultiEdit o Write.
# Modo: warn; nunca bloquea si no hay formateador instalado.
# -----------------------------------------------------------------------------

set -euo pipefail

PAYLOAD="$(cat || true)"
TOOL_NAME="${1:-}"
LOG_DIR=".claude/logs"
LOG_FILE="$LOG_DIR/post-tool-auto-format.log"

mkdir -p "$LOG_DIR"

if [[ "${GRV_AUTO_FORMAT_DISABLED:-false}" == "true" ]] || [[ "${GRV_AUTO_FORMAT_DISABLED:-false}" == "1" ]]; then
  exit 0
fi

if [[ -z "$TOOL_NAME" ]] && [[ -n "$PAYLOAD" ]] && command -v python3 >/dev/null 2>&1; then
  TOOL_NAME="$(PAYLOAD="$PAYLOAD" python3 - <<'PY' 2>/dev/null || true
import json
import os

try:
    payload = json.loads(os.environ.get("PAYLOAD", ""))
except (json.JSONDecodeError, TypeError, ValueError):
    payload = {}

print(payload.get("tool_name") or payload.get("tool") or "")
PY
)"
fi

if [[ -n "$TOOL_NAME" ]] && [[ ! "$TOOL_NAME" =~ ^(Edit|MultiEdit|Write|NotebookEdit)$ ]]; then
  exit 0
fi

collect_files_from_payload() {
  if [[ -z "$PAYLOAD" ]] || ! command -v python3 >/dev/null 2>&1; then
    return 0
  fi

  PAYLOAD="$PAYLOAD" python3 - <<'PY' 2>/dev/null || true
import json
import os

try:
    payload = json.loads(os.environ.get("PAYLOAD", ""))
except (json.JSONDecodeError, TypeError, ValueError):
    payload = {}

paths = []
try:
    MAX_DEPTH = int(os.environ.get("GRV_HOOK_MAX_DEPTH", "12"))
except ValueError:
    MAX_DEPTH = 12

def walk(value, depth=0):
    if depth > MAX_DEPTH:
        return
    if isinstance(value, dict):
        for key, item in value.items():
            if key in {"file_path", "path"} and isinstance(item, str):
                paths.append(item)
            else:
                walk(item, depth + 1)
    elif isinstance(value, list):
        for item in value:
            walk(item, depth + 1)

walk(payload)
for path in dict.fromkeys(paths):
    print(path)
PY
}

FILES=()
while IFS= read -r file; do
  [[ -n "$file" ]] && FILES+=("$file")
done < <(collect_files_from_payload)

if [[ ${#FILES[@]} -eq 0 ]] && git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  while IFS= read -r file; do
    [[ -n "$file" ]] && FILES+=("$file")
  done < <(git diff --name-only --diff-filter=ACM)
fi

if [[ ${#FILES[@]} -eq 0 ]]; then
  exit 0
fi

PRETTIER=()
if command -v prettier >/dev/null 2>&1; then
  PRETTIER=(prettier --write)
elif command -v npx >/dev/null 2>&1 && npx --no-install prettier --version >/dev/null 2>&1; then
  PRETTIER=(npx --no-install prettier --write)
fi

format_file() {
  local file="$1"

  [[ -f "$file" ]] || return 0

  case "$file" in
    *.js|*.jsx|*.ts|*.tsx|*.json|*.css|*.scss|*.md|*.yaml|*.yml)
      if [[ ${#PRETTIER[@]} -gt 0 ]]; then
        "${PRETTIER[@]}" "$file" >>"$LOG_FILE" 2>&1 || true
        echo "🎨 grv-ai-workspace: formateado $file"
      fi
      ;;
    *.py)
      if command -v ruff >/dev/null 2>&1; then
        ruff format "$file" >>"$LOG_FILE" 2>&1 || true
        echo "🎨 grv-ai-workspace: formateado $file"
      elif command -v black >/dev/null 2>&1; then
        black "$file" >>"$LOG_FILE" 2>&1 || true
        echo "🎨 grv-ai-workspace: formateado $file"
      fi
      ;;
    *.sh|*.bash)
      if command -v shfmt >/dev/null 2>&1; then
        shfmt -w "$file" >>"$LOG_FILE" 2>&1 || true
        echo "🎨 grv-ai-workspace: formateado $file"
      else
        bash -n "$file" >>"$LOG_FILE" 2>&1 || true
      fi
      ;;
  esac
}

for file in "${FILES[@]}"; do
  format_file "$file"
done

exit 0
