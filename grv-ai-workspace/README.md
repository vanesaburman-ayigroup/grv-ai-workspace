# grv-ai-workspace

Plataforma interna de asistencia para desarrollo del equipo de AYI que trabaja sobre la plataforma de GRV (Grupo Río Varadero). Integra skills, subagentes, hooks y MCPs de Claude Code para acelerar el trabajo del equipo.

## Contexto

- **Nosotros**: AYI, consultora argentina.
- **Cliente**: GRV (Grupo Río Varadero). Construimos y mantenemos su plataforma de siniestros laborales para clientes ART, pólizas de accidentes personales, y gerenciadora de empleadores autoasegurados.
- **Scope del workspace**: asistir al equipo de AYI en el desarrollo sobre esa plataforma.

## Qué es esto

No es una biblioteca de prompts. Es un **sistema** que combina:

- **Conocimiento de dominio** (ART, SRT, siniestros, turnos, autorizaciones, prestaciones, facturación, accidentes personales, autoasegurados, integraciones externas).
- **Prácticas de ingeniería** codificadas (review de migraciones, code review con reglas del equipo, generación de tests reales, sincronización de documentación).
- **Observación de procesos** para detectar oportunidades de automatización.
- **Hooks** que disparan checks automáticos en momentos clave del ciclo de desarrollo.
- **MCPs** conectados: MariaDB (dev/prod read-only sobre AWS RDS), Playwright, Context7, Sequential Thinking, Granola.

## Cómo empezar

1. Clonar este repo.
2. Abrirlo con Claude Code (`claude` en la terminal, dentro de la carpeta).
3. Claude Code lee automáticamente `CLAUDE.md` y carga los skills/agents/hooks.
4. Copiar `.env.example` a `.env` y completar las conexiones de MariaDB (ver `docs/mcp-setup.md`).
5. Ejecutar el skill de onboarding: pedile a Claude *"corré el skill de onboarding"*.

## Estructura

```
.claude/            Configuración de Claude Code (settings, MCPs, hooks)
skills/             Módulos de conocimiento cargables on-demand
  onboarding/       Tour guiado para nuevos usuarios
  domain/           Conocimiento de dominio (siniestros, regulaciones, etc)
  engineering/      Prácticas de ingeniería
  processes/        Análisis y automatización de procesos
agents/             Subagentes con roles especializados
prompts/            Biblioteca de prompts reutilizables
context/            Datos estructurados (YAML) que alimentan a los skills
templates/          Plantillas de artefactos (migrations, ADRs, post-mortems)
docs/               Documentación del workspace y case studies
sql/                Scripts SQL (creación de usuario read-only, etc)
```

## Estado de madurez

Cada skill declara su nivel en el frontmatter:

- **alpha** — funciona pero requiere supervisión humana constante.
- **beta** — usable con review ocasional; aún iterando sobre casos reales.
- **production** — probado en al menos 3 casos reales, documentado, estable.

## Regla de oro

**Si Claude no sabe algo de la plataforma real, pregunta. No inventa.** Ver `CLAUDE.md` para la versión completa de esta regla.

## Governance

Ver `GOVERNANCE.md` para el flujo de cambios, ownership y ritual mensual.

## Versionado

Ver `CHANGELOG.md`. Usamos SemVer liviano a nivel de workspace y cada skill tiene su propio campo `version:`.

## Contacto

- **Owner**: `[OWNER_NAME]` (tech lead)
- **Co-maintainer**: `[COMAINTAINER_NAME]`
