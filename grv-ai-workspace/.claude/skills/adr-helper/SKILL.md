---
name: adr-helper
version: v1
maturity: alpha
owner: "[OWNER_NAME]"
category: engineering
related_skills: [architecture-patterns, workspace-contribution, c4-diagrams, cross-team-impact]
related_agents: [grv-architect]
triggers:
  - "necesito documentar una decisión"
  - "quiero escribir un ADR"
  - "decidimos usar X, documentalo"
  - "architecture decision record"
  - "cómo documento esta decisión técnica"
---

# Skill: adr-helper

## Propósito

Guiar la escritura de un ADR (Architecture Decision Record) completo para una decisión técnica del equipo GRV. Usa el template en `templates/adr-template.md` y lo cruza con el contexto del workspace para identificar servicios afectados y alternativas que quizás no se consideraron.

Un ADR bien escrito evita la discusión circular sobre decisiones ya tomadas y da contexto a quien llega después.

## Cuándo usarme

- Se tomó (o se está tomando) una decisión técnica con consecuencias a mediano/largo plazo.
- Hay debate entre alternativas y se necesita registrar por qué se eligió una.
- Alguien pregunta "¿por qué usamos X en lugar de Y?" y no hay respuesta documentada.
- Se va a adoptar una nueva tecnología, patrón o convención en GRV.

## Cuándo NO usarme

- Para decisiones triviales o fácilmente reversibles (qué nombre darle a una variable, qué librería de utilidades usar).
- Para documentar una decisión ya vieja sin contexto disponible → es mejor dejar esa deuda documentada que inventar el contexto.

## Flujo

### Paso 1 — Entender la decisión

Pedir al usuario:
1. ¿Qué problema se está resolviendo? (contexto, fuerzas que actúan)
2. ¿Qué alternativas se consideraron?
3. ¿Cuál fue la decisión tomada?
4. ¿Cuál es el status? (proposed / accepted / deprecated / superseded)

### Paso 2 — Enriquecer con contexto del workspace

Cruzar con `context/microservices.yaml`: ¿qué servicios se ven afectados por esta decisión?
Cruzar con `context/integrations.yaml`: ¿hay integraciones externas implicadas?
Sugerir alternativas adicionales que el usuario quizás no consideró (basadas en el stack GRV).

### Paso 3 — Completar el ADR

Rellenar el template con:
- **Título**: `NNN-titulo-en-kebab-case.md` (NNN = siguiente número disponible en `docs/adr/`)
- **Contexto**: el problema, las fuerzas que llevan a necesitar la decisión
- **Alternativas consideradas**: tabla o lista con pros/contras de cada una
- **Decisión**: cuál se elige y por qué (criterios de decisión explícitos)
- **Consecuencias**: positivas y negativas (incluyendo lo que se sacrifica)
- **Status**: proposed / accepted
- **Servicios afectados**: lista de servicios de `microservices.yaml` que se ven impactados

### Paso 4 — Sugerir captura en workspace-contribution

Si la decisión define una nueva convención para el equipo, sugerir capturarla via `workspace-contribution` con tipo `architectural-decision`.

## Output

Archivo `docs/adr/NNN-titulo.md` completo, listo para abrir como MR.

```markdown
# ADR NNN: Título de la decisión

**Status**: proposed  
**Date**: YYYY-MM-DD  
**Author**: [nombre]  
**Servicios afectados**: ws-siniestralidad, ws-facturacion

## Contexto

[Descripción del problema y las fuerzas que llevan a la decisión]

## Alternativas consideradas

| Alternativa | Pros | Contras |
|---|---|---|
| Opción A | ... | ... |
| Opción B | ... | ... |

## Decisión

Se elige **Opción A** porque [criterios explícitos].

## Consecuencias

**Positivas**:
- ...

**Negativas / trade-offs**:
- ...

## Referencias

- [links a docs, tickets, conversaciones relevantes]
```

## Ejemplo de uso — GRV

**Usuario**: "Decidimos usar outbox pattern para la sincronización entre ws-siniestralidad y ws-facturacion. Documentalo."

**Respuesta del skill**:
```
Perfecto. Antes de escribir el ADR, necesito:

1. ¿Por qué se descartó hacer la llamada directa REST entre los dos servicios?
2. ¿Consideraron SQS FIFO directamente (sin outbox)? ¿Por qué outbox y no SQS directo?
3. ¿Status es "accepted" o todavía está "proposed"?

Lo que ya sé del contexto del workspace:
- ws-siniestralidad y ws-facturacion aparecen en context/microservices.yaml
- context/known-bugs.yaml tiene un bug relacionado con pérdida de mensajes que podría ser el disparador

Con eso armo el ADR completo.
```

## Límites

- Alpha: el directorio `docs/adr/` puede no existir en el servicio. Recordar crearlo.
- No valida si la decisión es correcta → eso es `architecture-patterns` y `api-design-review`.
- El skill guía la escritura pero el contenido lo aporta el usuario: no inventar contexto ni alternativas.

## TODO para promover a beta

- [ ] Producir 1 ADR real con el equipo y documentarlo en `docs/case-studies/`
- [ ] Verificar que el template `templates/adr-template.md` está alineado con lo que se usa
- [ ] Agregar tipo `architectural-decision` en `workspace-contribution`
