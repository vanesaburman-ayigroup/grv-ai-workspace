# Prompt: Comparación de Alternativas Arquitectónicas

Usá este prompt cuando necesitás evaluar 2-3 opciones para una decisión técnica antes de elegir una.

---

## Contexto del problema

**¿Qué problema resuelve esta decisión?**
<!-- Describir el problema de negocio o técnico que requiere la decisión. -->

**¿Cuáles son las restricciones no negociables?**
<!-- Ej: "no podemos agregar nuevas dependencias de infraestructura", "tiene que estar listo en 2 sprints", "no podemos tener downtime" -->

**¿Qué servicios están involucrados?**
<!-- Ver context/microservices.yaml -->

**¿Cuándo tiene que estar resuelto?**
<!-- Fecha o milestone -->

---

## Alternativas a comparar

### Alternativa A: [nombre]

**Descripción**: <!-- qué es y cómo funciona en este contexto -->

| Dimensión | Evaluación |
|---|---|
| Complejidad de implementación | Alta / Media / Baja |
| Complejidad operativa (mantenimiento) | Alta / Media / Baja |
| Tiempo de implementación | <!-- estimación --> |
| Reversibilidad | Fácil / Difícil / Irreversible |
| Riesgo de introducir bugs | Alto / Medio / Bajo |

**Pros**:
-
-

**Contras / trade-offs**:
-
-

---

### Alternativa B: [nombre]

**Descripción**: <!-- qué es y cómo funciona en este contexto -->

| Dimensión | Evaluación |
|---|---|
| Complejidad de implementación | Alta / Media / Baja |
| Complejidad operativa (mantenimiento) | Alta / Media / Baja |
| Tiempo de implementación | <!-- estimación --> |
| Reversibilidad | Fácil / Difícil / Irreversible |
| Riesgo de introducir bugs | Alto / Medio / Bajo |

**Pros**:
-
-

**Contras / trade-offs**:
-
-

---

### Alternativa C (opcional): [nombre]

<!-- Repetir la estructura de A y B si hay una tercera opción -->

---

## Criterios de decisión del equipo GRV

Ponderación para este contexto (ajustar si algún criterio no aplica):

| Criterio | Peso | A | B | C |
|---|---|---|---|---|
| Velocidad de entrega | Alto | | | |
| Mantenibilidad a largo plazo | Alto | | | |
| Riesgo operativo en producción | Alto | | | |
| Complejidad para el equipo actual | Medio | | | |
| Consistencia con decisiones previas | Medio | | | |

---

## Recomendación

**Se recomienda**: Alternativa [X]

**Justificación**: <!-- Por qué esta alternativa gana considerando los criterios del equipo. Ser específico con los criterios que más pesaron. -->

**Condición de revisión**: <!-- Cuándo volvería a evaluarse esta decisión. Ej: "Si el volumen de siniestros supera 10M, revisar si CQRS vale la pena." -->

---

## Consecuencias de elegir mal

**Si elegimos A y era B la correcta**: <!-- qué pasaría -->

**Si elegimos B y era A la correcta**: <!-- qué pasaría -->

---

## Próximos pasos

- [ ] Compartir este análisis con el equipo para feedback
- [ ] Documentar la decisión como ADR con `adr-helper` (especialmente si es transversal)
- [ ] Definir el criterio de "done" para la implementación de la alternativa elegida
