---
name: tech-debt-audit
version: v1
maturity: alpha
owner: "[OWNER_NAME]"
category: processes
related_skills: [release-readiness, cross-team-impact, grv-bugs-conocidos, mariadb-migration-review]
related_agents: [grv-tech-lead]
triggers:
  - "qué deuda tiene X"
  - "cuánto tech debt tenemos"
  - "priorizá qué limpiar primero"
  - "inventario de deuda técnica"
  - "qué TODOs hay en el código"
---

# Skill: tech-debt-audit

## Propósito

Inventariar y priorizar la deuda técnica de un servicio o de la plataforma GRV. El output no es una lista de quejas: es una tabla priorizada que el tech lead puede llevar directamente al planning.

## Cuándo usarme

- Antes del planning de un quarter para decidir qué deuda atacar.
- Cuando hay síntomas de deuda acumulada (lentitud de features, bugs frecuentes, deploys riesgosos).
- Al evaluar si un servicio está listo para crecer o necesita refactor primero.
- Cuando hay que priorizar entre tech debt y features nuevas.

## Cuándo NO usarme

- Para un bug específico → usá `grv-bugs-conocidos`.
- Para decidir si un servicio está listo para deployar → usá `release-readiness`.

## Fuentes de insumo

El skill busca deuda en:

1. **TODOs y FIXMEs en el código** (con y sin ticket asociado)
2. **Dependencias desactualizadas** (`pom.xml`, `package.json`)
3. **Deprecations**: APIs de Spring/Java deprecadas, `@Deprecated` en el propio código
4. **Patterns legacy GRV**: tablas MyISAM, código `bug-booltosn-null`, queries N+1, código sin tests
5. **Bugs conocidos abiertos** (`context/known-bugs.yaml`)
6. **Complejidad ciclomática alta**: clases de más de 500 líneas, métodos de más de 50 líneas (proxy de deuda)

## Criterios de priorización

| Prioridad | Criterio |
|---|---|
| **P0** | Bloquea feature nueva, tiene riesgo de incidente en prod, o es requisito de compliance |
| **P1** | Impacta la velocidad del equipo (tarda el doble por esto), genera bugs periódicos |
| **P2** | Mejora de calidad, no bloquea nada a corto plazo |

## Categorías de deuda

- **código**: coupling alto, complejidad, patrones obsoletos, duplicación
- **seguridad**: dependencias con CVEs, validación de input insuficiente, logs con PII
- **performance**: N+1 queries, queries sin índice, caches ineficientes
- **tests**: cobertura baja en rutas críticas, tests que no prueban nada útil
- **operativa**: configuración manual, deploy frágil, sin runbook, observabilidad insuficiente
- **contrato-api**: endpoints sin versionar, sin documentación openapi, breaking changes silenciosas

## Flujo

### Paso 1 — Definir el alcance

¿Auditoría de 1 servicio específico o de la plataforma completa?
Para la plataforma completa, recorrer `context/microservices.yaml` y hacer el inventario a nivel servicio primero.

### Paso 2 — Buscar deuda por fuente

Recorrer las fuentes de insumo para el alcance definido.

### Paso 3 — Categorizar y priorizar

Para cada item de deuda, asignar: categoría, prioridad (P0/P1/P2), esfuerzo (S = 1-2 días / M = 1 semana / L = más de 1 semana), disparador (qué haría que este item sea urgente aunque hoy no lo sea).

Usar `templates/tech-debt-entry.md` para cada item.

### Paso 4 — Tabla resumen

Entregar tabla ordenada por prioridad.

### Paso 5 — Recomendación de sprint

Sugerir qué 2-3 items de P0/P1 podrían entrar en el próximo sprint como parte del "20% de deuda técnica".

## Output

```
TECH DEBT AUDIT — <servicio / plataforma>
==========================================
Fecha: YYYY-MM-DD
Scope: <servicio o 'plataforma completa'>

RESUMEN
  P0: N items
  P1: N items
  P2: N items

TABLA DE DEUDA

| # | Título | Categoría | Servicio | Prioridad | Esfuerzo | Disparador |
|---|---|---|---|---|---|---|
| 1 | Queries N+1 en PrestacionRepository | performance | ws-prestaciones | P0 | M | Cualquier feature que aumente el volumen de prestaciones |
| 2 | Tabla siniestros_historial en MyISAM | operativa | ws-siniestralidad | P1 | L | Al necesitar transacciones sobre esa tabla |
| 3 | TODO: extraer validación a PrestacionValidator | código | ws-prestaciones | P2 | S | Al modificar la lógica de validación |

RECOMENDACIÓN PARA EL PRÓXIMO SPRINT
  Incluir items 1 y 3 (P0 + P2 de bajo esfuerzo): 1 M + 1 S = ~1.5 semanas de trabajo.

ITEMS SIN TICKET ASIGNADO (requieren creación)
  - Item 2: abrir ticket en Jira con estimación L
  - Item 3: agregar a backlog de tech debt
```

## Límites

- Alpha: la búsqueda de TODOs/FIXMEs requiere acceso al código fuente. Sin acceso, el inventario es parcial.
- Los criterios P0/P1/P2 son sugerencias — el tech lead tiene el contexto final para decidir.
- No evalúa deuda de negocio (features no implementadas, specs ambiguos).

## TODO para promover a beta

- [ ] Producir 1 auditoría real de un servicio GRV con el equipo
- [ ] Acordar con el tech lead el % de tiempo dedicado a tech debt por sprint
- [ ] Integrar con `context/known-bugs.yaml` para cross-reference automático
