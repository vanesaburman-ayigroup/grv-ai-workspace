---
name: openapi-from-scratch
version: v1
maturity: alpha
owner: "[OWNER_NAME]"
category: engineering
related_skills: [api-doc-sync, openapi-validator, spring-boot-review, api-design-review]
related_agents: [grv-doc-keeper]
triggers:
  - "generame el openapi"
  - "este servicio no tiene swagger"
  - "quiero un openapi.yaml para X"
  - "documentar la API de este servicio"
  - "el servicio no tiene anotaciones swagger"
---

# Skill: openapi-from-scratch

## Propósito

Generar un `openapi.yaml` válido (OpenAPI 3.0) leyendo el código de un servicio Spring Boot que **no tiene Swagger/springdoc anotado**. El resultado es un contrato de API funcional con bloques `# TODO:` explícitos para todo lo que requiere decisión humana (descripciones, ejemplos concretos, esquemas de autenticación, valores de enum).

**No reemplaza** a `api-doc-sync`, que detecta drift entre anotaciones existentes y código. Este skill es para cuando no hay ninguna anotación de partida.

## Cuándo usarme

- El servicio no tiene `springdoc-openapi` ni `swagger-annotations` en el pom.xml.
- Se quiere generar el contrato desde cero para un servicio legacy.
- Se necesita un openapi.yaml como insumo para `openapi-validator`, para mocks con Prism, o para documentación.

## Cuándo NO usarme

- El servicio ya tiene springdoc anotado → usá `api-doc-sync` para detectar drift.
- Se quiere validar un openapi.yaml existente → usá `openapi-validator`.

## Detección de springdoc vs swagger-core

Antes de arrancar, verificar en `pom.xml`:

```xml
<!-- springdoc-openapi (moderno, recomendado) -->
<dependency>
    <groupId>org.springdoc</groupId>
    <artifactId>springdoc-openapi-starter-webmvc-ui</artifactId>
</dependency>

<!-- swagger-core legacy (io.swagger.core.v3) -->
<dependency>
    <groupId>io.swagger.core.v3</groupId>
    <artifactId>swagger-annotations</artifactId>
</dependency>
```

Si ninguno está: el servicio no tiene Swagger → este skill aplica.
Si springdoc está pero sin anotaciones: combinar este skill con `api-doc-sync`.

## Flujo

### Paso 1 — Recibir inputs

Pedir al usuario:
- Nombre del servicio
- Ruta a la carpeta de controllers (ej: `src/main/java/com/grv/wssinestralidad/controller/`)
- ¿Hay autenticación? ¿Bearer JWT, API key, sin auth?
- ¿Hay URL de servidor dev/prod conocida?

### Paso 2 — Leer los controllers

Para cada `@RestController`:
- Extraer el `@RequestMapping` base de la clase
- Para cada método: `@GetMapping`, `@PostMapping`, `@PutMapping`, `@DeleteMapping`, `@PatchMapping`
  - Path completo (base + método)
  - Parámetros: `@PathVariable`, `@RequestParam`, `@RequestBody`
  - Tipo de retorno (para inferir el schema de respuesta)
  - Posibles `@ResponseStatus`

### Paso 3 — Inferir schemas de DTOs

Para cada tipo de request body y response body:
- Leer los campos de la clase Java (nombre, tipo, `@NotNull`, `@Valid`, etc.)
- Mapear tipos Java → tipos OpenAPI: `String` → `string`, `Integer`/`int` → `integer`, `LocalDate` → `string (format: date)`, `LocalDateTime` → `string (format: date-time)`, `Boolean` → `boolean`, `List<X>` → `array (items: $ref X)`
- Agregar `required: [...]` para campos `@NotNull`
- Marcar con `# TODO: agregar description` en cada campo

### Paso 4 — Generar el YAML

Usar `templates/openapi-skeleton.yaml` como estructura base.

Completar:
- `info.title`: nombre del servicio
- `info.version`: `1.0.0` (o la version del pom.xml si se puede inferir)
- `servers`: dev con URL conocida o `http://localhost:8080`, prod con `# TODO:`
- `tags`: uno por controller
- `paths`: uno por endpoint
- `components/schemas`: uno por DTO inferido

Marcar con `# TODO:` obligatorio:
- Cada `description` de endpoint y campo
- Ejemplos de request/response (`example:`)
- Enum values que no se puedan inferir del código
- Esquema de autenticación si no se confirmó

### Paso 5 — Validar con Spectral (si disponible)

```bash
spectral lint openapi.yaml
```

Si Spectral no está instalado: indicar cómo instalarlo e indicar que la validación queda pendiente.

### Paso 6 — Entregar el archivo

Guardar como `openapi.yaml` en la raíz del módulo o en `src/main/resources/` según convención del servicio.

## Output

```yaml
# openapi.yaml generado desde código — GRV
# Servicio: <nombre>
# Generado: <fecha>
# Estado: DRAFT — revisar los TODO antes de publicar
#
# TODOs pendientes: <N>

openapi: 3.0.3
info:
  title: <nombre del servicio>
  # TODO: agregar descripción del servicio
  version: 1.0.0
  # TODO: agregar contacto del equipo owner
servers:
  - url: http://localhost:8080
    description: Dev local
  - url: # TODO: URL de producción
    description: Producción
...
```

Al final, listar todos los `# TODO:` encontrados con su ubicación.

## Ejemplo de inferencia de endpoint

Controller Java:
```java
@RestController
@RequestMapping("/v1/siniestros")
public class SiniestroController {

    @GetMapping("/{siniestroId}/prestaciones")
    public List<PrestacionResponse> getPrestaciones(
        @PathVariable Long siniestroId,
        @RequestParam(required = false) String estado
    ) { ... }
}
```

OpenAPI generado:
```yaml
paths:
  /v1/siniestros/{siniestroId}/prestaciones:
    get:
      tags: [siniestros]
      operationId: getPrestaciones
      # TODO: agregar description del endpoint
      parameters:
        - name: siniestroId
          in: path
          required: true
          schema:
            type: integer
            format: int64
        - name: estado
          in: query
          required: false
          schema:
            type: string
          # TODO: documentar valores posibles de estado
      responses:
        '200':
          description: OK
          content:
            application/json:
              schema:
                type: array
                items:
                  $ref: '#/components/schemas/PrestacionResponse'
```

## Límites

- Alpha: requiere revisión humana de todos los TODOs antes de usar en producción.
- No infiere lógica de negocio: si un campo tiene reglas de validación complejas, las marca como TODO.
- Si el controller usa herencia o traits complejos de Spring, la inferencia puede ser incompleta.
- No genera tests de contrato (Pact): eso queda para Fase 3.

## TODO para promover a beta

- [ ] Probado contra 3 servicios reales GRV sin Swagger
- [ ] Validar que el YAML generado pasa `spectral lint` sin errores
- [ ] Caso de estudio documentado en `docs/case-studies/`
