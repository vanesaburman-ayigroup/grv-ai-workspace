#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# scripts/install-hooks.sh
# -----------------------------------------------------------------------------
# Instala wrappers de Git hooks locales para ejecutar los hooks del workspace.
# -----------------------------------------------------------------------------

set -euo pipefail

WORKSPACE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GIT_ROOT="$(git -C "$WORKSPACE_ROOT" rev-parse --show-toplevel 2>/dev/null || echo "$WORKSPACE_ROOT")"
HOOKS_DIR="$WORKSPACE_ROOT/.claude/hooks"
GIT_HOOKS_DIR="$GIT_ROOT/.git/hooks"

if [[ ! -d "$HOOKS_DIR" ]]; then
  echo "❌ No existe $HOOKS_DIR. Ejecutar desde la raíz del workspace."
  exit 1
fi

if [[ ! -d "$GIT_HOOKS_DIR" ]]; then
  echo "❌ No existe $GIT_HOOKS_DIR. ¿Este directorio es un repo git?"
  exit 1
fi

HOOK_SCRIPTS=("$HOOKS_DIR"/*.sh)
if [[ ! -e "${HOOK_SCRIPTS[0]}" ]]; then
  echo "❌ No hay scripts .sh en $HOOKS_DIR."
  exit 1
fi

chmod +x "${HOOK_SCRIPTS[@]}"

install_wrapper() {
  local hook_name="$1"
  local pattern="$2"
  local target="$GIT_HOOKS_DIR/$hook_name"

  if [[ -f "$target" ]]; then
    if grep -q "grv-ai-workspace managed hook" "$target"; then
      echo "ℹ️  Actualizando hook gestionado existente: .git/hooks/$hook_name"
    else
      local backup="$target.grv-backup.$(date +%Y%m%d%H%M%S)"
      cp "$target" "$backup"
      echo "ℹ️  Backup de hook existente: $backup"
    fi
  fi

  cat > "$target" <<EOF
#!/usr/bin/env bash
# grv-ai-workspace managed hook
set -euo pipefail

HOOKS_DIR="$HOOKS_DIR"

for hook in "\$HOOKS_DIR"/$pattern; do
  [[ -x "\$hook" ]] || continue
  "\$hook" "\$@"
done
EOF

  chmod +x "$target"
  echo "✅ Instalado .git/hooks/$hook_name"
}

install_wrapper "pre-commit" "pre-commit-*.sh"

echo ""
echo "Hooks instalados."
echo "Sound alerts:"
echo "  Activar:    .claude/hooks/post-tool-sound-alert.sh on"
echo "  Desactivar: .claude/hooks/post-tool-sound-alert.sh off"
echo "  Estado:     .claude/hooks/post-tool-sound-alert.sh status"
