---
name: api-design-review
version: v1
maturity: alpha
owner: "[OWNER_NAME]"
category: engineering
related_skills: [openapi-from-scratch, openapi-validator, architecture-patterns, spring-boot-review]
related_agents: [grv-architect, grv-reviewer]
triggers:
  - "cómo diseño este endpoint"
  - "antes de hacer la API de X"
  - "revisar diseño de contrato"
  - "es correcto usar GET o POST acá"
  - "cómo versiono esta API"
  - "hay breaking change en este cambio"
---

# Skill: api-design-review

## Propósito

Revisar el diseño de un endpoint **antes de escribirlo**. Responde preguntas de diseño (REST vs RPC, versionado, idempotencia, breaking changes) y produce una decisión documentada con tradeoffs.

Mejor invertir 20 minutos acá que refactorizar el contrato cuando ya hay consumers productivos.

## Cuándo usarme

- Antes de implementar un endpoint nuevo.
- Cuando hay dudas sobre el método HTTP correcto.
- Cuando se va a modificar un endpoint existente y no queda claro si es un breaking change.
- Para definir la política de versionado de una API nueva.

## Cuándo NO usarme

- Para revisar el código de implementación → usá `spring-boot-review`.
- Para generar o validar el `openapi.yaml` → usá `openapi-from-scratch` / `openapi-validator`.

## Convenciones GRV

### Versionado

- Todos los endpoints bajo `/v1/` siempre.
- Cambio de versión (`/v2/`) solo cuando hay breaking change inevitable.
- Política de deprecación: mantener la versión vieja al menos 90 días después de publicar la nueva.
- Nunca hacer breaking change en la versión activa sin previo aviso a consumers.

### Naming

- Paths: kebab-case para palabras compuestas (`/v1/siniestros-laborales/`)
- Query params: snake_case (`?fecha_desde=2024-01-01&tipo_siniestro=AT`)
- JSON body: camelCase (`{ "fechaAccidente": "2024-01-01" }`)
- Colecciones: plural en el path (`/v1/siniestros/`, `/v1/prestaciones/`)

### Método HTTP

| Operación | Método | Idempotente |
|---|---|---|
| Leer recurso | GET | ✅ Sí |
| Crear recurso | POST | ❌ No (por defecto) |
| Reemplazar recurso completo | PUT | ✅ Sí (debe serlo) |
| Actualización parcial | PATCH | ⚠️ No por defecto — implementar idempotencia explícita |
| Eliminar | DELETE | ✅ Sí |
| Acción / comando | POST | Depende |

### Breaking vs Non-breaking changes

**Non-breaking** (se puede hacer en `/v1/` sin nueva versión):
- Agregar campo opcional al response
- Agregar query param opcional
- Agregar nuevo endpoint

**Breaking** (requiere nueva versión o deprecación coordinada):
- Eliminar campo del request o response
- Cambiar tipo de campo (string → integer)
- Cambiar semántica de un campo
- Cambiar método HTTP de un endpoint
- Hacer obligatorio un campo que era opcional

## Checklist de diseño

```
□ Método HTTP correcto para la operación
□ Path con prefijo /v1/ y naming en kebab-case
□ Query params en snake_case
□ JSON body en camelCase
□ Idempotencia: PUT y DELETE son idempotentes
□ Respuestas: 200/201 para éxito, 400 para validación, 404 para no encontrado, 409 para conflicto, 500 para error interno
□ ¿Es breaking change? Si sí, ¿hay plan de deprecación?
□ ¿Necesita paginación? (listas de más de ~50 elementos)
□ ¿Necesita autenticación? ¿Qué rol/permiso?
□ ¿Es idempotente con la misma request? ¿Necesita idempotency key?
```

## Flujo

### Paso 1 — Recibir el diseño propuesto

Pedir:
1. ¿Qué hace el endpoint?
2. ¿Quién lo consume (frontend, otro servicio, integración externa)?
3. Diseño propuesto: método, path, request, response

### Paso 2 — Revisar contra checklist

Aplicar el checklist y marcar cada ítem.

### Paso 3 — Detectar breaking changes

Si el endpoint ya existe: comparar la propuesta de cambio con el contrato actual.

### Paso 4 — Sugerir diseño en formato OpenAPI

Entregar el diseño revisado en formato YAML (snippet, no el archivo completo).

## Output

```
REVISIÓN DE API DESIGN — <nombre del endpoint>
================================================

MÉTODO Y PATH
  ✅ POST /v1/prestaciones — correcto para creación
  ⚠️ Sugerencia: si la creación es idempotente (retry seguro), considerar usar PUT con un ID generado por el cliente

NAMING
  ✅ Path en kebab-case
  ❌ Query param 'fechaDesde' debe ser 'fecha_desde' (snake_case)

BREAKING CHANGES
  ⚠️ Remover el campo 'codigoLegacy' del response ES un breaking change.
     Consumidores actuales: ws-facturacion, app-frontend (ver context/microservices.yaml)
     Plan sugerido: deprecar en v1 (agregar header Deprecation), publicar v2 sin el campo

IDEMPOTENCIA
  ✅ DELETE /v1/siniestros/{id} es idempotente (segundo DELETE devuelve 404, no error)

PAGINACIÓN
  ⚠️ GET /v1/siniestros puede devolver miles de registros. Agregar paginación:
     ?page=0&size=20&sort=fecha_accidente,desc

DISEÑO SUGERIDO (fragmento OpenAPI)
  [fragmento yaml]

CHECKLIST FINAL: 4/6 ítems OK — 2 requieren ajuste antes de implementar
```

## Límites

- No valida la implementación, solo el diseño del contrato.
- "Breaking change" depende de quiénes son los consumers: el skill los infiere de `context/microservices.yaml` pero puede estar incompleto.

## TODO para promover a beta

- [ ] Validar la política de versionado (90 días) con el equipo
- [ ] Agregar a `context/microservices.yaml` qué endpoints consume cada servicio (hoy incompleto)
- [ ] Ejemplo real documentado en `docs/case-studies/`
