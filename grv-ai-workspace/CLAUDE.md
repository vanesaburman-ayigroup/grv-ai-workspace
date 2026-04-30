# CLAUDE.md

Contexto operativo del workspace. Lectura obligatoria en cada sesión.
Para el contexto extendido (negocio, stack, historia, ejemplos), ver
`docs/onboarding-humans.md`.

---

## ⚠️ Regla de oro: no alucinar

**Si no sabés algo, preguntá. No inventes.**

Aplica a nombres de servicios, esquemas de tablas, endpoints, resoluciones,
reglas de negocio, unidades de negocio del cliente, procesos del equipo.
Un error propagado termina en un MR, en un test falso, en una reunión
con el cliente.

Ante una duda:

1. Buscá en `context/*.yaml` y skills relevantes.
2. Si no está, **decilo** y proponé:
   - "¿Me lo explicás y lo agregamos al `context/`?"
   - "¿Querés que consulte el MCP de MariaDB (dev)?"
   - "¿Querés que busque en el código del servicio X?"
3. Si el usuario aporta la info que faltaba, ofrecé capturarla via
   `workspace-contribution` (es opt-in).

Frases prohibidas para llenar huecos: "probablemente", "suele ser",
"normalmente en este tipo de sistemas".

NUNCA inventar: nombres de servicios/MFEs, esquemas de tablas, convenciones
internas, unidades de negocio del cliente, definiciones de términos,
contenido marcado como `pending` en `context/`.

## Enfoque
Pensá y planeá antes de actuar. Lee los archivos existentes antes de escribir código.
Sé conciso en la respuesta, pero muy minucioso en el razonamiento. Apoyate en el razonamiento del usuario, pedile más specs si es necesario. 
Preferí editar en lugar de reescribir archivos enteros, salvo que el archivo lo requiera.
No vuelvas a leer archivos que ya leíste a menos que el archivo haya podido cambiar.
Probá tu código antes de declararlo terminado.
Nada de aperturas sicofánticas ni cierres innecesarios. Sé directo.
Mantené las soluciones simples y directas.
Las instrucciones del usuario siempre prevalecen sobre este archivo.
---

## Quiénes somos

**AYI** = consultora (nosotros).
**GRV** (Grupo Río Varadero) = cliente. Unidades de negocio sobre las que
trabajamos: siniestros laborales para clientes ART, pólizas de accidentes
personales, gerenciadora de empleadores autoasegurados. PPlataformade 30+
microservicios.

## Stack (resumen)

- **Backend**: Java (versiones varían), Spring Boot, Spring Data JPA, HikariCP, Spring Retry.
- **BD**: MariaDB/MySQL en AWS RDS. InnoDB; legacy en MyISAM.
- **Migraciones SQL**: archivos en repo, **NO Flyway**. Herramienta exacta TODO.
- **Frontend**: React en microfrontends compuestos por **container-app**. Mix de TypeScript con RTK Query y JavaScript sin RTK Query. Stack heterogéneo.
- **Infra**: Docker, Jenkins, AWS, Nginx.
- **Observabilidad**: Sentry, Microsoft Clarity.
- **Mensajería**: SQS (algunas FIFO), patrón outbox en críticos.

Detalle ampliado en `docs/onboarding-humans.md`.

## Términos críticos

- **AT / EP / in-itinere**: tipos de siniestro laboral (Ley 24.557).
- **Accidente personal**: unidad de negocio distinta de ART.
- **Autoasegurado**: empleador que gestiona sus propios riesgos.
- **SRT**: regulador. Recibe archivos posicionales (Res. 3326/14 AT, 3327/14 EP).
- **ILT**: Incapacidad Laboral Transitoria. **Día del accidente NO cuenta** (Res. 237/96).
- **CIE-10 trazadora**: bug abierto, ver `known-bugs.yaml`.
- **ROAM**: pendiente de validar — no usar.

Glosario completo: `context/glossary.yaml`.

## Cómo asistís

1. **No alucines** (regla de oro arriba).
2. **Leé `context/`** antes de opinar sobre temas no triviales.
3. **Los skills refieren al `context/`**, no duplican.
4. **Usá skills y agentes** cuando aplican.
5. **Ambiente default: dev**. Cambio a prod requiere petición explícita y confirmación.
6. **Nada de secretos en archivos**.

## Flujo recomendado por tarea

| Tarea | Skill / agente |
|-------|----------------|
| Revisar migración SQL | `mariadb-migration-review` + `grv-migration-guard` |
| Code review backend | `spring-boot-review` + `grv-reviewer` |
| Code review frontend | `react-mfe-review` + `grv-reviewer` |
| Escribir tests funcionales (contra spec) | `functional-test-author` + `grv-test-author`. **Pedir fuente de verdad antes de escribir un solo test.** |
| Escribir tests unitarios puros | `unit-test-author` + `grv-test-author` |
| Decidir qué nivel de test usar | `test-coverage-strategy` |
| Consulta regulatoria | `grv-regulaciones-srt` |
| ¿Qué servicio toca X? | `context/microservices.yaml` + `grv-arquitectura-plataforma` |
| Bug familiar | `grv-bugs-conocidos` |
| Onboarding | skill `onboarding` |
| Diseñar endpoint nuevo | `api-design-review` + `endpoint-design.md` (prompt) |
| Documentar API sin Swagger | `openapi-from-scratch` → `openapi-validator` |
| Sincronizar Swagger con código | `api-doc-sync` + `grv-doc-keeper` |
| Decisión arquitectónica | `adr-helper` + `architecture-patterns` + `grv-architect` |
| Cambio en tabla heavy | `database-design-heavy-table` + `grv-migration-guard` |
| Instrumentar un servicio | `observability-blueprint` |
| ¿Listo para deployar? | `release-readiness` + `grv-tech-lead` |
| Impacto de un cambio cross-team | `cross-team-impact` |
| Incident activo en prod | `incident-command` + `grv-tech-lead` |
| Deuda técnica del equipo | `tech-debt-audit` + `tech-debt-prioritization.md` (prompt) |
| Preparar el sprint | `sprint-planning-impact` + `grv-tech-lead` |

## Lo que NO hacemos

- Modificar tests para que pasen.
- Proponer fixes sin leer el código existente.
- Agregar dependencias sin justificación.
- Inventar esquemas de tablas (usar MCP MariaDB para verificar).
- Inventar nombres de servicios, MFEs, convenciones o unidades de negocio del cliente.

## Estado del workspace

- **Versión**: 0.2.0 (Fase 1: arquitectos, tech leads, testing unitario, OpenAPI)
- **Owner**: `[OWNER_NAME]`
- **Co-maintainer**: `[COMAINTAINER_NAME]`

Más info: `GOVERNANCE.md`, `docs/rollout-plan.md`, `docs/onboarding-humans.md`.
