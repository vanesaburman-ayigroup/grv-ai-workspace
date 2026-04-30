#!/usr/bin/env bash
# scripts/install-hooks.sh
# Instala los git hooks del workspace en .git/hooks/ del repositorio objetivo.
#
# Uso:
#   bash scripts/install-hooks.sh                    # instala en el repo actual
#   bash scripts/install-hooks.sh /path/to/repo      # instala en otro repo
#
# Este script crea symlinks en .git/hooks/ apuntando a los scripts en .claude/hooks/.
# Los hooks se ejecutan desde la raíz del repo, por lo que las rutas son relativas a esa raíz.

set -euo pipefail

WORKSPACE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET_REPO="${1:-$(pwd)}"

echo "📦 GRV AI Workspace — Instalador de git hooks"
echo "   Workspace:  $WORKSPACE_DIR"
echo "   Repo destino: $TARGET_REPO"
echo ""

# Verificar que el target es un repo git
if [ ! -d "$TARGET_REPO/.git" ]; then
  echo "❌ $TARGET_REPO no es un repositorio git."
  exit 1
fi

GIT_HOOKS_DIR="$TARGET_REPO/.git/hooks"
HOOKS_SRC="$WORKSPACE_DIR/.claude/hooks"

# --- Hooks pre-commit (git hook: pre-commit) ---
PRE_COMMIT_HOOKS=(
  "pre-commit-secrets.sh"
  "pre-commit-migration.sh"
  "pre-commit-api-sync.sh"
  "pre-commit-todo-orphan.sh"
  "pre-commit-openapi-sync.sh"
)

# --- Hooks commit-msg (git hook: commit-msg) ---
COMMIT_MSG_HOOKS=(
  "pre-commit-conventional-commits.sh"
)

# Crear el pre-commit hook como dispatcher
PRE_COMMIT_FILE="$GIT_HOOKS_DIR/pre-commit"
{
  echo "#!/usr/bin/env bash"
  echo "# Generado por scripts/install-hooks.sh — no editar manualmente"
  echo "set -e"
  for hook in "${PRE_COMMIT_HOOKS[@]}"; do
    HOOK_PATH="$HOOKS_SRC/$hook"
    if [ -f "$HOOK_PATH" ]; then
      echo "bash \"$HOOK_PATH\""
    fi
  done
} > "$PRE_COMMIT_FILE"
chmod +x "$PRE_COMMIT_FILE"
echo "✅ pre-commit hook instalado con ${#PRE_COMMIT_HOOKS[@]} scripts"

# Crear el commit-msg hook como dispatcher
COMMIT_MSG_FILE="$GIT_HOOKS_DIR/commit-msg"
{
  echo "#!/usr/bin/env bash"
  echo "# Generado por scripts/install-hooks.sh — no editar manualmente"
  echo "set -e"
  for hook in "${COMMIT_MSG_HOOKS[@]}"; do
    HOOK_PATH="$HOOKS_SRC/$hook"
    if [ -f "$HOOK_PATH" ]; then
      echo "bash \"$HOOK_PATH\" \"\$1\""
    fi
  done
} > "$COMMIT_MSG_FILE"
chmod +x "$COMMIT_MSG_FILE"
echo "✅ commit-msg hook instalado con ${#COMMIT_MSG_HOOKS[@]} scripts"

echo ""
echo "✅ Instalación completa."
echo ""
echo "Hooks git activos:"
echo "  pre-commit: ${PRE_COMMIT_HOOKS[*]}"
echo "  commit-msg: ${COMMIT_MSG_HOOKS[*]}"
echo ""
echo "Nota: Los hooks PostToolUse de Claude Code (.claude/hooks/post-edit-*.sh)"
echo "se configuran en .claude/settings.json y no requieren instalación manual."
