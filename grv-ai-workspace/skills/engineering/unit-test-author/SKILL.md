---
name: unit-test-author
version: v1
maturity: alpha
owner: "[OWNER_NAME]"
category: engineering
related_skills: [functional-test-author, test-coverage-strategy, spring-boot-review, react-mfe-review]
related_agents: [grv-test-author]
triggers:
  - "escribime unit tests"
  - "quiero aislar la unidad"
  - "cómo mockeo X"
  - "parametrizar tests"
  - "tests unitarios para esta clase"
  - "cobertura de unidad"
---

# Skill: unit-test-author

## Propósito

Escribir **tests unitarios puros**: tests que verifican el comportamiento de una función o clase **en aislamiento**, mockeando todos sus colaboradores externos.

Complementario a `functional-test-author` (que valida comportamiento contra spec/ticket), este skill se enfoca en la frontera técnica de la unidad:
- `functional-test-author` pregunta: "¿el código cumple con lo que dice el ticket?"
- `unit-test-author` pregunta: "¿esta función/clase funciona correctamente sola, con sus colaboradores mockeados?"

## Cuándo usarme

- Testear una clase de lógica de negocio (service, validator, calculator) en aislamiento.
- Cubrir edge cases técnicos: nulls, valores límite, listas vacías, excepciones.
- Agregar tests a código sin spec disponible.
- Parametrizar muchos casos con la misma estructura de test.
- Cuando el test de integración tarda mucho y querés feedback rápido.

## Cuándo NO usarme

- Cuando tenés un spec/ticket claro → usá `functional-test-author` primero.
- Para testear integraciones reales (HTTP, BD, SQS) → son tests de integración, no unitarios.
- Cuando la unidad tiene más de ~5 colaboradores → el código probablemente necesita refactor.
- Para decidir qué nivel de test conviene → usá `test-coverage-strategy`.

## Flujo

### Paso 1 — Identificar la unidad bajo test

Leer la clase/función/componente completa antes de proponer un test. Entender:
- ¿Qué responsabilidad tiene?
- ¿Dónde está la lógica no trivial (cálculos, validaciones, decisiones)?

### Paso 2 — Mapear colaboradores

Identificar todas las dependencias inyectadas:
- Repositorios JPA, otros services, FeignClient, RestTemplate
- En frontend: hooks custom, RTK Query, llamadas a API

**Regla**: solo se mockea lo que está en la frontera (dependencias inyectadas). Nunca se mockean métodos privados ni la clase bajo test misma.

### Paso 3 — Decidir qué mockear

| Colaborador | Mockear |
|---|---|
| Repositorio JPA | ✅ Siempre en unit test |
| FeignClient / RestTemplate | ✅ Siempre |
| Otro service (dependencia inyectada) | ✅ Sí |
| Método privado del propio service | ❌ Nunca |
| Lógica interna de la clase | ❌ Nunca |
| `LocalDate.now()` / reloj | ✅ Inyectar `Clock` o pasar fecha como parámetro |

Si hace falta mockear más de ~5 colaboradores para un test: avisar al usuario, el código está acoplado.

### Paso 4 — Generar fixtures

Antes de los tests, generar datos de prueba mínimos y representativos:
- **Java**: Object Mother (ver `templates/test-builder.java`)
- **TypeScript**: factories con Faker (ver `templates/test-factory.ts`)

Solo los campos necesarios para el test, con valores del dominio GRV.

### Paso 5 — Escribir los tests

**Java — JUnit 5 + Mockito + AssertJ** (ver `templates/junit5-test.java`):
- `@ExtendWith(MockitoExtension.class)` — strict stubs activados
- `@Mock` para colaboradores, `@InjectMocks` para la unidad
- `@Nested` para agrupar escenarios, `@DisplayName` para nombres descriptivos
- `@ParameterizedTest` + `@CsvSource` / `@MethodSource` para edge cases
- given/when/then como comentarios de sección
- AssertJ: `assertThat(resultado).isEqualTo(...)`, no `assertEquals`

**TypeScript — Jest + RTL** (ver `templates/jest-component-test.tsx`):
- `describe` e `it` con nombres descriptivos
- `describe.each` para parametrización
- RTL: `render`, `screen.getByRole`, `userEvent.click`, `waitFor`
- MSW (`setupServer`) para mockear RTK Query / fetch

### Paso 6 — Edge cases obligatorios

Siempre proponer casos para:
- Valor nulo o undefined en cada parámetro no opcional
- Lista/colección vacía cuando aplica
- Valores en el límite inferior y superior
- Excepción lanzada por el colaborador mockeado

## Output

```
===========================================================
UNIT TESTS — <clase/componente>
Stack: Java JUnit5 | TypeScript Jest+RTL
Unidad bajo test: <nombre completo>
Colaboradores mockeados: <lista>
===========================================================

FIXTURES
  [código de Object Mother / factory]

TESTS
  [código de tests]

EDGE CASES CUBIERTOS
  ✅ null en parámetro X
  ✅ lista vacía
  ✅ boundary: valor mínimo / máximo
  ✅ excepción del colaborador Y
  ⚠️ caso Z no cubierto — requiere refactor para ser testeable

ADVERTENCIAS
  [si el código tiene problemas de testabilidad]
```

## Ejemplo — Java, dominio GRV

```java
@ExtendWith(MockitoExtension.class)
@DisplayName("IltCalculatorService")
class IltCalculatorServiceTest {

    @Mock
    private SiniestroRepository siniestroRepository;

    @InjectMocks
    private IltCalculatorService service;

    @Nested
    @DisplayName("calcularDiasILT")
    class CalcularDiasILT {

        @ParameterizedTest(name = "accidente={0}, alta={1} → {2} días")
        @CsvSource({
            "2024-01-01, 2024-01-01, 0",
            "2024-01-01, 2024-01-02, 1",
            "2024-01-01, 2024-01-10, 9"
        })
        void calculaDiasCorrectamente(String accidente, String alta, int esperado) {
            // given
            var fechaAccidente = LocalDate.parse(accidente);
            var fechaAlta = LocalDate.parse(alta);

            // when
            int resultado = service.calcularDiasILT(fechaAccidente, fechaAlta);

            // then
            assertThat(resultado).isEqualTo(esperado);
        }

        @Test
        void lanzaExcepcion_cuando_altaEsAnteriorAlAccidente() {
            assertThatThrownBy(() ->
                service.calcularDiasILT(LocalDate.of(2024, 1, 10), LocalDate.of(2024, 1, 1))
            ).isInstanceOf(IllegalArgumentException.class);
        }
    }
}
```

## Límites

- No reemplaza tests de integración/E2E: la pirámide de testing los necesita.
- Mockito strict stubs fallan si se configura un mock que no se usa: es intencional, indica test sobrediseñado.
- Código legacy sin inyección de dependencias es difícil de testear unitariamente: ofrecer estrategia de refactor mínimo.

## TODO para promover a beta

- [ ] Ejemplo real documentado en `docs/case-studies/`
- [ ] Validación con el equipo de que Object Mother y Faker factory son adoptados
- [ ] Integración con hook `post-edit-test-suggestion.sh`
