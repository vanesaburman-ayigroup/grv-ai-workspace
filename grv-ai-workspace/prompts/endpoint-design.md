# Prompt: Diseño guiado de endpoint nuevo

Usá este prompt antes de escribir una línea de código para un endpoint nuevo. El objetivo es tomar todas las decisiones de diseño con la cabeza fría, no en medio de la implementación.

---

## 1. Caso de uso

**¿Qué resuelve este endpoint?**
<!-- Descripción del caso de uso desde la perspectiva del consumer. Ej: "Permite al frontend obtener la lista de prestaciones de un siniestro para mostrarlas en el detalle." -->

**¿Quién lo consume?**
- [ ] Frontend (app-frontend / un MFE específico: ___)
- [ ] Otro microservicio: ___
- [ ] Integración externa: ___
- [ ] Job interno

**¿Hay urgencia? ¿Cuándo tiene que estar listo?**

---

## 2. Decisiones de diseño

### Método HTTP

| Opción | Cuándo usar |
|---|---|
| `GET` | Lectura. Idempotente. Sin body. |
| `POST` | Creación. No idempotente (default). |
| `PUT` | Reemplazo completo del recurso. Debe ser idempotente. |
| `PATCH` | Actualización parcial. |
| `DELETE` | Eliminación. Idempotente. |

**Método elegido**: `___`  
**Justificación**: <!-- por qué -->

---

### Path

**Convenciones GRV**:
- Prefijo `/v1/` obligatorio
- Sustantivos en plural: `/v1/siniestros/`, `/v1/prestaciones/`
- Kebab-case para palabras compuestas: `/v1/siniestros-laborales/`
- Jerarquía refleja la relación: `/v1/siniestros/{siniestroId}/prestaciones`

**Path propuesto**: `___`

---

### Request

**¿Lleva body?** Sí / No (GET y DELETE no llevan body)

**Campos del body** (si aplica):

| Campo | Tipo | Requerido | Descripción |
|---|---|---|---|
| | | | |

**Query params** (snake_case):

| Param | Tipo | Requerido | Descripción |
|---|---|---|---|
| | | | |

---

### Response exitosa

**Status code**: 200 (lectura) / 201 (creación) / 204 (sin body)

**Campos del response**:

| Campo | Tipo | Descripción |
|---|---|---|
| | | |

**¿Necesita paginación?** Sí (si puede devolver más de ~50 elementos) / No

Si sí, estructura estándar:
```json
{
  "content": [...],
  "totalElements": 150,
  "totalPages": 8,
  "page": 0,
  "size": 20
}
```

---

### Respuestas de error

| Status | Cuándo |
|---|---|
| 400 | Validación de input fallida |
| 401 | No autenticado |
| 403 | Sin permisos |
| 404 | Recurso no encontrado |
| 409 | Conflicto (ej: ya existe) |
| 500 | Error interno |

---

## 3. Checklist de diseño

```
□ Método HTTP correcto para la operación
□ Path con prefijo /v1/ y naming correcto
□ Query params en snake_case
□ JSON body en camelCase
□ ¿Es idempotente? PUT y DELETE siempre lo son.
□ ¿Hay paginación si devuelve listas?
□ ¿Necesita autenticación? ¿Qué rol?
□ ¿Es un breaking change respecto a versión actual?
□ ¿Qué consumers se ven afectados? (ver context/microservices.yaml)
□ ¿El endpoint necesita idempotency key para evitar duplicados?
```

---

## 4. Output en formato OpenAPI (fragmento)

<!-- Usar templates/openapi-skeleton.yaml como referencia para estructurar el fragmento -->

```yaml
/v1/RECURSO:
  METHOD:
    tags: [TAG]
    operationId: nombreOperacion
    summary: Descripción breve
    # ...completar con los datos de las secciones anteriores
```

---

## 5. Próximos pasos

- [ ] Revisar con `api-design-review` si hay dudas sobre el diseño
- [ ] Agregar al `openapi.yaml` del servicio con `openapi-from-scratch` (o actualizar el existente)
- [ ] Validar con `openapi-validator`
- [ ] Implementar y cubrir con tests (`unit-test-author` + `functional-test-author`)
