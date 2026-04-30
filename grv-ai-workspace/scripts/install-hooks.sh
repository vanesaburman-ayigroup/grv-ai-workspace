#!/usr/bin/env bash
# scripts/install-hooks.sh
# Instala los git hooks del workspace en .git/hooks/ del repositorio objetivo.
#
# Uso:
#   bash scripts/install-hooks.sh                    # instala en el repo actual
#   bash scripts/install-hooks.sh /path/to/repo      # instala en otro repo
#
# Este script crea dispatchers en .git/hooks/ que invocan los scripts en .claude/hooks/.
# Los hooks se ejecutan desde la raíz del repo, por lo que las rutas son relativas a esa raíz.

set -euo pipefail

WORKSPACE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET_REPO="${1:-$(git -C "$WORKSPACE_DIR" rev-parse --show-toplevel 2>/dev/null || echo "$WORKSPACE_DIR")}"

echo "📦 GRV AI Workspace — Instalador de git hooks"
echo "   Workspace:    $WORKSPACE_DIR"
echo "   Repo destino: $TARGET_REPO"
echo ""

# Verificar que el target es un repo git
if [ ! -d "$TARGET_REPO/.git" ]; then
  echo "❌ $TARGET_REPO no es un repositorio git."
  exit 1
fi

GIT_HOOKS_DIR="$TARGET_REPO/.git/hooks"
HOOKS_SRC="$WORKSPACE_DIR/.claude/hooks"

if [[ ! -d "$HOOKS_SRC" ]]; then
  echo "❌ No existe $HOOKS_SRC. Ejecutar desde la raíz del workspace."
  exit 1
fi

# Hacer ejecutables todos los hook scripts
chmod +x "$HOOKS_SRC"/*.sh 2>/dev/null || true

# --- Hooks pre-commit (git hook: pre-commit) ---
PRE_COMMIT_HOOKS=(
  "pre-commit-secrets.sh"
  "pre-commit-migration.sh"
  "pre-commit-api-sync.sh"
  "pre-commit-typescript-quality.sh"
  "pre-commit-todo-orphan.sh"
  "pre-commit-openapi-sync.sh"
)

# --- Hooks commit-msg (git hook: commit-msg) ---
COMMIT_MSG_HOOKS=(
  "pre-commit-conventional-commits.sh"
)

# Instala un dispatcher de git hook, preservando hooks existentes no gestionados
install_dispatcher() {
  local hook_name="$1"
  local target="$GIT_HOOKS_DIR/$hook_name"
  shift
  local hooks=("$@")

  if [[ -f "$target" ]]; then
    if grep -q "grv-ai-workspace managed hook" "$target" 2>/dev/null; then
      echo "ℹ️  Actualizando hook gestionado existente: .git/hooks/$hook_name"
    else
      local backup="$target.grv-backup.$(date +%Y%m%d%H%M%S)"
      cp "$target" "$backup"
      echo "ℹ️  Backup de hook existente guardado en: $backup"
    fi
  fi

  {
    echo "#!/usr/bin/env bash"
    echo "# grv-ai-workspace managed hook — no editar manualmente"
    echo "set -e"
    for hook in "${hooks[@]}"; do
      HOOK_PATH="$HOOKS_SRC/$hook"
      if [ -f "$HOOK_PATH" ]; then
        if [[ "$hook_name" == "commit-msg" ]]; then
          echo "bash \"$HOOK_PATH\" \"\$1\""
        else
          echo "bash \"$HOOK_PATH\""
        fi
      fi
    done
  } > "$target"
  chmod +x "$target"
}

install_dispatcher "pre-commit" "${PRE_COMMIT_HOOKS[@]}"
echo "✅ pre-commit hook instalado con ${#PRE_COMMIT_HOOKS[@]} scripts"

install_dispatcher "commit-msg" "${COMMIT_MSG_HOOKS[@]}"
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
echo ""
echo "Documentación: .claude/hooks/README.md"
echo "Sound alerts:"
echo "  Activar:    .claude/hooks/post-tool-sound-alert.sh on"
echo "  Desactivar: .claude/hooks/post-tool-sound-alert.sh off"
echo "  Estado:     .claude/hooks/post-tool-sound-alert.sh status"
