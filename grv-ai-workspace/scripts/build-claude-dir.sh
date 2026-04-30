#!/usr/bin/env bash
# scripts/build-claude-dir.sh
# Sincroniza .claude/skills/ y .claude/agents/ con skills/ y agents/
# del workspace para que Claude Code los descubra via additionalDirectories.
#
# Ejecutar después de agregar o modificar skills/agentes.
# install-hooks.sh lo llama automáticamente.

set -euo pipefail

WORKSPACE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$WORKSPACE_DIR"

echo "🔄 Sincronizando .claude/skills/ y .claude/agents/..."

# Skills — copiar SKILL.md de cada subdirectorio
for category in skills/engineering skills/domain skills/processes; do
  [ -d "$category" ] || continue
  for skill_dir in "$category"/*/; do
    name=$(basename "$skill_dir")
    if [ -f "${skill_dir}SKILL.md" ]; then
      mkdir -p ".claude/skills/$name"
      cp "${skill_dir}SKILL.md" ".claude/skills/$name/SKILL.md"
    fi
  done
done

# Onboarding skill (archivo suelto)
if [ -f "skills/onboarding/SKILL.md" ]; then
  mkdir -p ".claude/skills/onboarding"
  cp "skills/onboarding/SKILL.md" ".claude/skills/onboarding/SKILL.md"
fi

# Agentes
mkdir -p ".claude/agents"
for agent_file in agents/*.md; do
  [ -f "$agent_file" ] || continue
  cp "$agent_file" ".claude/agents/$(basename "$agent_file")"
done

skill_count=$(ls .claude/skills/ 2>/dev/null | wc -l)
agent_count=$(ls .claude/agents/ 2>/dev/null | wc -l)
echo "✅ $skill_count skills, $agent_count agentes sincronizados en .claude/"
