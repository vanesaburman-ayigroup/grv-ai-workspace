#!/usr/bin/env bash
# scripts/install-hooks.sh
# Instala el workspace GRV en un repositorio de proyecto.
#
# Uso:
#   bash scripts/install-hooks.sh                    # instala en el repo actual
#   bash scripts/install-hooks.sh /path/to/repo      # instala en otro repo
#
# Qué instala:
#   1. .git/hooks/pre-commit y commit-msg  — git hooks
#   2. .claude/settings.json               — hooks Claude Code + skills + agentes + contexto
#   3. CLAUDE.md (stub)                    — importa el CLAUDE.md del workspace
#
# Después de esto podés abrir Claude Code desde el directorio del proyecto
# y tener disponibles todos los skills, agentes, hooks y contexto del workspace.

set -euo pipefail

WORKSPACE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET_REPO="${1:-$(git -C "$WORKSPACE_DIR" rev-parse --show-toplevel 2>/dev/null || echo "$WORKSPACE_DIR")}"

# En Windows (Git Bash / MSYS2), pwd devuelve /c/Users/... pero Claude Code
# necesita C:/Users/... (paths nativos Windows). cygpath -m hace esa conversión.
# En Linux/Mac, cygpath no existe y usamos los paths tal cual.
to_win_path() {
  if command -v cygpath &>/dev/null; then
    cygpath -m "$1"
  else
    echo "$1"
  fi
}

WORKSPACE_WIN=$(to_win_path "$WORKSPACE_DIR")
TARGET_WIN=$(to_win_path "$TARGET_REPO")

echo "📦 GRV AI Workspace — Instalador"
echo "   Workspace:    $WORKSPACE_WIN"
echo "   Repo destino: $TARGET_WIN"
echo ""

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
      echo "ℹ️  Actualizando git hook: .git/hooks/$hook_name"
    else
      local backup="$target.grv-backup.$(date +%Y%m%d%H%M%S)"
      cp "$target" "$backup"
      echo "ℹ️  Backup de hook existente: $backup"
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
echo "✅ Git hook pre-commit (${#PRE_COMMIT_HOOKS[@]} scripts)"

install_dispatcher "commit-msg" "${COMMIT_MSG_HOOKS[@]}"
echo "✅ Git hook commit-msg (${#COMMIT_MSG_HOOKS[@]} scripts)"

# ─────────────────────────────────────────────────────────────
# PARTE 2 — .claude/settings.json
#           Hooks Claude Code + skills + agentes + contexto
# ─────────────────────────────────────────────────────────────

CLAUDE_DIR="$TARGET_REPO/.claude"
SETTINGS_FILE="$CLAUDE_DIR/settings.json"

mkdir -p "$CLAUDE_DIR"

if [[ -f "$SETTINGS_FILE" ]]; then
  if grep -q "grv-ai-workspace" "$SETTINGS_FILE" 2>/dev/null; then
    echo "ℹ️  Actualizando .claude/settings.json"
  else
    local_backup="$SETTINGS_FILE.grv-backup.$(date +%Y%m%d%H%M%S)"
    cp "$SETTINGS_FILE" "$local_backup"
    echo "ℹ️  Backup de settings.json existente: $local_backup"
  fi
fi

HOOKS_SRC_WIN=$(to_win_path "$HOOKS_SRC")

# Sincronizar .claude/skills/ y .claude/agents/ en el workspace antes de instalar
bash "$WORKSPACE_DIR/scripts/build-claude-dir.sh"

cat > "$SETTINGS_FILE" << SETTINGS_EOF
{
  "\$schema": "https://json.schemastore.org/claude-code-settings.json",
  "_managed_by": "grv-ai-workspace — no editar manualmente. Re-ejecutar install-hooks.sh para actualizar.",
  "_workspace": "$WORKSPACE_WIN",
  "additionalDirectories": [
    "$WORKSPACE_WIN"
  ],
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [{"type": "command", "command": "bash \"$HOOKS_SRC_WIN/pre-edit-secrets.sh\""}]
      },
      {
        "matcher": "Edit|Write",
        "hooks": [{"type": "command", "command": "bash \"$HOOKS_SRC_WIN/pre-tool-branch-guard.sh\""}]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [{"type": "command", "command": "bash \"$HOOKS_SRC_WIN/post-edit-migration-check.sh\""}]
      },
      {
        "matcher": "Edit|Write",
        "hooks": [{"type": "command", "command": "bash \"$HOOKS_SRC_WIN/post-edit-api-sync.sh\""}]
      },
      {
        "matcher": "Edit|Write",
        "hooks": [{"type": "command", "command": "bash \"$HOOKS_SRC_WIN/post-edit-test-check.sh\""}]
      },
      {
        "matcher": "Edit|Write",
        "hooks": [{"type": "command", "command": "bash \"$HOOKS_SRC_WIN/post-edit-test-suggestion.sh\""}]
      },
      {
        "matcher": "Edit|Write",
        "hooks": [{"type": "command", "command": "bash \"$HOOKS_SRC_WIN/post-edit-pii-in-logs.sh\""}]
      },
      {
        "matcher": "Edit|Write",
        "hooks": [{"type": "command", "command": "bash \"$HOOKS_SRC_WIN/post-edit-changelog-suggest.sh\""}]
      },
      {
        "matcher": "Edit|Write",
        "hooks": [{"type": "command", "command": "bash \"$HOOKS_SRC_WIN/post-tool-auto-format.sh\""}]
      },
      {
        "matcher": "Edit|Write",
        "hooks": [{"type": "command", "command": "bash \"$HOOKS_SRC_WIN/post-tool-cost-tracker.sh\""}]
      },
      {
        "matcher": "Edit|Write",
        "hooks": [{"type": "command", "command": "bash \"$HOOKS_SRC_WIN/post-tool-feature-workflow.sh\""}]
      },
      {
        "matcher": "Edit|Write",
        "hooks": [{"type": "command", "command": "bash \"$HOOKS_SRC_WIN/post-tool-sound-alert.sh\""}]
      }
    ]
  },
  "defaults": {
    "mariadb_environment": "dev",
    "require_explicit_prod_switch": true,
    "block_write_statements": true,
    "enforce_limit_on_select": true,
    "pii_warning": true
  }
}
SETTINGS_EOF

echo "✅ .claude/settings.json (skills + agentes + contexto + hooks)"

# ─────────────────────────────────────────────────────────────
# PARTE 3 — CLAUDE.md stub
#           Si el proyecto no tiene CLAUDE.md, crea uno que
#           importa el del workspace. Si ya tiene uno, no lo toca.
# ─────────────────────────────────────────────────────────────

CLAUDE_MD="$TARGET_REPO/CLAUDE.md"

if [[ ! -f "$CLAUDE_MD" ]]; then
  cat > "$CLAUDE_MD" << CLAUDE_EOF
<!-- grv-ai-workspace stub — podés agregar instrucciones específicas del proyecto debajo -->
@$WORKSPACE_WIN/CLAUDE.md
CLAUDE_EOF
  echo "✅ CLAUDE.md stub creado (importa instrucciones del workspace)"
else
  if grep -q "grv-ai-workspace" "$CLAUDE_MD" 2>/dev/null; then
    echo "ℹ️  CLAUDE.md ya tiene el import del workspace"
  else
    echo "ℹ️  CLAUDE.md ya existe — no se modificó. Para importar el workspace agregá:"
    echo "     @$WORKSPACE_WIN/CLAUDE.md"
  fi
fi

# ─────────────────────────────────────────────────────────────
# PARTE 4 — .claude/commands/
#           Copia cada skill como slash command del proyecto
#           (el mecanismo que Claude Code sí descubre via /)
# ─────────────────────────────────────────────────────────────

COMMANDS_DIR="$TARGET_REPO/.claude/commands"
mkdir -p "$COMMANDS_DIR"

# Copiar SKILL.md como command file, stripeando el frontmatter YAML
install_skill_as_command() {
  local skill_file="$1"
  local skill_name="$2"
  awk 'BEGIN{n=0} /^---$/{n++; if(n==2){found=1}; next} found{print}' "$skill_file" \
    > "$COMMANDS_DIR/${skill_name}.md"
}

for dir in "$WORKSPACE_DIR/skills/engineering/"*/; do
  name=$(basename "$dir")
  [ -f "$dir/SKILL.md" ] && install_skill_as_command "$dir/SKILL.md" "$name"
done
for dir in "$WORKSPACE_DIR/skills/domain/"*/; do
  name=$(basename "$dir")
  [ -f "$dir/SKILL.md" ] && install_skill_as_command "$dir/SKILL.md" "$name"
done
for dir in "$WORKSPACE_DIR/skills/processes/"*/; do
  name=$(basename "$dir")
  [ -f "$dir/SKILL.md" ] && install_skill_as_command "$dir/SKILL.md" "$name"
done
[ -f "$WORKSPACE_DIR/skills/onboarding/SKILL.md" ] && \
  install_skill_as_command "$WORKSPACE_DIR/skills/onboarding/SKILL.md" "grv-onboarding"

cmd_count=$(ls "$COMMANDS_DIR" | wc -l)
echo "✅ $cmd_count slash commands instalados en .claude/commands/ (invocables con /nombre)"

# ─────────────────────────────────────────────────────────────
# RESUMEN
# ─────────────────────────────────────────────────────────────

echo ""
echo "✅ Instalación completa en: $TARGET_WIN"
echo ""
echo "Skills disponibles al abrir Claude Code desde el proyecto:"
echo "  Engineering : adr-helper, api-design-review, api-doc-sync, architecture-patterns,"
echo "                c4-diagrams, changelog-keeper, database-design-heavy-table,"
echo "                db-versioning-audit, functional-test-author, mariadb-migration-review,"
echo "                observability-blueprint, openapi-from-scratch, openapi-validator,"
echo "                react-mfe-review, spring-boot-review, test-coverage-strategy,"
echo "                unit-test-author, workspace-contribution"
echo "  Domain      : grv-arquitectura-plataforma, grv-autorizaciones-medicas,"
echo "                grv-bugs-conocidos, grv-facturacion, grv-glosario, grv-prestaciones,"
echo "                grv-provincia-art, grv-regulaciones-srt, grv-satapp, grv-sgc,"
echo "                grv-siniestros, grv-turnos-logistica"
echo "  Processes   : cross-team-impact, incident-command, release-readiness,"
echo "                sprint-planning-impact, tech-debt-audit"
echo ""
echo "Agentes disponibles:"
echo "  grv-architect, grv-doc-keeper, grv-domain-expert, grv-migration-guard,"
echo "  grv-process-analyst, grv-reviewer, grv-tech-lead, grv-test-author"
echo ""
echo "Sound alerts (opt-in):"
echo "  Activar:  bash \"$HOOKS_SRC_WIN/post-tool-sound-alert.sh\" on"
echo "  Estado:   bash \"$HOOKS_SRC_WIN/post-tool-sound-alert.sh\" status"
echo ""
echo "Abrí Claude Code desde $TARGET_REPO y todo estará disponible."
