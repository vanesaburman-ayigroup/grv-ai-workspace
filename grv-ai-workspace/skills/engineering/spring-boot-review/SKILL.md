---
name: spring-boot-review
version: v1
maturity: beta
owner: "[OWNER_NAME]"
category: engineering
related_skills: [grv-arquitectura-plataforma, grv-bugs-conocidos, mariadb-migration-review]
related_agents: [grv-reviewer]
triggers:
  - "usuario pide revisar código Java/Spring Boot"
  - "aparece cambio en src/main/java/ en el diff"
  - "usuario dice 'revisá este controller/service/repository'"
---

# Skill: spring-boot-review

## Propósito

Hacer code review de cambios en servicios Java/Spring Boot de la plataforma
de GRV, con foco en los patrones que sabemos que fallaron antes. No es un
linter genérico — está calibrado a los bugs y decisiones específicas del
proyecto.

## Fuente de verdad

- `context/microservices.yaml` — servicio al que pertenece el código.
- `context/known-bugs.yaml` — patterns históricos de falla.
- `context/glossary.yaml` — términos de dominio.

## Cuándo usarme

- Review previo a crear un MR.
- Review de un MR ajeno que me tocó como reviewer.
- Validación de una refactorización no trivial.
- Detección de anti-patterns en código legacy que voy a tocar.

## Cuándo NO usarme

- Para cuestiones puramente de frontend (usar `react-mfe-review`).
- Para revisar migraciones SQL (usar `mariadb-migration-review`).
- Para tests (usar `functional-test-author`).

## Información que pido antes de revisar

1. **El código** (el diff completo, no solo un snippet).
2. **Servicio al que pertenece** (para consultar `microservices.yaml`).
3. **Qué resuelve** el cambio (ticket, descripción del MR, lo que sea).
4. **Si es bugfix**: el reporte de bug.
5. **Si es feature**: los criterios de aceptación.

Sin contexto de negocio, solo puedo evaluar aspectos técnicos; sin
criterios de aceptación, no puedo evaluar si el código hace lo correcto.

## Checklist

### 1. Persistencia y transacciones

- [ ] **`@Transactional`**: métodos que hacen múltiples writes tienen transacción explícita. Nivel correcto (read-only para lecturas).
- [ ] **Rollback**: las excepciones que deberían revertir están en `rollbackFor` o son unchecked.
- [ ] **Propagation**: cuidado con `REQUIRES_NEW` innecesario (costo de conexión).
- [ ] **Lazy loading fuera de transacción**: causa `LazyInitializationException`. Revisar joins o DTOs.
- [ ] **N+1 queries**: revisar bucles que acceden a relaciones lazy.

### 2. Hikari / conexiones

- [ ] **Queries lentas sin timeout**: agregar `@QueryHints` o timeout explícito.
- [ ] **Conexión suelta**: todo recurso de BD debe cerrarse (try-with-resources). Spring Data lo maneja, pero `EntityManager` manual no.
- [ ] **Pool sizing**: ver `bug-hikari-pool-exhaustion` en `known-bugs.yaml`. Servicios chicos no deben reservar pools grandes.

### 3. Retry y error handling

- [ ] **`@Recover` silencioso**: ⚠️ patrón conocido. Ver `bug-logistica-etiqueta-asignado`. Todo `@Recover` debe:
  - Loguear con contexto completo.
  - Marcar el registro como inconsistente o emitir evento de falla.
  - No retornar silenciosamente como si todo hubiera funcionado.
- [ ] **Excepciones tragadas**: `catch (Exception e) { /* nada */ }` es bandera roja. `catch (Exception e) { log.error(...) }` sin re-throw también, dependiendo del contexto.
- [ ] **Errores de negocio vs errores técnicos**: distinguir. No mezclar `IllegalArgumentException` con `DataAccessException`.

### 4. Patrones específicos conocidos

- [ ] **`boolToSN` y funciones utilitarias**: ⚠️ ver `bug-booltosn-null`. Funciones que convierten null a un valor default "seguro" mienten sobre la ausencia de dato. Revisar caso por caso.
- [ ] **Funciones de formato de archivo posicional**: alineación, padding, longitud. Ver `bug-campo-alineacion`. Revisar los tests (si tocaste la función, probablemente los tests deberían fallar).
- [ ] **Cálculos de fecha con límites**: ver `bug-antiguedad-cast`. CAST de fechas puede fallar en rangos extremos.
- [ ] **Concurrencia sobre `auditoria_facturacion_log`**: ver `bug-lock-wait-auditoria`. Cualquier escritura nueva sobre esta tabla requiere análisis.

### 5. Auditoría y trazabilidad

- [ ] **Audit log en paths críticos**: operaciones sobre denuncias, siniestros, facturación deben quedar logueadas con `quién/cuándo/qué`.
- [ ] **Logs estructurados**: preferir logs con contexto (`MDC`, campos nombrados) sobre strings concatenados.
- [ ] **No loguear PII sensible**: DNI, dirección, historia clínica no van al log. Usar IDs internos.

### 6. API y contratos

- [ ] **DTOs separados de entidades JPA**: no exponer la entidad directamente.
- [ ] **Validación de input**: `@Valid`, `@NotNull`, `@Size`, etc.
- [ ] **HTTP codes correctos**: 400 vs 404 vs 422 vs 500.
- [ ] **Respuestas deterministas**: mismo input, mismo output.
- [ ] **Versionado de API si aplica**.

### 7. Nullability

- [ ] **Retornos que pueden ser null**: marcados con `@Nullable` u `Optional<>`.
- [ ] **Parámetros que no pueden ser null**: marcados con `@NonNull` y validados.

### 8. Testing (señal, no review completo)

- [ ] **¿Hay tests?** Si el cambio es no trivial y no tiene tests, alertar.
- [ ] **¿Los tests tocan este cambio?** Si agregaste una rama y ningún test la cubre, alertar.
- El review de calidad de tests se hace con `functional-test-author`.

### 9. Dependencias

- [ ] **¿Agrega dependencia nueva?** Evaluar costo de mantenimiento. La plataforma tiene 30+ servicios; cada dependencia nueva se multiplica.
- [ ] **¿Versión de librería actualizada?** No introducir versión conocida con CVEs.

### 10. Microservicio como ciudadano

- [ ] **Tiempo de startup**: no introducir `@Bean` costosos al arranque sin necesidad.
- [ ] **Graceful shutdown**: si procesa mensajes, debe drenar antes de bajar.
- [ ] **Idempotencia en operaciones expuestas a reintentos** (HTTP retries, SQS visibility timeout, etc).

### 11. Observabilidad

- [ ] **Logs JSON estructurados**: no concatenar strings en mensajes de log. Usar `{}` placeholders de SLF4J o MDC fields.
- [ ] **MDC con contexto de negocio**: campos como `siniestroId`, `traceId`, `usuarioId` en el MDC para correlacionar logs.
- [ ] **Niveles de log correctos**: ERROR para excepciones inesperadas, WARN para degradación/fallback, INFO para eventos de negocio. DEBUG solo en desarrollo, no en producción.
- [ ] **Sin PII en logs**: DNI, nombre, domicilio, historia clínica NO van en logs. Usar IDs internos. Ver `context/sensitive-tables.yaml`.
- [ ] **Métricas Micrometer**: si el código expone comportamiento crítico (procesamiento de lotes, colas, operaciones costosas), considerar agregar un `Counter` o `Timer` custom.
- [ ] **Sentry**: excepciones inesperadas deben llegar a Sentry con contexto relevante (sin PII). Excepciones de negocio esperadas (404, 400) no deben ir a Sentry.
- [ ] **Actuator**: verificar que `/actuator/health` y `/actuator/metrics` están habilitados si el servicio es nuevo.

Ver `skills/engineering/observability-blueprint` para el blueprint completo de instrumentación.

## Flujo del skill

1. Pedir código completo + contexto de negocio.
2. Identificar el servicio y consultar `microservices.yaml`.
3. Cruzar con `known-bugs.yaml` buscando patterns similares.
4. Correr el checklist sección por sección, marcando solo los ítems
   relevantes al cambio (no inventar hallazgos donde no los hay).
5. Generar reporte con severidad y acción sugerida por ítem.
6. Si hay dudas sobre intención, preguntar al autor antes de afirmar.

## Output

```
===========================================================
CODE REVIEW — Spring Boot
Servicio: <servicio>
Cambio: <descripción corta>
===========================================================

RESUMEN
  🟢 <cantidad> secciones OK
  🟡 <cantidad> observaciones no-bloqueantes
  🔴 <cantidad> bloqueantes

HALLAZGOS

🔴 BLOQUEANTES
  1. <archivo:línea> — <descripción>
     Por qué bloquea: <...>
     Fix sugerido: <...>
     Relacionado a: <bug conocido | patrón> si aplica

🟡 OBSERVACIONES
  ...

🟢 BUENAS PRÁCTICAS (cosas que funcionan bien y vale la pena destacar)
  ...

PREGUNTAS AL AUTOR
  ...
```

## Ejemplo

**Usuario**: Revisame esto, es una modificación en `WSTurnos.anularTurno`:
```java
public void anularTurno(Long idTurno) {
    try {
        Traslado traslado = findTrasladoProgramado(idTurno);
        if (traslado != null) {
            emailService.enviarCancelacion(traslado);
        }
        turnoRepository.marcarAnulado(idTurno);
    } catch (Exception e) {
        log.error("Error anulando turno {}", idTurno, e);
    }
}
```

**Respuesta**:
```
🔴 BLOQUEANTES

1. `anularTurno` no ejecuta la cancelación del traslado.
   Este es el patrón exacto del bug-logistica-anular-turno documentado
   en known-bugs.yaml: cuando findTrasladoProgramado encuentra un traslado,
   el código solo envía email en lugar de ejecutar la lógica completa
   de cancelación (endpoint desestimar + liberación del slot).

   Fix: agregar la llamada a la cancelación real del traslado antes del email.
   El email es notificación, no sustituto del cambio de estado.

2. Excepción tragada con catch (Exception e).
   El catch loguea pero no propaga. El caller cree que la anulación fue
   exitosa aunque haya fallado la actualización en BD.
   Esto es el mismo patrón que bug-logistica-etiqueta-asignado:
   silenciar errores sin compensar ni propagar.

   Fix: diferenciar:
     - errores de negocio (turno inexistente) → lanzar excepción de negocio
     - errores técnicos (DB down) → propagar o marcar inconsistencia
     - en cualquier caso, no retornar como si hubiera funcionado

🟡 OBSERVACIONES

3. No hay @Transactional. Si emailService.enviarCancelacion() falla,
   el turno queda sin anular. Si turnoRepository.marcarAnulado() falla,
   el email ya se envió. Inconsistencia en ambos sentidos.

   Fix: @Transactional sobre el método (con rollbackFor si es necesario)
   o separar email a un evento post-commit.

4. No hay audit log de la operación. Anular un turno es una operación
   sobre estado de negocio, debería quedar trazado quién/cuándo/por qué.

PREGUNTAS AL AUTOR
  - ¿Cuál es el criterio de aceptación que estás cubriendo con este cambio?
  - ¿El bug-logistica-anular-turno está en tu radar? ¿Es parte del scope?
```

## Límites

- No ejecuta los tests; solo evalúa por lectura.
- No detecta bugs de lógica de negocio que no sean patterns conocidos.
- Un review automatizado no sustituye review humano — es complemento.
