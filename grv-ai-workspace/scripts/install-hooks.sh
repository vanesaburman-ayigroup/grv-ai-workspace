#!/usr/bin/env bash
# scripts/install-hooks.sh
# Instala los git hooks Y los hooks de Claude Code en el repositorio objetivo.
#
# Uso:
#   bash scripts/install-hooks.sh                    # instala en el repo actual
#   bash scripts/install-hooks.sh /path/to/repo      # instala en otro repo
#
# Qué instala:
#   1. .git/hooks/pre-commit y .git/hooks/commit-msg  — hooks de git
#   2. .claude/settings.json en el repo destino       — hooks de Claude Code (PostToolUse/PreToolUse)
#
# Los hooks de Claude Code usan rutas absolutas al workspace para funcionar
# independientemente de desde dónde se abra Claude Code.

set -euo pipefail

WORKSPACE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET_REPO="${1:-$(git -C "$WORKSPACE_DIR" rev-parse --show-toplevel 2>/dev/null || echo "$WORKSPACE_DIR")}"

echo "📦 GRV AI Workspace — Instalador de hooks"
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

# ─────────────────────────────────────────────────────────────
# PARTE 1 — Git hooks
# ─────────────────────────────────────────────────────────────

PRE_COMMIT_HOOKS=(
  "pre-commit-secrets.sh"
  "pre-commit-migration.sh"
  "pre-commit-api-sync.sh"
  "pre-commit-typescript-quality.sh"
  "pre-commit-todo-orphan.sh"
  "pre-commit-openapi-sync.sh"
)

COMMIT_MSG_HOOKS=(
  "pre-commit-conventional-commits.sh"
)

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
      local hook_path="$HOOKS_SRC/$hook"
      if [ -f "$hook_path" ]; then
        if [[ "$hook_name" == "commit-msg" ]]; then
          echo "bash \"$hook_path\" \"\$1\""
        else
          echo "bash \"$hook_path\""
        fi
      fi
    done
  } > "$target"
  chmod +x "$target"
}

install_dispatcher "pre-commit" "${PRE_COMMIT_HOOKS[@]}"
echo "✅ Git hook pre-commit instalado (${#PRE_COMMIT_HOOKS[@]} scripts)"

install_dispatcher "commit-msg" "${COMMIT_MSG_HOOKS[@]}"
echo "✅ Git hook commit-msg instalado (${#COMMIT_MSG_HOOKS[@]} scripts)"

# ─────────────────────────────────────────────────────────────
# PARTE 2 — Claude Code hooks (.claude/settings.json)
# ─────────────────────────────────────────────────────────────

CLAUDE_DIR="$TARGET_REPO/.claude"
SETTINGS_FILE="$CLAUDE_DIR/settings.json"

mkdir -p "$CLAUDE_DIR"

# Si ya existe un settings.json gestionado por el workspace, lo actualiza.
# Si existe uno custom (no gestionado), hace backup.
if [[ -f "$SETTINGS_FILE" ]]; then
  if grep -q "grv-ai-workspace" "$SETTINGS_FILE" 2>/dev/null; then
    echo "ℹ️  Actualizando .claude/settings.json gestionado existente"
  else
    local_backup="$SETTINGS_FILE.grv-backup.$(date +%Y%m%d%H%M%S)"
    cp "$SETTINGS_FILE" "$local_backup"
    echo "ℹ️  Backup de settings.json existente guardado en: $local_backup"
  fi
fi

# Genera settings.json con rutas absolutas al workspace
cat > "$SETTINGS_FILE" << SETTINGS_EOF
{
  "\$schema": "https://json.schemastore.org/claude-code-settings.json",
  "_managed_by": "grv-ai-workspace — no editar manualmente. Re-ejecutar install-hooks.sh para actualizar.",
  "_workspace": "$WORKSPACE_DIR",
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Edit|Write",
        "command": "bash \"$HOOKS_SRC/pre-edit-secrets.sh\""
      },
      {
        "matcher": "Edit|Write",
        "command": "bash \"$HOOKS_SRC/pre-tool-branch-guard.sh\""
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Edit|Write",
        "command": "bash \"$HOOKS_SRC/post-edit-migration-check.sh\""
      },
      {
        "matcher": "Edit|Write",
        "command": "bash \"$HOOKS_SRC/post-edit-api-sync.sh\""
      },
      {
        "matcher": "Edit|Write",
        "command": "bash \"$HOOKS_SRC/post-edit-test-check.sh\""
      },
      {
        "matcher": "Edit|Write",
        "command": "bash \"$HOOKS_SRC/post-edit-test-suggestion.sh\""
      },
      {
        "matcher": "Edit|Write",
        "command": "bash \"$HOOKS_SRC/post-edit-pii-in-logs.sh\""
      },
      {
        "matcher": "Edit|Write",
        "command": "bash \"$HOOKS_SRC/post-edit-changelog-suggest.sh\""
      },
      {
        "matcher": "Edit|Write",
        "command": "bash \"$HOOKS_SRC/post-tool-auto-format.sh\""
      },
      {
        "matcher": "Edit|Write",
        "command": "bash \"$HOOKS_SRC/post-tool-cost-tracker.sh\""
      },
      {
        "matcher": "Edit|Write",
        "command": "bash \"$HOOKS_SRC/post-tool-feature-workflow.sh\""
      },
      {
        "matcher": "Edit|Write",
        "command": "bash \"$HOOKS_SRC/post-tool-sound-alert.sh\""
      }
    ]
  }
}
SETTINGS_EOF

echo "✅ .claude/settings.json instalado con hooks de Claude Code"

# ─────────────────────────────────────────────────────────────
# RESUMEN
# ─────────────────────────────────────────────────────────────

echo ""
echo "✅ Instalación completa en: $TARGET_REPO"
echo ""
echo "Git hooks:"
echo "  pre-commit : ${PRE_COMMIT_HOOKS[*]}"
echo "  commit-msg : ${COMMIT_MSG_HOOKS[*]}"
echo ""
echo "Claude Code hooks (PostToolUse):"
echo "  post-edit-migration-check, post-edit-api-sync, post-edit-test-check"
echo "  post-edit-test-suggestion, post-edit-pii-in-logs, post-edit-changelog-suggest"
echo "  post-tool-auto-format, post-tool-cost-tracker, post-tool-feature-workflow"
echo "  post-tool-sound-alert"
echo ""
echo "Claude Code hooks (PreToolUse):"
echo "  pre-edit-secrets, pre-tool-branch-guard"
echo ""
echo "Sound alerts (opt-in):"
echo "  Activar:    bash \"$HOOKS_SRC/post-tool-sound-alert.sh\" on"
echo "  Desactivar: bash \"$HOOKS_SRC/post-tool-sound-alert.sh\" off"
echo "  Estado:     bash \"$HOOKS_SRC/post-tool-sound-alert.sh\" status"
echo ""
echo "Abrí Claude Code desde $TARGET_REPO para que los hooks de Claude Code estén activos."
echo "Documentación: $WORKSPACE_DIR/.claude/hooks/README.md"
