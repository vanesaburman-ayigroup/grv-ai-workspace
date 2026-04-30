---
name: observability-blueprint
version: v1
maturity: alpha
owner: "[OWNER_NAME]"
category: engineering
related_skills: [architecture-patterns, spring-boot-review, database-design-heavy-table]
related_agents: [grv-architect]
triggers:
  - "qué logueo en X"
  - "cómo instrumentar este servicio"
  - "necesito alertas para Y"
  - "qué métricas expongo"
  - "cómo configuro Sentry"
  - "observabilidad del servicio"
---

# Skill: observability-blueprint

## Propósito

Definir qué loguear, qué métricas exponer y qué alertas configurar para un servicio GRV nuevo o existente. Aplicado a la stack real: Sentry + Microsoft Clarity + Micrometer (Spring Boot).

La observabilidad no es "loguear todo" — es loguear lo que se necesita para diagnosticar problemas en producción sin exponer PII.

## Cuándo usarme

- Al crear un servicio nuevo: definir la instrumentación desde el arranque.
- Al agregar una feature con nueva lógica de negocio crítica.
- Cuando hay un incident y se descubre que "no había logs suficientes".
- Para auditar un servicio existente que tiene observabilidad pobre.

## Cuándo NO usarme

- Para debuggear un problema puntual en desarrollo → usá logs temporales que SE ELIMINAN antes del MR.
- Para instrumentación de performance de BD → eso es `database-design-heavy-table`.

## Reglas de logging

### Formato obligatorio — JSON estructurado

Todos los logs deben ser JSON estructurado. Campos mínimos:

```json
{
  "timestamp": "2024-01-15T10:30:00.000Z",
  "level": "INFO",
  "service": "ws-siniestralidad",
  "traceId": "abc123",
  "spanId": "def456",
  "message": "Prestación aprobada",
  "siniestroId": 12345,
  "prestacionId": 67890
}
```

**No incluir nunca** (datos PII — ver `context/sensitive-tables.yaml`):
- DNI / CUIL / CUIT del afiliado
- Nombre, apellido, dirección
- Historia clínica / diagnóstico
- Datos bancarios

Frente a duda sobre si un campo es PII: no loguearlo. Usar IDs (siniestroId, afiliado_id) que permitan lookup sin exponer datos.

### Cuándo usar cada nivel

| Nivel | Cuándo |
|---|---|
| `ERROR` | Excepción no esperada, operación crítica que falló, integración externa caída |
| `WARN` | Operación completada pero con degradación (fallback activado, retry necesario, dato faltante no crítico) |
| `INFO` | Inicio/fin de operaciones de negocio importantes (prestación aprobada, siniestro cerrado, archivo SRT enviado) |
| `DEBUG` | Solo en desarrollo. **Nunca en producción** |

### Patrón MDC en Spring Boot

```java
MDC.put("siniestroId", String.valueOf(siniestro.getId()));
MDC.put("traceId", request.getHeader("X-Trace-Id"));
try {
    // lógica de negocio
} finally {
    MDC.clear();
}
```

## Métricas Micrometer

### Métricas automáticas (Spring Boot Actuator)

Spring Boot exporta automáticamente:
- `http_server_requests_seconds` — latencia por endpoint
- `hikaricp_connections_active` — pool de conexiones BD
- `jvm_memory_used_bytes` — memoria JVM

Activar en `application.yml`:
```yaml
management:
  endpoints:
    web:
      exposure:
        include: health,metrics,prometheus
  metrics:
    export:
      prometheus:
        enabled: true
```

### Métricas custom recomendadas

```java
// Contador de eventos de negocio
Counter.builder("grv.siniestros.cerrados")
    .tag("tipo", siniestro.getTipo().name())
    .register(meterRegistry)
    .increment();

// Tiempo de procesamiento de operación crítica
Timer.builder("grv.srt.archivo.generacion")
    .register(meterRegistry)
    .record(() -> generarArchivoSRT(siniestros));

// Gauge de cola pendiente
Gauge.builder("grv.prestaciones.pendientes", prestacionService, s -> s.countPendientes())
    .register(meterRegistry);
```

## Sentry

### Qué capturar

```java
// Error no esperado con contexto de negocio
try {
    procesarPrestacion(prestacion);
} catch (Exception e) {
    Sentry.withScope(scope -> {
        scope.setTag("servicio", "ws-siniestralidad");
        scope.setExtra("siniestroId", prestacion.getSiniestroId());
        // NO incluir datos PII en el scope
        Sentry.captureException(e);
    });
    throw e;
}
```

### Qué NO capturar en Sentry

- Excepciones de negocio esperadas (`SiniestroNoEncontradoException` → es un 404, no un error)
- Excepciones de validación de input (`MethodArgumentNotValidException`)
- Errores de autenticación (401/403)

**Filtrar en la configuración de Sentry**:
```yaml
sentry:
  ignored-exceptions-for-type: "com.grv.exception.RecursoNoEncontradoException,jakarta.validation.ConstraintViolationException"
```

## Microsoft Clarity (Frontend)

- Clarity está para UX: sessiones grabadas, heatmaps.
- No usar para métricas de negocio (para eso usar el backend).
- Verificar que los campos de formulario sensibles estén enmascarados.

## SLOs sugeridos por tipo de servicio

| Tipo | Latencia P99 | Error Rate | Disponibilidad |
|---|---|---|---|
| API sincrónica (usuario espera) | < 1s | < 1% | 99.5% |
| Job batch / cron | < 5min por ejecución | < 0.1% | 99% |
| Integración SRT (envío de archivo) | < 30s | 0% (crítico) | 99.9% |
| Integración externa (SATApp, SAP) | < 3s con circuit breaker | < 5% | 95% |

## Output del skill

Dado un servicio, producir un bloque markdown con:

```markdown
## Observability Blueprint — <nombre del servicio>

### Logs
- Campos MDC: siniestroId, usuarioId, traceId
- Eventos INFO: [lista de qué se loguea a nivel INFO]
- Campos PII a excluir: DNI, nombre, diagnóstico

### Métricas
- Automáticas: http_server_requests, hikaricp (activar actuator)
- Custom: [lista de métricas de negocio recomendadas]

### Sentry
- Capturar: [tipos de excepción]
- Ignorar: [tipos de excepción esperadas]

### SLOs
- Latencia P99: < Xs
- Error rate: < X%

### Alertas sugeridas
- Error rate > 1% en los últimos 5 minutos
- Latencia P99 > 2s
- Pool de conexiones activas > 80%
```

## Límites

- Alpha: los valores de SLO son sugerencias — deben ajustarse con datos reales de cada servicio.
- No configura Sentry ni Grafana automáticamente: produce el blueprint, el dev lo implementa.
- Micrometer + Prometheus + Grafana: supone que la infraestructura GRV los soporta (verificar con ops).

## TODO para promover a beta

- [ ] Confirmar que Prometheus/Grafana están disponibles en la infra GRV
- [ ] Blueprint aplicado a 2 servicios reales, con SLOs acordados con el equipo
- [ ] Agregar a `context/microservices.yaml` los SLOs definidos por servicio
