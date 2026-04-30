#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# scripts/install-hooks.sh
# -----------------------------------------------------------------------------
# Instala wrappers de Git hooks locales para ejecutar los hooks del workspace.
# -----------------------------------------------------------------------------

set -euo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
HOOKS_DIR="$ROOT/.claude/hooks"
GIT_HOOKS_DIR="$ROOT/.git/hooks"

if [[ ! -d "$HOOKS_DIR" ]]; then
  echo "❌ No existe $HOOKS_DIR. Ejecutar desde la raíz del workspace."
  exit 1
fi

if [[ ! -d "$GIT_HOOKS_DIR" ]]; then
  echo "❌ No existe $GIT_HOOKS_DIR. ¿Este directorio es un repo git?"
  exit 1
fi

chmod +x "$HOOKS_DIR"/*.sh

install_wrapper() {
  local hook_name="$1"
  local pattern="$2"
  local target="$GIT_HOOKS_DIR/$hook_name"

  if [[ -f "$target" ]] && ! grep -q "grv-ai-workspace managed hook" "$target"; then
    local backup="$target.grv-backup.$(date +%Y%m%d%H%M%S)"
    cp "$target" "$backup"
    echo "ℹ️  Backup de hook existente: $backup"
  fi

  cat > "$target" <<EOF
#!/usr/bin/env bash
# grv-ai-workspace managed hook
set -euo pipefail

ROOT="\$(git rev-parse --show-toplevel)"
HOOKS_DIR="\$ROOT/.claude/hooks"

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
