# How to add a hook

Un hook es un script que se dispara automáticamente en un momento específico
del ciclo de desarrollo: pre-commit, pre-push, post-edit, pre-MR, etc.

## Tipos de hooks

| Hook | Dispara en | Uso típico |
|---|---|---|
| `pre-commit-*` | Antes de cada commit local | Validaciones rápidas, linting, secrets scan |
| `pre-push-*` | Antes de push | Tests, validaciones que toman más tiempo |
| `post-edit-*` | Después que Claude edita un archivo | Checks de calidad del output de Claude |
| `pre-tool-*` | Antes de una herramienta de Claude Code | Guardrails antes de editar o ejecutar comandos |
| `post-tool-*` | Después de una herramienta de Claude Code | Formato, observabilidad, alertas |
| `pre-mr-*` | Al crear MR (via CI) | Review automático completo |
| `post-deploy-*` | Después de deploy (via CI) | Post-mortem, smoke tests |

## Estructura

```
.claude/hooks/<hook-name>.sh
```

Un script bash (o Python si necesita más lógica). Ejecutable.

## Plantilla

```bash
#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# <hook-name>.sh
# -----------------------------------------------------------------------------
# Propósito: <una línea>
# Dispara en: <cuándo>
# Modo: warn | blocking
# Skill asociado: skills/engineering/<skill>
# -----------------------------------------------------------------------------

set -euo pipefail

# 1. Detectar si el hook debe hacer algo
# ...

# 2. Si no aplica, salir sin ruido
if [[ condicion ]]; then
  exit 0
fi

# 3. Hacer el check
# ...

# 4. Reportar resultado
echo "🔍 grv-ai-workspace: ..."

# 5. Exit code apropiado
#    0 = ok, 1 = warning, otros = error bloqueante
exit 0
```

## Modos

- **Warn**: imprime mensajes pero retorna 0. No bloquea. Default para hooks nuevos.
- **Blocking**: retorna 1 si hay problemas. Bloquea el commit/push. Solo para hooks maduros.

Todo hook arranca en warn mode. Pasa a blocking cuando:
- Falsos positivos < 5% en casos reales.
- Validado por el owner del hook.
- Anunciado al equipo.

## Flujo para agregar un hook

1. Branch `feat/hook-<nombre>`.
2. Crear el script en `.claude/hooks/`.
3. `chmod +x` (hacer ejecutable).
4. Agregarlo a `hooks.enabled` en `.claude/settings.json`.
5. Probar en commits locales reales — al menos 5 casos.
6. Documentar en el header del script.
7. MR con descripción + casos de prueba.
8. Merge.
9. Rollout: anunciar al equipo cuando pase a blocking.

## Instalación en git

Los hooks de `.claude/hooks/` no se instalan solos en `.git/hooks/`. Cada
dev debe hacerlo una vez. Opciones:

1. **Script de setup**: ejecutar `scripts/install-hooks.sh` desde la raíz del repo. Instala un wrapper en `.git/hooks/pre-commit` que corre todos los `.claude/hooks/pre-commit-*.sh`.
2. **Manual**: crear symlinks de `.claude/hooks/pre-commit-*.sh` a `.git/hooks/pre-commit`.
3. **Con `pre-commit` framework**: tener un `.pre-commit-config.yaml` que apunte a los hooks del workspace. Esto permite composición con otros hooks estándar (black, eslint, etc).

Los hooks `pre-tool-*`, `post-tool-*` y `post-edit-*` los ejecuta Claude Code
cuando están listados en `.claude/settings.json`.

## Hooks disponibles

| Hook | Tipo | Modo | Propósito |
|---|---|---|---|
| `pre-tool-branch-guard` | PreTool | warn por default | Advierte si Claude intenta modificar estando en `main`, `master`, `develop` o `release/*`. Puede bloquear con `GRV_BRANCH_GUARD_MODE=block`. |
| `post-tool-auto-format` | PostTool | warn | Ejecuta formateadores ya instalados (`prettier`, `ruff`, `black`, `shfmt`) sobre archivos editados. No instala dependencias. |
| `post-tool-cost-tracker` | PostTool | observability | Registra eventos y tokens/costos si Claude Code los expone en `.claude/logs/cost-tracker.jsonl`. Resumen: `.claude/hooks/post-tool-cost-tracker.sh summary`. |
| `post-tool-sound-alert` | PostTool / comando | opt-in | Reproduce sonidos cortos para atención, finalización, plan, skill y subagente. |

Para estimaciones de costo, `post-tool-cost-tracker` acepta las variables
opcionales `GRV_COST_INPUT_USD_PER_MTOK` y `GRV_COST_OUTPUT_USD_PER_MTOK`
(USD por millón de tokens). Si no están definidas, solo registra tokens y
costos explícitamente reportados por Claude Code.

Los parsers de payload de hooks usan `GRV_HOOK_MAX_DEPTH` (default `12`) para
evitar recursión excesiva en payloads anidados.

## Sound alerts

El hook de sonido está desactivado por default para no sorprender al equipo.
Comandos:

```bash
.claude/hooks/post-tool-sound-alert.sh on
.claude/hooks/post-tool-sound-alert.sh off
.claude/hooks/post-tool-sound-alert.sh status
.claude/hooks/post-tool-sound-alert.sh test complete
.claude/hooks/post-tool-sound-alert.sh test attention
```

Si el sistema no tiene reproductor de audio (`afplay`, `paplay`, `pw-play`,
`aplay`, `ffplay` o `play`), usa el bell de terminal como fallback.

## Hooks en CI vs hooks locales

Los hooks locales son rápidos y disciplinan al dev. Los hooks en CI (GitLab)
son el "safety net" de lo que escapa local. Regla:

- **Local**: warnings útiles, blocking de cosas obvias (secrets).
- **CI**: blocking de todo lo crítico, aunque tarde más.

## Buenas prácticas

- **Ser rápido**. Un pre-commit >2s frustra al equipo.
- **Ser silencioso cuando todo está bien**. Output solo cuando hay algo que reportar.
- **Ser accionable**. Si reportás un problema, decí cómo arreglarlo.
- **Ser escapable**. `--no-verify` debe seguir funcionando (respeto al dev).
- **Loguear**. `.claude/logs/<hook-name>.log` para debugging.
