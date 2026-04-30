---
name: grv-best-practices
version: v1
maturity: alpha
owner: "[OWNER_NAME]"
category: engineering
related_skills: [spring-boot-review, react-mfe-review, mariadb-migration-review, functional-test-author]
related_agents: [grv-reviewer]
triggers:
  - "usuario pregunta '¿cómo hacemos X en el equipo?'"
  - "usuario pide 'las buenas prácticas de AYI para Y'"
  - "nuevo dev pregunta convenciones"
---

# Skill: grv-best-practices

## Propósito

Ser el librito vivo de convenciones y buenas prácticas del equipo de AYI
trabajando sobre la plataforma de GRV. Este skill **no inventa** convenciones;
documenta las que el equipo ya acordó, y marca claramente lo que está
pendiente de acordar.

## Principio rector

Si una convención no está documentada acá o en `CLAUDE.md`, **no es una
convención todavía** — es una propuesta. El skill no puede imponer algo
que el equipo no decidió.

## Categorías

Este skill actúa como índice. Para temas específicos, delegar al skill
correspondiente:

- **Review de código Java** → `spring-boot-review`
- **Review de código React** → `react-mfe-review`
- **Migraciones** → `mariadb-migration-review`
- **Tests** → `functional-test-author`
- **Documentación** → `api-doc-sync`, `c4-diagrams`, `changelog-keeper`
- **Arquitectura** → `grv-arquitectura-plataforma`

## Convenciones confirmadas

### Commits

- Convencional: `feat:`, `fix:`, `chore:`, `docs:`, `refactor:`, `test:`.
- Un commit por cambio lógico; evitar commits monstruo.
- Mensaje claro en imperativo: "agrega endpoint X", no "agregado endpoint X".

### MRs

- Descripción con: problema, solución, testing manual, riesgo.
- Nombres de branch: `feat/...`, `fix/...`, `chore/...`.
- Auto-review antes de pedir review humano (leer el propio diff).

### Backend

- Transacciones explícitas en operaciones multi-write.
- `@Recover` con propagación de error o marca de inconsistencia —
  **nunca silenciar**.
- Audit log en operaciones sobre denuncias, siniestros, facturación.
- Nada de PII sensible en logs.
- DTOs separados de entidades JPA.

### Frontend

- Rules of Hooks (React) estrictas.
- Estado Redux serializable.
- Imports específicos para tree-shaking.
- Credenciales via `credentials.js` pattern (no env vars en build time).

### Base de datos

- InnoDB en tablas nuevas.
- Migraciones SQL en el repo (herramienta exacta TODO).
- Idempotencia: toda migración debe poder re-correrse.
- Compatibilidad backward durante el deploy: código viejo y nuevo conviven.

### Testing

- Tests validan comportamiento contra fuente de verdad (no implementación).
- Jamás modificar un test para que pase.
- Mocks solo para colaboradores externos, no internos.

## Convenciones pendientes de acordar

Estas cosas aparecen recurrentemente pero el equipo no tiene (todavía)
decisión formal:

- [ ] **Naming de microservicios backend**: hay heterogeneidad por historia.
- [ ] **Naming de microfrontends**: pendiente.
- [ ] **Herramienta de aplicación de migraciones SQL**: no usamos Flyway; qué usamos exactamente pendiente de documentar.
- [ ] **Estructura de paquetes Java** estándar por servicio.
- [ ] **Política de versiones de dependencias**: cuándo actualizar, cómo.
- [ ] **Política de versioning de APIs**: `/v1`, `/v2`, deprecation timeline.
- [ ] **Stack front "por defecto" para MFEs nuevos**: ¿TS + RTK Query siempre?
- [ ] **Ownership formal de cada servicio/MFE**: completar `context/team.yaml`.

## Cuándo usarme

- Un dev pregunta "¿cómo hacemos X acá?".
- Onboarding de alguien nuevo.
- Durante un review, cuando hace falta una convención para decidir.
- Como input para una reunión de decisión: "estas son las pendientes, elijamos".

## Flujo

1. Escuchar la pregunta.
2. Si hay convención confirmada: responder.
3. Si está en "pendientes de acordar": decirlo explícitamente. Ofrecer
   documentar el acuerdo si el usuario tiene la respuesta.
4. Si es un tema nuevo no cubierto acá: **no inventar**. Pedir al usuario
   que confirme con el equipo y agregar al skill.

## Output

Formato simple, conversacional. El skill no genera reportes — responde
preguntas.

## Ejemplo

**Usuario**: ¿Usamos `@Transactional(readOnly=true)` en queries de lectura?

**Respuesta**:
```
Sí, es una convención confirmada del equipo. Los métodos que solo leen
deben tener @Transactional(readOnly=true) para permitirle a Hibernate y
al driver optimizar la sesión.

Ver sección "Backend" en grv-best-practices. También aparece en el
checklist de spring-boot-review.

Excepción: si el método no toca BD en absoluto (solo procesa datos en
memoria), no necesita @Transactional.
```

**Usuario**: ¿Qué librería usamos para validación de DTOs?

**Respuesta**:
```
Esto no lo tengo como convención confirmada en grv-best-practices.
Sé que usamos Spring Boot y que generalmente se usa jakarta.validation
(Bean Validation) con anotaciones @Valid, @NotNull, etc — pero **no
puedo confirmarte que sea la elección oficial del equipo en AYI sin
que alguien lo valide**.

Dos opciones:
1. Si vos sabés que es la convención, lo agrego a grv-best-practices
   y queda documentado.
2. Si no estás seguro, consultalo con [BACKEND_REFERENT] y después lo
   agregamos.

No quiero afirmarlo como convención sin confirmación para no crear una
falsa fuente de verdad.
```

## Ofrecer captura como contribución

Cuando el usuario confirma una convención que estaba en "pendientes de
acordar", o aporta una nueva convención que el equipo ya decidió pero
que no estaba documentada, al cierre del flujo ofrecer invocar
`workspace-contribution` con `type: best-practices`. Ver
`skills/engineering/workspace-contribution/helper.md`.

El `proposed_content` es el texto en markdown a insertar en la sección
correspondiente de este mismo SKILL.md (Backend, Frontend, BD, Testing,
Commits, MRs).

**Importante**: las convenciones capturadas por esta vía **deben venir
del equipo**, no del criterio personal del usuario. El skill pregunta
explícitamente "¿esto lo decidió el equipo o es tu preferencia personal?"
antes de ofrecer capturar.

## Límites

- **Alpha**: el catálogo de convenciones confirmadas es chico todavía.
  Crece con el uso.
- No reemplaza documentación técnica formal (que puede vivir en Notion,
  Confluence, etc).
- No puede "imponer" convenciones — solo documenta las que el equipo eligió.
