---
name: test-coverage-strategy
version: v1
maturity: alpha
owner: "[OWNER_NAME]"
category: engineering
related_skills: [unit-test-author, functional-test-author, spring-boot-review, react-mfe-review]
related_agents: [grv-test-author]
triggers:
  - "qué debería testear"
  - "cuánto coverage necesito"
  - "qué tests hago para X"
  - "pirámide de testing"
  - "unit vs integración vs E2E"
  - "cómo distribuyo los tests"
---

# Skill: test-coverage-strategy

## Propósito

Decidir **qué cubrir con qué nivel de test** antes de escribir una sola línea. El error más caro no es tener poca cobertura sino tener la distribución equivocada: todo E2E (lento, frágil) o todo unitario (rápido pero ciega ante integraciones rotas).

## Cuándo usarme

- Antes de empezar a escribir tests para una feature nueva.
- Cuando hay debate en el equipo sobre "hay que testear esto con unit o integración".
- Para auditar una suite de tests existente y detectar desequilibrios.
- Al onboardear un dev nuevo para que entienda la estrategia del proyecto.

## Cuándo NO usarme

- Para escribir los tests → usá `unit-test-author` o `functional-test-author`.
- Para decidir si el código tiene bugs → eso es `functional-test-author`.

## Pirámide aplicada al stack GRV

```
        /\
       /  \   E2E / Playwright
      /----\  (pocos, happy path del flujo completo)
     /      \
    /--------\ Integración
   /          \ (mariadb real, spring context, mensajes SQS)
  /------------\
 /              \ Unit
/----------------\ (la mayoría: services, validators, calculators)
```

### Unit tests — la base (mayoría)

**Qué va acá**: toda lógica de negocio encapsulada en un service, validator, calculator, transformer, mapper.

En GRV: `IltCalculatorService`, `PrestacionValidator`, `SrtFileGenerator`, componentes React sin side effects.

**Señal de que algo va en unit test**: se puede testear mockeando colaboradores sin perder confianza.

Usar: `unit-test-author`

### Tests de integración — la panza (cantidad moderada)

**Qué va acá**: capas que integran con infraestructura real: repositorios JPA con BD real (H2 / MariaDB test), endpoints Spring MVC con `@SpringBootTest`, procesadores de mensajes SQS.

En GRV: `SiniestroRepository`, controllers (con `MockMvc`), jobs de cron que leen/escriben en BD.

**Señal**: si mockeás la BD en un test de repositorio, el test no prueba nada relevante.

Usar: `functional-test-author` + contexto de integración.

### Tests E2E / Playwright — la punta (pocos)

**Qué va acá**: happy path del flujo de negocio completo desde el frontend hasta la BD. Flujos críticos del negocio GRV: denuncia de siniestro, liquidación de prestaciones.

**Señal**: si rompe este test, el cliente lo nota.

Usar: Playwright MCP.

## Heurística de decisión

Para cada pieza de código, respondé estas preguntas:

1. **¿Tiene lógica de negocio propia (cálculos, validaciones, transformaciones)?**
   → Unit test. No se necesita infra para validar la lógica.

2. **¿Depende de que la BD/infraestructura se comporte de cierta manera?**
   → Test de integración. Mockar la BD acá sería testear el mock, no el comportamiento.

3. **¿Es un flujo de usuario end-to-end que el negocio necesita que funcione?**
   → E2E. Pocos, pero los que están deben correr en CI.

4. **¿Es un componente React con solo renderizado?**
   → Unit test con RTL (render + snapshot o assertion básica).

5. **¿Es un componente React con llamadas a API?**
   → Unit test con MSW para mockear las respuestas. Solo integración si querés probar el contrato real.

## Output

```
ESTRATEGIA DE TESTS — <feature / clase / servicio>
==============================================

DISTRIBUCIÓN RECOMENDADA
  Unit tests: X%
  Integración: Y%
  E2E: Z%

POR COMPONENTE
  ClaseName → unit test (razón: tiene lógica de cálculo de X)
  RepositoryName → test de integración con H2 (razón: valida queries JPA)
  FlowName → E2E Playwright (razón: flujo crítico de negocio)

ANTIPATRONES DETECTADOS (si aplica)
  ⚠️ Repository testeado con mock → no valida el query real
  ⚠️ Toda la suite es E2E → lenta y frágil

PRÓXIMOS PASOS
  1. Escribir unit tests para X con /unit-test-author
  2. Agregar integration test para Y
  3. Verificar si hay E2E existente para el flujo Z
```

## Límites

- La pirámide es una guía, no una ley. Hay contextos donde la distribución varía (legacy sin unit tests, APIs externas que solo se pueden testear con integración).
- No valida si los tests existentes están bien escritos → eso es `functional-test-author` + `unit-test-author`.

## TODO para promover a beta

- [ ] Ejemplo de auditoría de suite existente documentado en `docs/case-studies/`
- [ ] Valores de referencia de cobertura acordados con el equipo (% mínimo por capa)
