---
name: c4-diagrams
version: v1
maturity: alpha
owner: "[OWNER_NAME]"
category: engineering
related_skills: [grv-arquitectura-plataforma]
related_agents: [grv-doc-keeper]
triggers:
  - "usuario pide un diagrama C4 de un servicio o flujo"
  - "usuario pide 'diagrama de arquitectura'"
  - "usuario pide 'graficar el flujo de X'"
---

# Skill: c4-diagrams

## Propósito

Generar diagramas C4 (Context, Container, Component) de la plataforma de
GRV para documentación técnica, onboarding y discusión de diseño.

## Niveles de C4 (referencia rápida)

- **Context**: el sistema + actores externos (usuarios, sistemas externos).
- **Container**: el sistema zoom in: microservicios, BDs, frontends, colas.
- **Component**: un container zoom in: componentes internos de un servicio.
- **Code** (nivel 4): opcional, rara vez útil en este contexto.

## Fuente de verdad

- `context/microservices.yaml` — para el nivel Container.
- `context/integrations.yaml` — para Context y Container (actores externos).
- El código del servicio — solo si el usuario pide nivel Component.

## Cuándo usarme

- Documentación técnica de un servicio nuevo.
- Onboarding de un dev al mapa de la plataforma.
- Análisis de impacto de un cambio (visualizar qué toca).
- Preparación de presentación técnica al cliente o al equipo.

## Cuándo NO usarme

- Para código (nivel 4) — ese trabajo es de diagramas de clases o
  herramientas IDE.
- Para diagramas de secuencia de flujos específicos — usar otro formato
  (Mermaid sequenceDiagram).
- Para flowcharts de lógica de negocio — no es C4, usar Mermaid flowchart.

## Formato de salida

Por defecto, genera el diagrama en **Mermaid** (`C4Context`, `C4Container`)
porque se renderiza en GitLab, Notion, y muchos editores. También puede
generar **PlantUML** con la librería C4-PlantUML si el usuario lo prefiere.

## Flujo

1. Preguntar qué nivel quiere el usuario (Context / Container / Component).
2. Preguntar cuál es el alcance (¿todo el sistema? ¿un servicio y sus dependencias? ¿un flujo específico?).
3. Leer `context/microservices.yaml` y `context/integrations.yaml`.
4. Si falta información relevante, **preguntar** antes de inventar
   componentes o relaciones.
5. Generar el diagrama.
6. Explicar el diagrama en texto (qué representa cada caja, qué flechas son síncronas/async).

## Ejemplo

**Usuario**: Hacé un Container de wssiniestralidad y sus dependencias.

**Respuesta**:
```mermaid
C4Container
  title wssiniestralidad — Container

  Person(mesaCarga, "Mesa de carga", "Carga denuncias iniciales")
  Person(tramitador, "Tramitador", "Gestiona casos")

  System_Boundary(c1, "Plataforma GRV") {
    Container(wssiniestralidad, "wssiniestralidad", "Java/Spring Boot", "Gestión de denuncias y generación de archivos SRT")
    ContainerDb(db, "MariaDB (AWS RDS)", "MariaDB", "datos_denuncia_srt_logs, siniestros, denuncias")
    Container(wsdocumento, "wsdocumento", "Java/Spring Boot", "Gestión documental")
    Container(otros, "Otros servicios...", "", "30+ servicios")
  }

  System_Ext(srt, "SRT (Portal)", "Upload de archivos posicionales AT/EP")
  System_Ext(provinciaArt, "Provincia ART", "Integración bidireccional")
  System_Ext(sgc, "SGC", "Sistema de Gestión de Casos")
  System_Ext(satapp, "Satapp", "Intercambio de archivos via MuleSoft")

  Rel(mesaCarga, wssiniestralidad, "Registra denuncias")
  Rel(tramitador, wssiniestralidad, "Consulta/modifica")
  Rel(wssiniestralidad, db, "Reads/Writes", "JDBC")
  Rel(wssiniestralidad, wsdocumento, "Obtiene docs", "HTTP")
  Rel(wssiniestralidad, srt, "Envía archivos", "Upload")
  Rel(wssiniestralidad, provinciaArt, "Intercambia datos", "REST")
  Rel(wssiniestralidad, sgc, "Intercambia casos")
  Rel(wssiniestralidad, satapp, "Intercambia archivos", "MuleSoft")
```

Notas:
- No incluí actores específicos de negocio (CEM) porque no están confirmados
  como consumers directos de wssiniestralidad — chequear antes de publicar.
- Las flechas no distinguen sync/async en este nivel; si hace falta, pedílo.

## Límites

- El diagrama es tan bueno como la info en `context/microservices.yaml`.
  Si faltan servicios o dependencias, el diagrama va a reflejar esa carencia.
- No genera layouts "lindos" automáticamente — Mermaid C4 decide el layout.
- No reemplaza una sesión de diseño real; es documentación, no decisión.

## Ejemplos de los 3 niveles

### Nivel 1 — Context (el sistema GRV y sus actores externos)

```mermaid
C4Context
  title Plataforma GRV — Context

  Person(mesaCarga, "Mesa de carga", "Carga denuncias iniciales de ART")
  Person(tramitador, "Tramitador", "Gestiona casos de siniestros")
  Person(medico, "Médico auditador", "Audita prestaciones médicas")

  System(grv, "Plataforma GRV", "Gestión de siniestros laborales, prestaciones y facturación para ART")

  System_Ext(srt, "SRT", "Regulador. Recibe archivos AT/EP posicionales")
  System_Ext(provinciaArt, "Provincia ART", "ART regulada. Intercambio bidireccional")
  System_Ext(sgc, "SGC", "Sistema de Gestión de Casos externo")
  System_Ext(satapp, "Satapp / MuleSoft", "Intercambio de archivos via MuleSoft")

  Rel(mesaCarga, grv, "Registra denuncias")
  Rel(tramitador, grv, "Gestiona y tramita casos")
  Rel(medico, grv, "Audita prestaciones")
  Rel(grv, srt, "Envía archivos posicionales AT/EP")
  Rel(grv, provinciaArt, "Intercambia datos de siniestros")
  Rel(grv, sgc, "Sincroniza casos")
  Rel(grv, satapp, "Intercambia archivos")
```

### Nivel 2 — Container (microservicios y sus relaciones)

Ver el ejemplo en la sección anterior (wssiniestralidad).

### Nivel 3 — Component (internals de un servicio)

```mermaid
C4Component
  title wssiniestralidad — Components

  Container_Boundary(ws, "wssiniestralidad") {
    Component(controller, "SiniestroController", "Spring MVC @RestController", "Expone /v1/siniestros")
    Component(service, "SiniestroService", "Spring @Service", "Lógica de negocio: apertura, tramitación, cierre")
    Component(srtGen, "SrtFileGenerator", "Spring @Component", "Genera archivos posicionales para la SRT")
    Component(repo, "SiniestroRepository", "Spring Data JPA", "Acceso a tablas siniestros y datos_denuncia_srt_logs")
    Component(outbox, "OutboxEventPublisher", "Spring @Scheduled + SQS", "Publica eventos a SQS via patrón outbox")
  }

  ContainerDb(db, "MariaDB", "AWS RDS", "siniestros, datos_denuncia_srt_logs, outbox_events")
  System_Ext(sqsQueue, "SQS", "Cola de eventos de siniestros")
  System_Ext(srt, "SRT Portal", "Upload de archivos posicionales")

  Rel(controller, service, "Delega lógica")
  Rel(service, repo, "Reads/Writes")
  Rel(service, srtGen, "Genera archivo cuando se cierra siniestro")
  Rel(service, outbox, "Encola eventos de dominio")
  Rel(repo, db, "JDBC")
  Rel(outbox, db, "Lee outbox_events")
  Rel(outbox, sqsQueue, "Publica eventos")
  Rel(srtGen, srt, "Upload HTTP")
```

## TODO para promover a beta

- [ ] Generación automática de Component desde estructura de paquetes Java.
- [ ] Soporte para exportar a imagen (requiere Mermaid CLI o similar).
- [ ] Actualizar el ejemplo Container con los 30+ servicios reales del workspace.
