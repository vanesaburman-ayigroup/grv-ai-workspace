# Project Context

> Contexto del proyecto para OpenSpec. Se lee antes de proponer/diseñar cualquier change.

## Purpose

Workspace de desarrollo FullStack SENIOR del SAS (GRV). Aloja herramientas de día a día (sync de repos, MCP read-only a la DB del SAS, flujo de soporte, review pre-MR) y, vía OpenSpec, los changes de evolución funcional de los ws/MFE del ecosistema GRV.

## Tech Stack

- **Backend:** Java 11 (algunos servicios hacia Java 21), Spring Boot 2.x/3.x, MariaDB (esquema principal `cs`). Acceso a datos vía JPA/Hibernate y **stored procedures** (`NamedStoredProcedureQuery`). Microservicios `ws*` por dominio.
- **Frontend:** Microfrontends React (heterogéneo). Los modernos en TypeScript + Redux Toolkit Query + `sas-component-lib` + MUI v5; los viejos en JS sin RTK Query.
- **Datos del SAS:** tablas grandes (p. ej. `turnos` ~4.4M, `traslados` ~1.47M, `denuncias` ~450k). Consultas read-only de diagnóstico vía MCP MariaDB.

## Project Conventions

### Code Style
- **Idioma del dominio en español** (entidades, DTOs, servicios, variables). Tokens de framework en inglés (`Controller`, `Service`, `Repository`, `Component`).
- No mezclar inglés/español en variables: adoptar el idioma del archivo destino.
- Preferir parametrización en backend antes que hardcodear IDs en el front.

### Architecture
- Backend por capas: `controller` → `serviceDTO`/`service` → `repository`/SP. Patrón Strategy detrás de interfaces cuando una decisión deba ser intercambiable/transportable.
- Frontend: una pantalla = página + hook orquestador; todo HTTP por la capa de servicios/RTK Query del MFE.

### Testing
- Backend: tests funcionales con el skill `functional-test-author`; verificación de SP en réplica read-only vía MCP MariaDB.
- Frontend: test del hook orquestador + integración con MSW para flujos nuevos.

### Git Workflow
- Branch `feature/<change-id>` por repo afectado, para trazabilidad 1:1 con el change de OpenSpec.
- Commits en español, Conventional Commits (`feat:`, `fix:`, `refactor:`, `docs:`, `test:`).
- Cambios de DB: un script SQL por PR; revisar con el skill `mariadb-migration-review`.

## Domain Context

Ecosistema SAS/GRV (siniestralidad, traslados, auditoría, facturación, SRT). Múltiples ws backend y MFE comparten la base `cs`. Glosario incremental en `docs/dominio-vocabulario.md`; memoria post-fix en `docs/runbooks/`.

## Important Constraints

- MCP MariaDB es **read-only** (`MCP_READ_ONLY=true`) — nunca apuntar a prod en modo escritura.
- Topología actual de los ws: revisar si un servicio es mono o multi-instancia antes de diseñar caches en memoria (define Caffeine vs distribuido).
- Stack congelado: no introducir tecnologías nuevas sin decisión arquitectónica explícita.

## External Dependencies

- GitLab (`grvx/backend`, `grvx/frontend`) vía PAT.
- Jira/Confluence vía MCP Atlassian (OAuth).
- MCP MariaDB (réplica read-only de prod del SAS).
