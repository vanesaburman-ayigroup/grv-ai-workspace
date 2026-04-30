# Tech Debt Entry

**Título**: <!-- nombre corto y descriptivo del item de deuda -->  
**Fecha de identificación**: <!-- YYYY-MM-DD -->  
**Identificado por**: <!-- nombre -->

---

## Clasificación

| Campo | Valor |
|---|---|
| **Categoría** | código / seguridad / performance / tests / operativa / contrato-api |
| **Servicio afectado** | <!-- nombre del servicio o "plataforma" --> |
| **Prioridad** | P0 / P1 / P2 |
| **Esfuerzo estimado** | S (1-2 días) / M (1 semana) / L (>1 semana) |

---

## Descripción del problema

<!-- Describir el problema técnico específico. Ser concreto: qué archivo, qué clase, qué patrón.
Ejemplo: "El método `calcularILT()` en `PrestacionService.java` tiene 3 casos de N+1 query 
porque itera sobre una lista de prestaciones y llama `repository.findById()` por cada una." -->

---

## Impacto actual

<!-- Qué consecuencias tiene este problema hoy:
- Performance degradada
- Bugs periódicos
- Velocidad del equipo reducida
- Riesgo de seguridad
- Lentitud en el deploy -->

---

## Disparador

<!-- Qué evento haría urgente atacar esta deuda aunque hoy no lo sea:
- "Cuando la tabla siniestros supere 10M de filas, el N+1 tirará timeouts"
- "Al next spring boot upgrade, la API deprecada se romperá"
- "Si hay un audit de seguridad, este punto saldrá como finding" -->

---

## Solución propuesta

<!-- Descripción breve de cómo se resolvería. No tiene que ser el diseño final,
solo suficiente para estimar el esfuerzo. -->

---

## Criterio de "done"

<!-- Cómo sabemos que esta deuda está resuelta:
- Tests que antes fallaban ahora pasan
- Métricas de performance mejoraron en X%
- El patrón legacy fue reemplazado en todos los usos -->

---

## Owner sugerido

<!-- Quién debería liderar esta tarea (por conocimiento del código o del dominio) -->

---

## Links relacionados

<!-- Tickets de Jira, ADRs, PRs relacionados -->
