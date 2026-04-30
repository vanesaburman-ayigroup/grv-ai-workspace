# Hooks del workspace

Estos hooks automatizan guardrails locales de GRV para Claude Code y para Git.
Están pensados para ser rápidos, accionables y silenciosos cuando no aplican.

## Instalación

Para instalar en un proyecto (git hooks + hooks de Claude Code):

```bash
# En el proyecto actual:
bash /ruta/al/workspace/scripts/install-hooks.sh

# En otro repo:
bash /ruta/al/workspace/scripts/install-hooks.sh /ruta/al/proyecto
```

El instalador hace dos cosas:

**1. Git hooks** (en `.git/hooks/` del proyecto):
- `pre-commit` — secrets, migraciones, API sync, TypeScript quality, TODOs, OpenAPI sync
- `commit-msg` — valida formato Conventional Commits

**2. Claude Code hooks** (crea `.claude/settings.json` en el proyecto):
- PreToolUse: `pre-edit-secrets`, `pre-tool-branch-guard`
- PostToolUse: `post-edit-migration-check`, `post-edit-api-sync`, `post-edit-test-check`,
  `post-edit-test-suggestion`, `post-edit-pii-in-logs`, `post-edit-changelog-suggest`,
  `post-tool-auto-format`, `post-tool-cost-tracker`, `post-tool-feature-workflow`,
  `post-tool-sound-alert`

Los paths en el `.claude/settings.json` generado son **absolutos** al workspace,
así que funcionan aunque abras Claude Code desde el directorio del proyecto.

Hace backup automático si ya existía un `.git/hooks/pre-commit` o `.claude/settings.json`
no gestionado por el workspace.

Los hooks `pre-tool-*`, `post-tool-*` y `post-edit-*` los ejecuta Claude Code
cuando están listados en `.claude/settings.json`.

## Hooks disponibles

| Hook | Cuándo corre | Modo | Qué hace |
|---|---|---|---|
| `pre-commit-secrets.sh` | Git pre-commit | blocking | Bloquea secretos obvios en archivos staged. |
| `pre-commit-migration.sh` | Git pre-commit | warn | Detecta migraciones SQL staged y recomienda `mariadb-migration-review`. |
| `pre-commit-api-sync.sh` | Git pre-commit | warn | Detecta controllers Spring staged y recuerda revisar Swagger/OpenAPI. |
| `pre-commit-typescript-quality.sh` | Git pre-commit | warn por default | Si hay `.ts`/`.tsx` staged, corre los scripts existentes `lint` y `typecheck` del `package.json` cercano. Bloquea con `GRV_TS_CHECK_MODE=block`. |
| `post-edit-test-check.sh` | Post-edit/manual | warn | Advierte sobre señales de tests acoplados a implementación. |
| `pre-tool-branch-guard.sh` | PreTool | warn por default | Advierte si Claude intenta editar en ramas protegidas. Bloquea con `GRV_BRANCH_GUARD_MODE=block`. |
| `post-tool-auto-format.sh` | PostTool | warn | Formatea archivos editados si el formatter ya está instalado: `google-java-format` para Java y Prettier para React/TypeScript/JS/CSS/MD/YAML/JSON. |
| `post-tool-cost-tracker.sh` | PostTool/manual | observability | Registra tokens/costos si Claude Code los expone. Resumen: `.claude/hooks/post-tool-cost-tracker.sh summary`. |
| `post-tool-feature-workflow.sh` | PostTool/manual | warn | Al cerrar una feature, recuerda lint/typecheck, review de migraciones SQL, changelog y `/plan` si quedan pasos. |
| `post-tool-sound-alert.sh` | PostTool/manual | opt-in | Reproduce sonidos cortos para eventos de atención, finalización, plan, skill y subagente. |

## Formateo

`post-tool-auto-format.sh` no instala dependencias. Usa lo que ya exista en el
servicio:

- Java: `google-java-format --replace <archivo.java>`.
- Java alternativo: `GOOGLE_JAVA_FORMAT_JAR=/ruta/google-java-format.jar` con `java`.
- React/TypeScript/JavaScript/CSS/Markdown/YAML/JSON: `prettier --write` o `npx --no-install prettier --write`.
- Python: `ruff format` o `black`.
- Shell: `shfmt`, o `bash -n` como validación mínima.

## TypeScript lint/typecheck

`pre-commit-typescript-quality.sh` busca el `package.json` más cercano a los
archivos `.ts`/`.tsx` staged. Si existen scripts `lint` y/o `typecheck`, los
corre con el package manager detectado (`pnpm`, `yarn`, `bun` o `npm`).

Variables útiles:

```bash
GRV_TS_CHECK_MODE=warn   # default, no bloquea
GRV_TS_CHECK_MODE=block  # bloquea el commit si lint/typecheck falla
```

## Sound alerts

Las alertas sonoras están desactivadas por default para no sorprender al equipo.
Sirven como feedback auditivo cuando Claude necesita atención o termina una
parte relevante del flujo.

| Evento | Cuándo suena | Intención |
|---|---|---|
| `attention` | Error, permiso o acción que necesita intervención | Mirar la terminal. |
| `complete` | Una herramienta terminó correctamente | Aviso corto de finalización. |
| `plan` | Se detecta trabajo de planificación | Distinguir cierre de plan de cierre de ejecución. |
| `skill` | Se invoca o termina un skill | Señalar cambio de contexto a skill. |
| `subagent` | Se invoca o termina un subagente | Señalar trabajo delegado. |

Comandos:

```bash
.claude/hooks/post-tool-sound-alert.sh on
.claude/hooks/post-tool-sound-alert.sh off
.claude/hooks/post-tool-sound-alert.sh status
.claude/hooks/post-tool-sound-alert.sh test complete
.claude/hooks/post-tool-sound-alert.sh test attention
.claude/hooks/post-tool-sound-alert.sh test plan
.claude/hooks/post-tool-sound-alert.sh test skill
.claude/hooks/post-tool-sound-alert.sh test subagent
```

Si no hay reproductor (`afplay`, `paplay`, `pw-play`, `aplay`, `ffplay` o
`play`), usa el bell de terminal como fallback.

## Checklist de cierre de feature

Al terminar una feature, `post-tool-feature-workflow.sh` recuerda:

1. correr lint/typecheck si hubo TypeScript;
2. usar `mariadb-migration-review` si hubo migraciones SQL o cambios de datos;
3. usar `changelog-keeper` antes de cerrar feature/release;
4. usar `/plan` si quedan pasos de rollout, deuda técnica o decisiones abiertas.

También puede ejecutarse manualmente:

```bash
.claude/hooks/post-tool-feature-workflow.sh feature-done
```
