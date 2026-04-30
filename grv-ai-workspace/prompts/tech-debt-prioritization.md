# Prompt: Priorización de Deuda Técnica

Usá este prompt para armar la tabla P0/P1/P2 de deuda técnica de un servicio y llegar al planning con una recomendación concreta.

---

## Scope

**Servicio o componente**: ___  
**Período de análisis**: ___  
**Contexto**: <!-- ej: "Antes del planning del Q2", "Evaluando si el servicio está listo para una feature grande" -->

---

## 1. Inventario (llenar con lo encontrado)

Para cada item de deuda encontrado, completar una fila:

| # | Título | Categoría | Esfuerzo | Notas |
|---|---|---|---|---|
| | | código/seguridad/performance/tests/operativa/contrato-api | S/M/L | |

> Para el detalle de cada item, usar `templates/tech-debt-entry.md`

---

## 2. Priorización

Aplicar los criterios del workspace:

| Prioridad | Criterio |
|---|---|
| **P0** | Bloquea feature nueva, tiene riesgo de incidente en prod, o es requisito de compliance |
| **P1** | Impacta la velocidad del equipo (tarda el doble por esto), genera bugs periódicos |
| **P2** | Mejora de calidad, no bloquea nada a corto plazo |

**Items P0** (deben resolverse pronto):

| Item | Justificación P0 | Esfuerzo |
|---|---|---|
| | | |

**Items P1** (entrar en los próximos 2-3 sprints):

| Item | Justificación P1 | Esfuerzo |
|---|---|---|
| | | |

**Items P2** (backlog de mejora continua):

| Item | Justificación P2 | Esfuerzo |
|---|---|---|
| | | |

---

## 3. Recomendación para el próximo sprint

**¿Qué items entran en el sprint?** (regla del 20% del sprint para deuda técnica)

| Item | Prioridad | Esfuerzo | Owner sugerido |
|---|---|---|---|
| | | | |

**¿Qué queda para el backlog?**

| Item | Cuándo revisarlo |
|---|---|
| | |

---

## 4. Señales de alarma para el tech lead

<!-- Completar si hay items que requieren decisión fuera del sprint normal -->

- [ ] Hay P0 items que bloquean features planificadas para este quarter
- [ ] Hay deuda de seguridad con CVEs activos
- [ ] La deuda acumulada en `___` es tan alta que convendría una semana de "sprint técnico" dedicado
- [ ] Hay items que requieren coordinación con otro equipo

---

## 5. Próximos pasos

- [ ] Validar la priorización con el equipo en el planning
- [ ] Crear tickets en Jira para los P0/P1 sin ticket
- [ ] Comunicar al PO el impacto de la deuda P0 en las features planificadas
- [ ] Revisar este inventario en el próximo quarter
