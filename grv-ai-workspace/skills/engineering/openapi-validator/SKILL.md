---
name: openapi-validator
version: v1
maturity: alpha
owner: "[OWNER_NAME]"
category: engineering
related_skills: [openapi-from-scratch, api-doc-sync, api-design-review]
related_agents: [grv-doc-keeper]
triggers:
  - "validar openapi"
  - "qué problemas tiene este yaml"
  - "revisar contrato openapi"
  - "lintear el swagger"
  - "spectral"
---

# Skill: openapi-validator

## Propósito

Validar un `openapi.yaml` existente con reglas estándar (Spectral) y reglas custom GRV, produciendo un reporte con severity clasificada.

## Cuándo usarme

- Antes de mergear un MR que modifica `openapi.yaml`.
- Después de correr `openapi-from-scratch` para validar el resultado.
- Como parte del checklist de `release-readiness`.
- Cuando hay dudas sobre si el contrato cumple las convenciones GRV.

## Cuándo NO usarme

- Para generar un openapi.yaml desde cero → usá `openapi-from-scratch`.
- Para detectar drift entre código y openapi.yaml → usá `api-doc-sync`.

## Reglas de validación

### Tier 1 — Error (bloquea MR)

| Regla | Descripción |
|---|---|
| `openapi-version` | Debe ser `3.0.x` |
| `info-required` | `info.title` y `info.version` presentes |
| `paths-not-empty` | Al menos un path definido |
| `operation-operationId` | Cada operación debe tener `operationId` único |
| `response-200-present` | Todo endpoint debe tener al menos respuesta 200 |
| `no-$ref-siblings` | No mezclar `$ref` con propiedades en el mismo objeto |

### Tier 2 — Warning (debe revisarse antes de release)

| Regla | Descripción |
|---|---|
| `grv-path-version` | Todos los paths deben empezar con `/v1/` o `/vN/` |
| `grv-query-snake-case` | Query params en snake_case (no camelCase) |
| `operation-description` | Cada operación debe tener `description` |
| `schema-description` | Cada schema en `components/schemas` debe tener `description` |
| `response-4xx-defined` | Endpoints que reciben body deben definir respuesta 400/422 |
| `response-500-defined` | Todo endpoint debe definir respuesta 500 |
| `no-todo-in-prod` | Si el yaml tiene `# TODO:` presentes, warn para producción |

### Tier 3 — Info (sugerencia)

| Regla | Descripción |
|---|---|
| `operation-tags` | Toda operación debería tener al menos un tag |
| `schema-examples` | Se recomienda incluir `example:` en schemas |
| `grv-contact-info` | `info.contact` recomendado para saber a quién contactar |
| `grv-servers-both` | Recomendado tener server dev y prod definidos |

## Flujo

### Con Spectral instalado

```bash
# Instalar si no está
npm install -g @stoplight/spectral-cli

# Correr con ruleset base + custom GRV
spectral lint openapi.yaml --ruleset .spectral.grv.yaml
```

El archivo `.spectral.grv.yaml` con las reglas custom GRV queda pendiente de crear en el repositorio (ver TODO).

### Sin Spectral

Si Spectral no está disponible, hacer la validación manualmente contra las reglas del Tier 1 y Tier 2 leyendo el YAML.

## Output

```
VALIDACIÓN OPENAPI — <archivo>
==============================

ERROR (bloquea MR)
  ❌ operationId duplicado: 'getSiniestro' aparece en /v1/siniestros/{id} y /v1/siniestros/detalle
  ❌ Sin respuesta 200 en POST /v1/prestaciones

WARNING (revisar antes de release)
  ⚠️ Path /siniestros/{id} no tiene prefijo /v1/
  ⚠️ Query param 'estadoSiniestro' debería ser 'estado_siniestro' (snake_case)
  ⚠️ 3 schemas sin descripción: SiniestroRequest, PrestacionDto, ErrorResponse

INFO (sugerencia)
  ℹ️ 5 operaciones sin ejemplos de respuesta
  ℹ️ info.contact no definido

RESUMEN: 2 errores, 3 warnings, 6 infos
Acción requerida: corregir errores antes de mergear
```

## Límites

- Alpha: el archivo `.spectral.grv.yaml` con reglas custom todavía no existe — las reglas GRV se aplican manualmente.
- Spectral no valida semántica de negocio (si el schema es correcto para el dominio GRV).
- No valida que el yaml sea consistente con el código Java → eso es `api-doc-sync`.

## TODO para promover a beta

- [ ] Crear `.spectral.grv.yaml` con las reglas custom GRV codificadas
- [ ] Integrar con el hook `pre-commit-openapi-sync.sh`
- [ ] Probado contra 3+ servicios reales
