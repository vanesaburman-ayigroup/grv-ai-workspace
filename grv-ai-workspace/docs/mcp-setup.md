# MCP Setup

Guía para configurar los MCPs del workspace en tu máquina local.

## Pre-requisitos

- Claude Code instalado (`claude --version`)
- Node.js 18+ (para los MCPs stdio)
- Acceso a la red interna (para MariaDB dev/prod)
- Credenciales del usuario read-only de MariaDB

## Paso 1: Variables de entorno

```bash
cp .env.example .env
```

Editar `.env` y completar:

- `GRV_MARIADB_DEV_*` — obligatorio. Ambiente default.
- `GRV_MARIADB_PROD_*` — opcional pero recomendado para bugs.
- `CONTEXT7_API_KEY` — opcional. Si no lo tenés, el MCP se deshabilita solo.
- `SENTRY_*` — opcional. Requerido por `deploy-post-mortem`.
- `GRANOLA_API_KEY` — opcional. Requerido por `granola-to-actions`.

**NO commitees el `.env`.** Está en `.gitignore` pero igual revisá.

## Paso 2: MariaDB MCP server

Usamos el MCP de MariaDB en modo SSE. Levantar un server por ambiente:

```bash
# DEV (default)
npx @mariadb/mcp-server --sse --port 3333 \
  --host $GRV_MARIADB_DEV_HOST \
  --port $GRV_MARIADB_DEV_PORT \
  --user $GRV_MARIADB_DEV_USER \
  --password $GRV_MARIADB_DEV_PASSWORD \
  --database $GRV_MARIADB_DEV_DATABASE \
  --readonly

# PROD (solo cuando haga falta)
npx @mariadb/mcp-server --sse --port 3334 \
  --host $GRV_MARIADB_PROD_HOST \
  --port $GRV_MARIADB_PROD_PORT \
  --user $GRV_MARIADB_PROD_USER \
  --password $GRV_MARIADB_PROD_PASSWORD \
  --database $GRV_MARIADB_PROD_DATABASE \
  --readonly
```

Alternativa: correrlos como servicios via `pm2`, `systemd` o script local en `scripts/start-mcps.sh` (TODO del workspace).

## Paso 3: Seguridad de MariaDB

### Hasta que tengamos usuario dedicado

Mientras no exista el usuario `claude_readonly`, las capas de defensa son:

1. **Usuario con permisos limitados** en `.env` (pedirle a `[DEVOPS_REFERENT]` uno si no lo tenés).
2. **Read-only enforcement** en el MCP (`--readonly` flag).
3. **Query validation en skills**: los skills validan que el statement empiece con `SELECT|SHOW|EXPLAIN|DESCRIBE`.
4. **max_execution_time** por sesión: el wrapper ejecuta `SET SESSION max_execution_time = 5000` antes de cada query.
5. **LIMIT obligatorio** en SELECTs (excepto COUNT/EXPLAIN).
6. **Rate limiting suave** (20 queries/min default, configurable en `.env`).
7. **Bloqueo heurístico de writes**: el skill rechaza cualquier cosa que matchee `INSERT|UPDATE|DELETE|DROP|ALTER|TRUNCATE|CREATE|GRANT|REVOKE|RENAME|REPLACE|CALL|LOAD`.

### Una vez creado `claude_readonly`

Correr `sql/create-claude-readonly-user.sql` en dev y prod, actualizar `.env`
con las credenciales nuevas, y el resto de las capas siguen activas como
defensa en profundidad.

## Paso 4: Cambio entre DEV y PROD

Claude **siempre arranca en DEV**. Para cambiar a PROD en una sesión:

```
Usuario: "Cambiá a prod, necesito ver datos reales del bug 2469285"
Claude: "OK, cambio a prod. Confirmo: voy a ejecutar queries contra
         GRV_MARIADB_PROD_HOST. ¿Procedo? (sí/no)"
```

Claude **nunca** cambia a prod por iniciativa propia. El cambio queda
logueado en `.claude/logs/mariadb-queries.log`.

## Paso 5: PII warning

El wrapper muestra un aviso **una sola vez por sesión** la primera vez
que una query toca una tabla sensible. El aviso es informativo, no
bloquea. Los queries que tocan tablas sensibles se loguean **sin
resultados**, solo el query y el timestamp.

Ver `context/sensitive-tables.yaml` para la lista.

## Paso 6: Otros MCPs

### Playwright

```bash
npx -y @playwright/mcp@latest
```

Primera vez descarga browsers. Paciencia.

### Context7

SSE, no necesita proceso local. Solo requiere `CONTEXT7_API_KEY` en `.env`.

### Sequential Thinking

```bash
npx -y @modelcontextprotocol/server-sequential-thinking
```

### Granola

SSE. Ya está configurado si tenés tu cuenta Granola conectada en claude.ai.

## Paso 7: Verificación

Dentro de Claude Code:

```
Usuario: "listá los MCPs disponibles"
Claude: [muestra la lista con estado de cada uno]

Usuario: "probá el MCP de MariaDB dev con SHOW TABLES LIMIT 5"
Claude: [ejecuta y muestra resultado]
```

Si alguno falla, revisar:
- Proceso del MCP corriendo (para stdio/sse locales)
- `.env` cargado correctamente
- Permisos del usuario de MariaDB
- Logs en `.claude/logs/`

## Troubleshooting

| Síntoma | Probable causa | Fix |
|---|---|---|
| `Connection refused` | MCP server no levantado | Correr el `npx` del paso 2 |
| `Access denied` en MariaDB | Usuario sin permiso o pass mal | Revisar `.env` |
| `Query blocked` | Statement no es SELECT | Es el wrapper haciendo su trabajo |
| `Rate limited` | Más de 20 queries/min | Esperar o subir `GRV_MARIADB_RATE_LIMIT_PER_MIN` |
| Claude cambia a prod solo | Bug — reportalo | Revisar logs y abrir issue |
