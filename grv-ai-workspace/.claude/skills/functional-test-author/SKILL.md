---
name: functional-test-author
version: v1
maturity: alpha
owner: "[OWNER_NAME]"
category: engineering
related_skills: [spring-boot-review, react-mfe-review, grv-arquitectura-plataforma]
related_agents: [grv-test-author]
triggers:
  - "usuario pide tests para un método, clase, componente o endpoint"
  - "usuario dice 'escribime tests'"
  - "post-edit hook detecta archivo de test modificado por Claude"
---

# Skill: functional-test-author

## Propósito

Escribir tests que **validan comportamiento contra la fuente de verdad**,
no tests que se adaptan a la implementación para pasar. Este skill existe
porque el problema más caro de los tests generados con IA (y también por
humanos apurados) es que terminan testeando lo que el código *hace* en
lugar de lo que *debería hacer*.

## Principios no negociables

1. **La fuente de verdad no es el código**. Es el ticket, el spec, los
   criterios de aceptación, el documento de diseño, o la transcripción
   de la reunión donde se decidió. **Ante un conflicto, gana la fuente
   de verdad — no el código existente.**

2. **Si un test falla, el bug está en el código o el spec estaba mal
   interpretado**. Nunca se modifica el test para que pase. Se corrige
   el código, o se valida la interpretación con el autor del spec.

3. **Los tests expresan intención**, no implementación. Nada de `verify`
   sobre métodos privados o llamadas internas. Nada de mocks que
   reproducen la lógica del production code.

4. **Un test vale por lo que atrapa cuando rompe**, no por la cobertura
   que suma.

## Fuentes de verdad soportadas

Las fuentes pueden ser variadas. Orden de precedencia cuando hay más de una:

1. **Jira** (principal) — tiene estado, ownership y se considera la fuente canónica del equipo.
2. **Documento** (PDF, Word, Google Doc) — complementa a Jira.
3. **Excel** — casos de prueba, tablas de decisión, matrices de datos.
4. **Transcripción de reunión (Granola)** — captura intención pero no es fuente canónica; sirve para contexto.

Si hay **conflicto** entre fuentes (ej: Jira dice A, el Excel dice B),
el skill **se frena** y pregunta al usuario cuál prevalece antes de
escribir un solo test.

## Cuándo usarme

- Escribir tests para una feature nueva con criterios de aceptación claros.
- Escribir tests para un bug que se está fixeando (test primero, después fix).
- Revisar tests existentes que huelen a implementación.
- Cubrir una rama de código que no tiene tests.

## Cuándo NO usarme

- Generar tests "porque falta cobertura" sin fuente de verdad → no.
- Arreglar un test que falla sin investigar por qué → no.
- Escribir tests sobre código que cambia cada semana sin spec estable → primero estabilizar el spec.

## Relación con unit-test-author

Este skill valida **comportamiento observable contra una fuente de verdad (spec, ticket, documento)**. Es complementario a `unit-test-author`, que cubre **aislamiento de unidad** (cómo se comporta una función/clase cuando sus colaboradores se mockean).

Regla de oro para elegir cuál usar:

| Pregunta | Skill |
|---|---|
| "¿Cumple el código con el spec?" | `functional-test-author` |
| "¿Funciona la función sola, aislada?" | `unit-test-author` |
| "¿Qué nivel de test conviene para X?" | `test-coverage-strategy` |

## Flujo forzado (el corazón del skill)

### Paso 1 — Pedir la fuente de verdad

Antes de leer una línea de código a testear, el skill **pide explícitamente**:

- "¿Cuál es la fuente de verdad para este comportamiento?"
- "¿Tenés el ticket de Jira, el documento de spec, el Excel de casos, o la transcripción de la reunión donde se decidió?"

Si el usuario no tiene fuente de verdad, el skill **no escribe tests**.
En su lugar, ofrece:

- Ayudar a extraer los criterios de aceptación del código y mandárselos
  al PM / autor del spec para que los confirme. Solo cuando el autor
  confirma, se vuelven "fuente de verdad".
- Escribir un esqueleto de tests con `TODO: confirmar con el ticket`
  explícitos en cada test. Nunca llenar los asserts sin confirmación.

### Paso 2 — Extraer los casos de la fuente de verdad

Leer la fuente y extraer una lista de **escenarios** en formato given/when/then:

- `Dado <precondición>, cuando <acción>, entonces <resultado esperado>`.

No leer todavía el código. Es importante no contaminar la interpretación
de la fuente de verdad con lo que el código ya hace.

Si la fuente de verdad es ambigua en algún escenario, **marcarlo** y
preguntar antes de asumir.

### Paso 3 — Diseñar los tests desde los escenarios

Un test por escenario, con nombre descriptivo que refleje el comportamiento:

- ✅ `should_rejectMigration_when_noAutorizacionExists`
- ❌ `testCase1`, `test_method_returns_true`

Estructura given/when/then en comentarios o secciones del test.

### Paso 4 — Mockear solo lo imprescindible

Los mocks son ventanas al sistema externo, no a la implementación interna.

- ✅ Mock de un cliente HTTP externo (SAP, Moovear, Google Maps).
- ✅ Mock de un repositorio JPA cuando queremos aislar la lógica de servicio.
- ❌ Mock de un método privado del propio servicio.
- ❌ Mock que reproduce la lógica del código que queremos testear.

Si hace falta mockear más de ~5 colaboradores para un solo test, probablemente
el código está acoplado — avisar al usuario y sugerir refactor.

### Paso 5 — Correr los tests contra el código

Recién ahora se lee el código y se corren los tests.

- **Si pasan todos**: perfecto, probablemente el código implementa lo
  que el spec dice.
- **Si fallan algunos**: reportar al usuario con esta estructura:
  ```
  Test: <nombre>
  Expected (según spec): <...>
  Observed (según código): <...>
  Hipótesis: <bug en el código | interpretación del spec equivocada | spec ambiguo>
  ```
  Y **esperar decisión del usuario**. No modificar el test.

### Paso 6 — Reportar cobertura

Decir qué escenarios de la fuente de verdad quedaron cubiertos, cuáles no,
y por qué. No maquillar cobertura — si 2 escenarios no se pudieron testear
por limitación técnica, decirlo.

## Output

```
===========================================================
FUNCTIONAL TESTS — <clase/componente/endpoint>
Fuente de verdad usada: <jira-TICKET-123 | doc X | excel Y>
===========================================================

ESCENARIOS EXTRAÍDOS DE LA FUENTE
  1. Dado ... cuando ... entonces ...
  2. Dado ... cuando ... entonces ...
  ...

TESTS GENERADOS
  [código de los tests]

RESULTADO DE EJECUCIÓN
  🟢 <n> pasaron
  🔴 <n> fallaron:
    - test X: expected <...>, observed <...>, hipótesis: <...>

COBERTURA DE ESCENARIOS
  ✅ escenario 1 — cubierto
  ✅ escenario 2 — cubierto
  ⚠️ escenario 3 — no cubierto (razón: ...)

PREGUNTAS AL AUTOR DEL SPEC
  ...
```

## Ejemplo

**Usuario**: Escribime tests para el método `calcularDiasILT` que suma los
días de ILT desde la fecha del accidente hasta el alta.

**Respuesta**:
```
Antes de escribir un solo test, necesito la fuente de verdad para el
comportamiento esperado. Opciones:

1. ¿Hay ticket de Jira con criterios de aceptación?
2. ¿Documento de spec?
3. ¿Excel con casos esperados (especialmente útil para cálculos de días)?

Lo que ya sé desde el contexto del workspace:
- Res. SRT 237/96 (ver context/regulations.yaml) dice que el día del
  accidente NO cuenta como ILT.
- La recomendación del equipo es usar ChronoUnit.DAYS.between(LocalDate, LocalDate).

Si usamos esa regulación como parte de la fuente de verdad, ya puedo
extraer al menos estos escenarios:

  1. Dado accidente el 2024-01-01 y alta el 2024-01-01, entonces 0 días de ILT.
  2. Dado accidente el 2024-01-01 y alta el 2024-01-02, entonces 1 día de ILT.
  3. Dado accidente el 2024-01-01 y alta el 2024-01-10, entonces 9 días de ILT.
  4. Dado accidente y alta idénticos pero con horas distintas (LocalDateTime),
     entonces el cálculo debe basarse en LocalDate, no en horas.

Pero antes de escribir los tests, necesito que me confirmes:

- ¿Hay casos de borde específicos que el equipo ya decidió? (ej: ¿qué pasa
  si la fecha de alta es anterior a la de accidente? ¿excepción? ¿0?)
- ¿Qué pasa si el trabajador tuvo reapertura? ¿Se cuentan los días de la
  reapertura o no?
- ¿Hay alguna regla específica del cliente GRV que no esté en la resolución?

Contame y escribo los tests. Si no hay respuesta aún, escribo un esqueleto
con TODO: confirmar explícito en cada caso de borde, y lo usás como
checklist para pedirle al PM.
```

## Límites

- **Alpha**: la integración con Jira MCP no existe todavía. Por ahora,
  el usuario tiene que pegar el contenido del ticket o del spec.
- El skill no decide qué es "correcto" — eso es el autor del spec.
- Cuando la fuente de verdad es una transcripción de reunión, el skill
  debe tratarla como "intención capturada", no como decisión firme.
- No reemplaza tests de integración/E2E cuando el comportamiento depende
  de múltiples servicios.

## TODO para promover a beta

- [ ] Integración con Jira MCP
- [ ] Plantillas de test por stack (JUnit 5 + Mockito, Jest + React Testing Library, etc)
- [ ] Ejemplo real documentado de caso donde el test rompió y encontró un bug
- [ ] Métrica: % de tests propuestos que revelaron bugs reales (calibra el skill)
