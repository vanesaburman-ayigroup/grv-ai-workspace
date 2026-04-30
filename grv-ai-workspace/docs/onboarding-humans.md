# Onboarding técnico — grv-ai-workspace

Contexto extendido para quien se incorpora al equipo o al workspace.
`CLAUDE.md` tiene el resumen operativo; este doc tiene el detalle.

---

## Quiénes somos

**AYI** es la consultora. Desarrollamos y mantenemos la plataforma GRV.

**GRV** (Grupo Río Varadero) es el cliente. Gestiona siniestros laborales,
prestaciones médicas y facturación para clientes ART (Aseguradoras de
Riesgos del Trabajo), pólizas de accidentes personales y empleadores
autoasegurados.

El sistema nació hace varios años; tiene deuda técnica acumulada, stacks
heterogéneos entre servicios, y convenciones que varían por época de
desarrollo. El workspace existe para ayudar a navegarlo.

---

## Dominio de negocio

### Ley 24.557 — Riesgos del trabajo

La regulación principal. Define:

- **AT** (Accidente de Trabajo): accidente ocurrido durante la jornada laboral.
- **EP** (Enfermedad Profesional): patología causada por el trabajo.
- **In-itinere**: accidente en el trayecto al/desde el trabajo.
- **ILT** (Incapacidad Laboral Transitoria): días que el trabajador no puede
  trabajar. El día del accidente **no cuenta** (Res. 237/96). Esto tiene
  lógica de negocio específica en el código.
- **SRT** (Superintendencia de Riesgos del Trabajo): regulador nacional.
  Recibe archivos posicionales AT (Res. 3326/14) y EP (Res. 3327/14).

### Flujo de una denuncia

1. Mesa de carga ingresa la denuncia inicial.
2. El sistema abre el siniestro y genera expediente.
3. Se registran prestaciones médicas, traslados, internaciones.
4. Se genera el archivo posicional para la SRT.
5. Se factura a la ART.
6. El caso se cierra con alta médica, ILP o fallecimiento.

### Actores externos principales

| Actor | Qué es | Integración |
|-------|--------|-------------|
| SRT | Regulador | Upload de archivos posicionales AT/EP |
| Provincia ART | ART regulada | REST bidireccional |
| SGC | Sistema de Gestión de Casos | REST |
| SATApp / MuleSoft | Integrador de archivos | Intercambio por MuleSoft |
| SAP | ERP del cliente | Facturación |
| Moovear | Traslados | REST |

Ver detalle en `context/integrations.yaml`.

---

## Stack técnico

### Backend

- **Lenguaje**: Java. Las versiones varían por servicio (algunos en Java 8,
  otros en 11 o 17). Confirmar por servicio antes de asumir.
- **Framework**: Spring Boot. Spring Data JPA, HikariCP, Spring Retry.
- **Patrones comunes**: Outbox pattern en servicios críticos (para garantía
  de entrega via SQS). Repository pattern. Servicios transaccionales con
  `@Transactional`.
- **Resiliencia**: Resilience4j (Circuit Breaker) en servicios que llaman
  a externos. Spring Retry para reintentos con backoff.

### Base de datos

- **Motor**: MariaDB / MySQL en AWS RDS. InnoDB es el motor estándar.
  Hay tablas legacy en MyISAM — documentadas en `context/microservices.yaml`.
- **Migraciones**: archivos SQL en el repo de cada servicio, **NO Flyway**.
  El proceso exacto de aplicación está pendiente de documentar. No asumir
  runner automático.
- **Heavy tables**: tablas con alto volumen que requieren estrategia especial
  para DDL. Ver `context/heavy-tables.yaml`.
  - `siniestros`: cientos de miles de filas.
  - `datos_denuncia_srt_logs`: append-only, alta escritura.
  - `auditoria_facturacion_log`: compartida entre servicios, historial de
    lock wait en prod (ver `context/known-bugs.yaml`).

### Frontend

- **Arquitectura**: microfrontends compuestos por `container-app`.
- **Stack**: mix de TypeScript con RTK Query (servicios más nuevos) y
  JavaScript sin RTK Query (servicios legacy). No asumir uniformidad.
- **Testing**: Jest + React Testing Library + MSW (Mock Service Worker) +
  factories con Faker. Ver templates en `templates/jest-component-test.tsx`
  y `templates/test-factory.ts`.

### Mensajería

- **SQS**: algunas colas FIFO. Patrón outbox en servicios críticos para
  garantizar entrega (no perder mensajes ante fallo antes del ack).

### Infra

- Docker (contenedores), Jenkins (CI/CD), AWS (RDS, SQS, EC2), Nginx.

### Observabilidad

- **Sentry**: errores de aplicación. Capturar excepciones con contexto
  (no solo el mensaje). PII prohibida en Sentry.
- **Microsoft Clarity**: comportamiento de usuario en frontend.
- **Micrometer**: métricas de aplicación (JVM, HikariCP, métricas custom).
- **Logs**: `slf4j` + JSON estructurado recomendado. MDC para trazar requests.
  PII (DNI, CUIL, nombres, domicilios) prohibida en logs.

---

## Convenciones de código

### Backend (Java)

- **Tests**: JUnit 5 + Mockito (strict stubs) + AssertJ. Patrón Object Mother
  para fixtures. Ver `templates/junit5-test.java` y `templates/test-builder.java`.
- **Commits**: Conventional Commits (`feat:`, `fix:`, `chore:`, etc.).
  Ver hook `pre-commit-conventional-commits.sh`.
- **SQL**: snake_case para nombres de tablas y columnas. InnoDB + charset
  utf8mb4. Migraciones idempotentes con `IF NOT EXISTS`.

### Frontend (TypeScript/JS)

- **Tests**: Jest + RTL + MSW. Factories con Faker para datos de prueba.
  Ver `templates/jest-component-test.tsx` y `templates/test-factory.ts`.

### API (OpenAPI / REST)

- Versión: `/v1/` como prefijo de paths.
- Paths: kebab-case (`/siniestros/{id}/historial`).
- Query params: snake_case (`?fecha_desde=`).
- Request/response body JSON: camelCase.
- Spec: OpenAPI 3.0.3. Ver `templates/openapi-skeleton.yaml`.

---

## Roles cubiertos por el workspace

El workspace tiene skills y agentes específicos para cada rol técnico:

### Desarrollador backend/frontend

Skills de uso diario: `mariadb-migration-review`, `spring-boot-review`,
`react-mfe-review`, `unit-test-author`, `functional-test-author`,
`api-doc-sync`, `grv-bugs-conocidos`.

Agentes: `grv-reviewer`, `grv-migration-guard`, `grv-test-author`,
`grv-doc-keeper`.

### Arquitecto / tech lead senior

Skills de diseño: `adr-helper`, `architecture-patterns`, `api-design-review`,
`observability-blueprint`, `database-design-heavy-table`, `c4-diagrams`.

Agente dedicado: `grv-architect` — orquesta todos los skills de diseño.
Sugiere patrones (Outbox, Circuit Breaker, Saga) con criterios de GRV.
Propone ADRs usando `templates/adr-template.md`.

### Tech lead / engineering manager

Skills de proceso: `tech-debt-audit`, `release-readiness`, `cross-team-impact`,
`incident-command`, `sprint-planning-impact`, `changelog-keeper`,
`db-versioning-audit`.

Agente dedicado: `grv-tech-lead` — coordina entre servicios, evalúa impacto,
lidera incidentes, decide go/no-go en releases.

Prompts de apoyo: `tech-debt-prioritization.md`, `breaking-change-evaluation.md`,
`onboarding-tech-deep.md`.

---

## Qué el workspace NO sabe (huecos conocidos)

Estos ítems están pendientes de completar. Aportar la info via
`workspace-contribution` si la conocés:

- `context/microservices.yaml`: varios servicios tienen placeholders
  (`[FRONTEND_NAME_*]`, owners, tablas propias).
- `context/team.yaml`: referentes reales por área (campos `[OWNER_NAME]`,
  `[ARCHITECT_REFERENT]`, `[TECH_LEAD_REFERENT]`, etc.).
- Herramienta de aplicación de migraciones SQL: no es Flyway, pero el
  proceso exacto no está documentado.
- Stack por defecto para MFEs nuevos: ¿TypeScript + RTK Query en todos
  los nuevos? No está confirmado como decisión.
- Política de versionado de APIs: ¿cuándo se crea `/v2/`?
- `context/heavy-tables.yaml`: lista real de tablas heavy (aproximada).
- Endpoints de GitLab MCP y Sentry MCP para `.claude/mcp.json`.

---

## Cómo navegar el workspace

```
grv-ai-workspace/
├── CLAUDE.md               ← leer primero; resumen operativo
├── GOVERNANCE.md           ← cómo evoluciona el workspace
├── CHANGELOG.md            ← qué cambió en cada versión
├── context/                ← fuente de verdad del dominio GRV
│   ├── microservices.yaml  ← mapa de servicios, tablas, owners
│   ├── glossary.yaml       ← términos del dominio
│   ├── regulations.yaml    ← regulaciones SRT relevantes
│   ├── integrations.yaml   ← sistemas externos
│   ├── known-bugs.yaml     ← bugs en prod documentados
│   └── heavy-tables.yaml   ← tablas de alta sensibilidad
├── skills/
│   ├── engineering/        ← skills técnicos (review, tests, API, BD, etc.)
│   └── processes/          ← skills de proceso (release, deuda, incidentes)
├── agents/                 ← subagentes orquestadores por rol
├── templates/              ← plantillas listas para usar
├── prompts/                ← prompts estructurados para tareas comunes
├── docs/
│   ├── onboarding-humans.md ← (este archivo)
│   ├── rollout-plan.md
│   ├── how-to-add-a-skill.md
│   ├── how-to-add-an-agent.md
│   └── how-to-add-a-hook.md
└── .claude/
    ├── settings.json       ← hooks registrados
    ├── hooks/              ← scripts de hooks
    └── mcp.json            ← configuración MCPs
```

Para agregar un skill, agente o hook, ver los how-to en `docs/`.
Para proponer cambios al `context/`, ver `workspace-contribution` skill.

---

## Primeros pasos al incorporarse

1. Leer `CLAUDE.md` completo.
2. Leer `context/microservices.yaml` para entender el mapa de servicios.
3. Revisar `context/known-bugs.yaml` — los bugs que están en prod y hay que
   conocer antes de tocar código relacionado.
4. Correr `scripts/install-hooks.sh` en cada repo local de GRV.
5. Configurar `.env` con las variables de MCPs que uses.
6. Usar un skill en una tarea real la primera semana. El primer caso de uso
   documentado es el más valioso.
