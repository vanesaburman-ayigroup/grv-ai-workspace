---
name: changelog-keeper
version: v1
maturity: alpha
owner: "[BACKEND_REFERENT]"
category: engineering
related_skills: [api-doc-sync, db-versioning-audit]
related_agents: [grv-doc-keeper]
triggers:
  - "usuario pide actualizar el changelog de un servicio"
  - "usuario está por hacer release"
  - "semanal automático: armar changelog de la semana"
---

# Skill: changelog-keeper

## Propósito

Mantener un `CHANGELOG.md` por servicio, actualizado con los cambios reales
del repo (no adivinados). Genera entries a partir de commits convencionales
y MRs mergeados.

## Formato

Seguimos [Keep a Changelog](https://keepachangelog.com/es-ES/1.0.0/):

- **Added** — funcionalidad nueva
- **Changed** — cambios en funcionalidad existente
- **Deprecated** — marcado para remover
- **Removed** — eliminado
- **Fixed** — bug fixes
- **Security** — arreglos de seguridad

Versionado: **SemVer**. Si el servicio no tiene versionado formal, usamos
fechas: `[2026-04-10]`.

## Cuándo usarme

- Antes de hacer release de un servicio.
- Semanalmente, para mantener el changelog al día sin hacerlo de golpe.
- Cuando el PM pide "¿qué cambió en wsXXXXX esta sprint?".

## Flujo

1. Pedir el servicio o leer del contexto actual.
2. Determinar el rango de cambios (¿desde el último tag? ¿desde una fecha?).
3. Leer commits y MRs mergeados en ese rango.
4. Categorizar cada uno según el prefijo convencional:
   - `feat:` → Added
   - `fix:` → Fixed
   - `refactor:` → Changed (si afecta comportamiento observable)
   - `chore:`/`docs:`/`test:` → generalmente no van al changelog
   - `BREAKING CHANGE:` o `!` → destacar con ⚠️
5. Generar entries concisas y orientadas al lector, no al dev. El changelog
   es para quien no escribió el código.
6. Proponer el bump de versión (MAJOR/MINOR/PATCH) según las entries.

## Regla importante

**No inventar cambios**. Si el mensaje de commit es críptico (`fix: stuff`),
el skill pregunta al autor en lugar de completar. Un changelog con
información inventada es peor que uno incompleto.

## Output

```markdown
## [1.4.0] — 2026-04-10

### Added
- Endpoint GET /api/v1/siniestros/{id}/historial para consultar historial
  de cambios de una denuncia. (#1234)

### Fixed
- Corregido cálculo de días de ILT cuando el accidente cae en fin de semana.
  Ver Res. SRT 237/96. (#1240)
- Resuelto lock wait intermitente en auditoria_facturacion_log tras
  implementar SKIP LOCKED. (#1245)

### Changed
- La generación de nro_siniestro_srt ahora usa INSERT ON DUPLICATE KEY UPDATE
  para garantizar atomicidad bajo concurrencia. (#1238)

### Deprecated
- El campo `legacy_estado` en la respuesta de /api/v1/siniestros está
  deprecado y será removido en 2.0.0. Usar `estado_v2`.
```

## Ejemplo de pregunta cuando hay commit poco claro

**Usuario**: Armá el changelog de esta semana para wssiniestralidad.

**Respuesta** (después de leer commits):
```
Leí los commits de la semana. Puedo armar la mayoría, pero hay 3 commits
que no entiendo lo suficiente para ponerlos en el changelog sin inventar:

1. commit abc123: "fix: refactoring final"
   - Tocó 4 archivos en el paquete de trazadoras CIE-10.
   - ¿Es el fix del bug-cie10-trazadora-wrong-codes? ¿O es otra cosa?

2. commit def456: "chore: ajustes pedido Matías"
   - Modificó el controller de denuncias.
   - ¿Qué ajuste exactamente? ¿Para mencionar en Changed?

3. commit ghi789: "feat: cambios en boolToSN"
   - El mensaje dice feat pero el código parece un refactor.
   - ¿Es cambio de comportamiento o cosmético?

¿Me confirmás los 3? Mientras tanto, te dejo el borrador con los commits
que sí pude interpretar.
```

## Límites

- Depende de commits convencionales; commits crípticos requieren
  intervención humana.
- No reemplaza release notes orientadas al cliente (que requieren
  más interpretación de negocio).
- No actualiza versionado semántico automáticamente; propone y el
  usuario decide.

## TODO para promover a beta

- [ ] Integración con GitLab MCP para leer MRs directamente.
- [ ] Detección de breaking changes a partir de cambios en DTOs o
      eliminación de endpoints (cruzar con `api-doc-sync`).
