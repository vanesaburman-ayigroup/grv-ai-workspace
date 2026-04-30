---
name: architecture-patterns
version: v1
maturity: alpha
owner: "[OWNER_NAME]"
category: engineering
related_skills: [adr-helper, observability-blueprint, api-design-review, database-design-heavy-table, c4-diagrams]
related_agents: [grv-architect]
triggers:
  - "qué patrón uso para X"
  - "cómo sincronizan X e Y"
  - "necesito garantía de entrega"
  - "outbox"
  - "saga"
  - "circuit breaker"
  - "cómo evito el acoplamiento entre servicios"
---

# Skill: architecture-patterns

## Propósito

Aplicar patrones de arquitectura distribuida al stack GRV específico. No es teoría genérica: cada patrón se explica con el contexto real (Spring Boot + MariaDB + SQS + servicios conocidos), con las trade-offs que importan en este sistema.

## Cuándo usarme

- Cuando hay que sincronizar datos entre dos servicios y no está claro cómo.
- Cuando un servicio falla y hay que decidir cómo manejarlo (retry, circuit breaker, fallback).
- Cuando se necesita garantía de que un mensaje/evento se entrega aunque haya falla.
- Cuando hay debate sobre si usar llamada REST directa vs mensajería vs event sourcing.

## Cuándo NO usarme

- Para decidir el diseño de un endpoint específico → usá `api-design-review`.
- Para cambios en tablas heavy → usá `database-design-heavy-table`.
- Para documentar la decisión → usá `adr-helper` después de decidir el patrón.

## Patrones disponibles

### Outbox Pattern

**Cuándo**: necesitás garantía de entrega de un mensaje a SQS (o cualquier broker) junto con una transacción de BD. Sin outbox, si la BD commitea y SQS falla, el mensaje se pierde.

**Cómo funciona en GRV**:
1. En la misma transacción que el cambio de dominio, escribís un registro en la tabla `outbox_events` (o similar).
2. Un job/poller (puede ser Spring `@Scheduled`) lee los eventos pendientes y los envía a SQS.
3. Si el envío falla, reintenta. Si tiene éxito, marca el evento como procesado.

**Trade-offs**:
- ✅ Garantía de "at-least-once": nunca se pierde
- ✅ Sin 2PC / distributed transactions
- ⚠️ Introduce latencia (el poller no es inmediato)
- ⚠️ El consumer debe ser idempotente (puede recibir el mismo evento dos veces)

**En GRV**: ya existe en algunos servicios críticos. Antes de implementar uno nuevo, verificar en `context/microservices.yaml` si hay implementación de referencia.

### Circuit Breaker

**Cuándo**: un servicio llama a otro (FeignClient, RestTemplate) y el servicio destino puede fallar. Sin circuit breaker, las fallas en cascada pueden tumbar el servicio origen.

**En Spring Boot**:
```java
// Con Resilience4j (recomendado)
@CircuitBreaker(name = "satapp-client", fallbackMethod = "fallbackGetEstado")
public EstadoResponse getEstado(Long siniestroId) {
    return satappClient.getEstado(siniestroId);
}

private EstadoResponse fallbackGetEstado(Long siniestroId, Exception ex) {
    log.warn("SATApp no disponible para siniestro {}, usando fallback", siniestroId);
    return EstadoResponse.noDisponible();
}
```

**Trade-offs**:
- ✅ Evita fallas en cascada
- ✅ Permite degradación controlada
- ⚠️ El fallback debe ser útil, no solo `return null`
- ⚠️ Configuración de umbrales requiere ajuste en producción

**En GRV**: usar en todas las llamadas a SATApp, SAP, Moovear. Verificar `context/integrations.yaml` para la lista de integraciones externas.

### Retry / Backoff

**Cuándo**: operación que puede fallar transitoriamente (red, BD momentáneamente no disponible).

**Con Spring Retry**:
```java
@Retryable(
    retryFor = {TransientDataAccessException.class},
    maxAttempts = 3,
    backoff = @Backoff(delay = 1000, multiplier = 2)
)
public void procesarPrestacion(Long prestacionId) { ... }
```

**Trade-offs**:
- ✅ Resuelve fallas transitorias sin intervención
- ⚠️ No usar para errores no transitorios (4xx de negocio)
- ⚠️ Con backoff exponencial puede demorar la respuesta al usuario: usar en jobs, no en requests síncronos

### Saga (orquestación vs coreografía)

**Cuándo**: una operación de negocio abarca múltiples servicios y necesita consistencia eventual + rollback coordinado.

**Orquestación** (recomendado para GRV):
- Un orquestador central conoce el flujo y coordina los pasos.
- Más fácil de entender y debuggear.
- Más acoplamiento en el orquestador.

**Coreografía**:
- Cada servicio reacciona a eventos de los demás.
- Más desacoplado, más difícil de seguir el flujo completo.

**En GRV**: preferir orquestación cuando el flujo tiene ≤5 pasos. Para flujos complejos o de larga duración, evaluar coreografía + outbox.

### CQRS

**Cuándo**: una entidad tiene muchas lecturas complejas y escrituras frecuentes que degradan la performance. Separar el modelo de lectura del de escritura.

**En GRV**: solo considerar para `siniestros` si hay evidencia de que las lecturas complejas impactan las escrituras. La complejidad que agrega CQRS no justifica el uso especulativo.

### Dual Write / Shadow Table

Para cambios en tablas heavy → ver `database-design-heavy-table`.

## Flujo de uso

1. Describir el problema de integración/resiliencia.
2. El skill identifica el patrón más apropiado con justificación.
3. Da el diseño concreto para el stack GRV (qué tabla, qué clase, qué anotación).
4. Sugiere abrir un ADR con `adr-helper` si es una decisión transversal.

## Límites

- Alpha: los ejemplos de código son orientativos. Verificar las versiones exactas de Resilience4j / Spring Retry en el pom.xml del servicio.
- No decide por el equipo: presenta las trade-offs para que el equipo decida.
- No valida si el patrón ya está implementado en el servicio → eso requiere leer el código.

## TODO para promover a beta

- [ ] Ejemplos reales de cada patrón tomados de servicios GRV existentes
- [ ] Agregar a `context/microservices.yaml` qué servicios ya usan outbox, circuit breaker, retry
- [ ] Caso de estudio documentado: problema de sincronización resuelto con outbox
