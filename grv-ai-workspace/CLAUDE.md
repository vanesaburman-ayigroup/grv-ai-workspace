# CLAUDE.md — Contexto global del workspace

Este archivo es leído automáticamente por Claude Code al abrir el workspace. Define quiénes somos, qué construimos, cómo trabajamos y qué debe hacer Claude al asistirnos.

---

## ⚠️ Regla de oro: no alucinar

**Si no sabés algo, preguntá. No inventes.**

Esto aplica a nombres de servicios, esquemas de tablas, endpoints, resoluciones, reglas de negocio, unidades de negocio del cliente, procesos del equipo, y cualquier otra cosa. La tentación de completar con lo que "suena razonable" es el fallo más costoso de una asistencia con IA en este contexto: un error propagado termina en un MR, en un test falso, en una reunión con el cliente.

Cuando haya una duda:

1. Buscá primero en `context/*.yaml` y en los skills pertinentes.
2. Si está ahí, usalo.
3. Si no está, **decilo explícitamente** y proponé una de estas tres acciones:
   - "Esto no lo tengo documentado, ¿me lo explicás y lo agregamos al `context/`?"
   - "¿Querés que consulte el MCP de MariaDB (dev) para verificar?"
   - "¿Querés que busque en el código del servicio X?"
4. **Si el usuario aporta la información que faltaba**, ofrecé al final
   del flujo capturarla como propuesta de mejora al workspace via el
   skill `workspace-contribution`. Es opt-in: el usuario decide si sí,
   esperar (buffer) o no. Ver
   `skills/engineering/workspace-contribution/SKILL.md` y el helper en
   la misma carpeta.

Frases prohibidas cuando se usan para llenar un hueco de conocimiento real: "probablemente", "suele ser", "normalmente en este tipo de sistemas".

En particular, Claude **no inventa**:

- Nombres de servicios, microservicios o microfrontends.
- Nombres de tablas, columnas o esquemas.
- Nombres de convenciones internas.
- Unidades de negocio, productos o sistemas del cliente.
- Definiciones de términos de dominio (ver `context/glossary.yaml`).
- Definiciones que estén marcadas como **pendientes de validar** en `context/`.

---

## Quiénes somos

**AYI** es una consultora argentina de software.

**GRV** (Grupo Río Varadero) es nuestro cliente principal. GRV tiene varias unidades de negocio; nosotros trabajamos sobre las siguientes:

- **Administración de siniestros laborales** para clientes ART (aseguradoras de riesgos del trabajo).
- **Pólizas de accidentes personales**.
- **Gerenciadora de empleadores autoasegurados**.

El workspace `grv-ai-workspace` asiste al equipo de AYI en el desarrollo de la plataforma que construimos para GRV. La plataforma tiene **más de 30 microservicios** en producción.

## Stack

- **Backend**: Java, Spring Boot, Spring Data JPA, HikariCP, Spring Retry. Las versiones de Java varían entre servicios (algunos en 17, otros en 21). *[TODO: inventariar versiones por servicio.]*
- **Base de datos**: MariaDB / MySQL en **AWS RDS**. InnoDB; algunas tablas legacy en MyISAM.
- **Migraciones SQL**: mantenemos las migraciones como archivos SQL en el repo, pero **no usamos Flyway**. *[TODO: documentar la herramienta/proceso exacto de aplicación de migraciones.]*
- **Frontend**: React en microfrontends compuestos por un **container-app**. Algunos frontends nuevos están en TypeScript con Redux Toolkit Query; **otros más viejos en JavaScript sin RTK Query**. *[TODO: inventariar stack por microfrontend y convención de naming.]*
- **Infra**: Docker, Jenkins CI/CD, AWS (EC2, RDS, S3, SQS), Nginx.
- **Observabilidad**: Sentry, Microsoft Clarity, logs estructurados.
- **Mensajería asincrónica**: SQS (algunas FIFO), patrón outbox en servicios críticos.

## Sistemas de IA

Ver `context/ai-systems.yaml` para el catálogo completo.

**IA para el cliente (GRV)**, en uso:

- **ColonIA** — chatbot con información para CEM, tramitadores y mesa de carga.
- **Agente de informes médicos** — clasifica si un archivo subido a un turno médico es efectivamente un informe médico o si se subió otra cosa.
- **Análisis de métricas del call center** — sobre llamadas de la mesa de atención.

**IA interna (de AYI)**, estado POC:

- Prueba de concepto de agente de asistencia interna para tareas regulatorias y diagnóstico. No está en producción.

## Contexto de dominio (lectura obligatoria antes de asistir)

Trabajamos principalmente en el dominio de **Riesgos del Trabajo en Argentina**, regulado por la **Ley 24.557** y resoluciones de la **SRT (Superintendencia de Riesgos del Trabajo)**. También cubrimos pólizas de accidentes personales y la gerenciadora de autoasegurados, que comparten parte del modelo pero tienen reglas propias.

Términos clave:

- **ART**: Aseguradora de Riesgos del Trabajo.
- **Siniestro laboral**: evento que genera derecho a prestaciones bajo Ley 24.557. Puede ser:
  - **Accidente de trabajo (AT)**
  - **Enfermedad profesional (EP)**
  - **Accidente in-itinere** (ocurrido en el trayecto casa/trabajo)
- **Accidente personal**: evento cubierto por pólizas de accidentes personales. Es una unidad de negocio distinta de ART y tiene sus propias reglas.
- **Autoasegurado**: empleador que gestiona sus propios riesgos del trabajo (no tiene ART contratada). GRV los gerencia mediante una unidad dedicada.
- **Denuncia**: registro inicial de un siniestro o accidente.
- **SRT**: organismo regulador. Recibe archivos posicionales según Res. 3326/14 (AT) y 3327/14 (EP).
- **ATEP**: códigos de agentes de riesgo / circunstancias del siniestro.
- **ESOP**: códigos de agentes causantes de EP, definidos en Res. 81/19 Anexo III.
- **CIE-10**: clasificación internacional de enfermedades. Usado para diagnósticos.
- **CIE-10 trazadora**: subset de códigos que dispara validaciones especiales.
- **ILT**: Incapacidad Laboral Transitoria — días en los que el trabajador no puede trabajar. Regulada por Res. SRT 237/96 (el día del accidente cuenta como trabajado, no como ILT).
- **ROAM**: *[definición pendiente de validar con el equipo — no usar hasta confirmar en `context/glossary.yaml`.]*
- **Prestación**: atención médica, kinesiológica, farmacológica, traslado, etc., que la ART debe brindar.
- **Agencia / prestador**: entidad externa que provee la prestación.

Ver `context/glossary.yaml` para glosario completo y `context/regulations.yaml` para el índice de resoluciones.

## Mapa de microservicios

Ver `context/microservices.yaml`. La plataforma tiene 30+ servicios. Documentamos inicialmente los más tocados en el día a día; el resto está marcado como pendiente. Cuando aparezca un servicio no documentado, **agregalo al YAML antes de responder sobre él, o decí que no lo tenés mapeado todavía**.

## Cómo trabajamos

### Principios del equipo

1. **Pragmático sobre elegante**. Preferimos soluciones simples que funcionen hoy y se puedan iterar, antes que abstracciones prematuras.
2. **Iteración sobre patches**. Cuando un artefacto (doc, código, config) tiene muchos cambios, preferimos regenerarlo limpio antes que parchar.
3. **Documentación como parte del trabajo, no como ceremonia post-hoc**. Swagger, changelog, diagramas se actualizan en el mismo MR que el código.
4. **Los tests testean comportamiento, no implementación**. Mocks son herramienta, no objetivo.
5. **Los bugs en producción se investigan hasta el root cause**. No se cierran con "no reproducible".

### Convenciones de código

- **Backend**: convenciones de naming pendientes de documentar formalmente. *[TODO.]*
- **Frontend**: microfrontends compuestos por container-app. Convención de naming pendiente. *[TODO.]*
- **Migraciones**: archivos SQL versionados en el repo. Herramienta/proceso exacto pendiente. *[TODO.]*
- **Commits**: convencional (`feat:`, `fix:`, `chore:`, `docs:`, `refactor:`, `test:`).
- **MRs**: descripción con problema, solución, testing manual, riesgo.

## Cómo asistís vos, Claude

### Reglas generales

1. **No alucines**. Si no sabés, preguntás. Ver la regla de oro arriba.
2. **Leé el contexto antes de responder**. Para cualquier tarea no trivial, consultá `context/` y los skills relevantes antes de opinar.
3. **Los skills refieren al `context/`, no duplican**. Si vas a mencionar un servicio, un término, una regulación o una integración, sacalo del YAML correspondiente. Si no está ahí, marcalo como pendiente de validar y no inventes.
4. **Usá los skills disponibles**. Si una tarea matchea con un skill, cargalo y seguí su flujo.
5. **Usá los subagentes cuando corresponda**.
6. **Ambiente default: dev**. Nunca ejecutes queries contra prod sin que el usuario lo pida explícitamente. Ver `docs/mcp-setup.md`.
7. **Nada de secretos en archivos**.

### Flujo recomendado para tareas típicas

- **"Revisá esta migración"** → `skills/engineering/mariadb-migration-review` + agente `grv-migration-guard`.
- **"Revisá este código"** → `skills/engineering/spring-boot-review` o `react-mfe-review` + agente `grv-reviewer`.
- **"Escribí tests para esto"** → `skills/engineering/functional-test-author` + agente `grv-test-author`. **Pedir siempre la fuente de verdad antes de escribir un solo test**.
- **"¿Qué dice la resolución X?"** → `skills/domain/grv-regulaciones-srt`.
- **"¿Qué servicio toca cuando pasa X?"** → `context/microservices.yaml` + `skills/domain/grv-arquitectura-plataforma`.
- **"Este bug se parece a algo que ya vimos"** → `skills/domain/grv-bugs-conocidos`.

### Lo que NO hacemos

- **No modificar tests para que pasen**.
- **No proponer soluciones sin leer el código existente**.
- **No agregar dependencias nuevas sin justificación**.
- **No inventar esquemas de tablas**. Usar MCP de MariaDB en modo read-only para verificar.
- **No inventar nombres de servicios, de microfrontends, de convenciones o de unidades de negocio del cliente**.

## Equipo

Ver `context/team.yaml`.

## Estado del workspace

- **Versión actual**: 0.1.0 (bootstrap)
- **Owner**: `[OWNER_NAME]`
- **Co-maintainer**: `[COMAINTAINER_NAME]`

Leer también: `GOVERNANCE.md`, `docs/rollout-plan.md`.
