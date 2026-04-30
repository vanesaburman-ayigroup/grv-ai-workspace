---
name: api-doc-sync
version: v1
maturity: alpha
owner: "[BACKEND_REFERENT]"
category: engineering
related_skills: [spring-boot-review, changelog-keeper, openapi-from-scratch, openapi-validator]
related_agents: [grv-doc-keeper]
triggers:
  - "usuario modificó un controller Spring Boot"
  - "pre-commit hook pre-commit-api-sync.sh detecta cambios en Controller"
  - "usuario pide 'actualizá el swagger'"
---

# Skill: api-doc-sync

## Propósito

Mantener la documentación de APIs (Swagger / OpenAPI) sincronizada con
el código real de los controllers Spring Boot. Detecta drift entre lo
que está expuesto y lo que está documentado.

## Cuándo usarme

- Después de modificar un `@RestController`.
- Cuando el hook `pre-commit-api-sync.sh` avisa.
- Antes de publicar una nueva versión de un servicio.
- Review de MR que toca endpoints.

## Qué detecta

- Endpoints nuevos sin documentación.
- Endpoints viejos que se eliminaron pero siguen documentados.
- Cambios en request/response bodies no reflejados.
- Cambios en códigos HTTP retornados.
- Parámetros nuevos o removidos en query/path/header.
- Cambios en autenticación/autorización.
- Ejemplos desactualizados.

## Fuente de verdad

- El código del controller (lo que realmente está expuesto).
- Las anotaciones de Swagger/OpenAPI (`@Operation`, `@ApiResponse`, `@Schema`, etc).
- Los DTOs usados en request/response.

## Flujo

1. Pedir el controller o el diff del cambio.
2. Leer el código y extraer la lista de endpoints expuestos con sus contratos.
3. Leer la documentación actual (Swagger annotations o archivo OpenAPI).
4. Cruzar ambos y generar un report de diferencias.
5. Ofrecer generar las anotaciones faltantes o actualizadas.

## Output

```
===========================================================
API DOC SYNC — <nombre del controller>
===========================================================

ENDPOINTS EN EL CÓDIGO
  - GET  /api/v1/siniestros/{id}      [documented]
  - POST /api/v1/siniestros           [MISSING @Operation]
  - PUT  /api/v1/siniestros/{id}      [DOC DRIFT: response type changed]

DIFERENCIAS DETECTADAS
  1. POST /api/v1/siniestros
     - No tiene @Operation.
     - Sugerencia: agregar summary, description, @ApiResponse para 201 y 400.

  2. PUT /api/v1/siniestros/{id}
     - DTO de response en el código: SiniestroResponseV2
     - DTO documentado: SiniestroResponse
     - Acción requerida: actualizar @Schema o revertir el cambio.

SUGERENCIAS DE ACTUALIZACIÓN
  [bloques de código con las anotaciones corregidas]
```

## Modo standalone (openapi.yaml sin anotaciones)

Para servicios que **no tienen anotaciones Swagger/springdoc**, este skill no aplica directamente. En ese caso:

1. Usá `openapi-from-scratch` para generar el `openapi.yaml` leyendo los controllers.
2. Luego usá `openapi-validator` para validar el resultado.
3. Una vez que existe el `openapi.yaml`, este skill puede detectar drift entre el archivo y el código.

**Detección de springdoc vs swagger-core** — verificar en `pom.xml`:
- `org.springdoc:springdoc-openapi-starter-webmvc-ui` → springdoc (moderno)
- `io.swagger.core.v3:swagger-annotations` → swagger-core legacy
- Ninguno de los dos → sin Swagger, ir a `openapi-from-scratch`

## Límites

- No genera el archivo OpenAPI desde cero si no hay anotaciones → usá `openapi-from-scratch`.
- Asume que el proyecto usa springdoc-openapi o similar. Si usa otra
  herramienta, el skill necesita adaptación.
- No valida semánticamente que los ejemplos sean coherentes con los schemas.

## TODO para promover a beta

- [ ] Documentar qué librería de Swagger/OpenAPI usa cada servicio.
- [ ] Soporte para archivos `openapi.yaml` externos al código.
- [ ] Validación de ejemplos.
