# Release Readiness Checklist

**Servicio**: <!-- nombre del servicio -->  
**Versión**: <!-- ej: 2.3.1 -->  
**Fecha de evaluación**: <!-- YYYY-MM-DD -->  
**Evaluado por**: <!-- nombre -->  
**Resultado**: <!-- ✅ GO / ❌ NO-GO -->

---

## 1. Schema y migraciones

- [ ] Las migraciones SQL son reversibles, o existe script de rollback documentado en `scripts/rollback-vX.Y.sql`
- [ ] Las migraciones fueron revisadas con `mariadb-migration-review`
- [ ] Si hay tablas heavy: revisadas con `database-design-heavy-table` y estrategia aprobada
- [ ] `db-versioning-audit` confirma que el versionado de migraciones es correcto
- [ ] Las migraciones corren en staging sin errores

**Notas**: <!-- observaciones -->

---

## 2. Contrato de API

- [ ] `openapi.yaml` está actualizado con los cambios de este release
- [ ] `openapi-validator` sin errores de Tier 1 (warnings documentados si los hay)
- [ ] No hay breaking changes — o, si los hay:
  - [ ] Nueva versión (`v2`) publicada
  - [ ] Todos los consumers identificados con `cross-team-impact`
  - [ ] Consumers notificados con al menos 90 días de anticipación
  - [ ] Período de coexistencia de versiones definido

**Consumers afectados**: <!-- lista o "ninguno" -->  
**Notas**: <!-- observaciones -->

---

## 3. Tests

- [ ] CI verde: todos los tests unitarios y de integración pasan
- [ ] La funcionalidad nueva tiene cobertura al menos del happy path
- [ ] Si hay bug fix: existe test que lo reproduce (y ahora pasa)
- [ ] No se rompieron tests existentes sin justificación

**Tests totales / fallas**: <!-- ej: 152 / 0 -->  
**Notas**: <!-- observaciones -->

---

## 4. Changelog

- [ ] `CHANGELOG.md` del servicio actualizado con entry para esta versión
- [ ] El entry incluye: qué cambió, si hay breaking change, cómo migrar
- [ ] Versión en `pom.xml` o `package.json` actualizada según semver

**Versión anterior**: <!-- X.Y.Z -->  
**Versión nueva**: <!-- X.Y.Z -->  
**Notas**: <!-- observaciones -->

---

## 5. Feature flags (si aplica)

- [ ] Feature nueva tiene flag de feature para rollout gradual
- [ ] El flag está configurado en OFF por default en producción
- [ ] Existe runbook para activar/desactivar el flag
- [ ] N/A: el cambio no requiere feature flag

**Nombre del flag**: <!-- o "N/A" -->  
**Notas**: <!-- observaciones -->

---

## 6. Rollback plan

- [ ] Rollback documentado: ¿cómo? ¿cuánto tarda?
- [ ] La migración SQL es backward compatible con la versión anterior del código
- [ ] El equipo conoce el procedimiento de rollback

**Procedimiento de rollback**: <!-- pasos o link -->  
**Tiempo estimado de rollback**: <!-- ej: 5 minutos -->  
**Notas**: <!-- observaciones -->

---

## 7. Alertas y monitoreo

- [ ] Sentry configurado para el servicio
- [ ] Si hay lógica de negocio crítica nueva: hay alerta para el comportamiento esperado
- [ ] Métricas custom agregadas si aplica (ver `observability-blueprint`)
- [ ] N/A: cambio menor sin nuevo comportamiento observable

**Notas**: <!-- observaciones -->

---

## 8. Runbook (para cambios de alto riesgo)

- [ ] Existe runbook en `templates/incident-runbook.md` para el escenario de error más probable
- [ ] El runbook tiene los comandos exactos para diagnosticar y resolver
- [ ] N/A: cambio de bajo riesgo

**Link al runbook**: <!-- o "N/A" -->  
**Notas**: <!-- observaciones -->

---

## 9. Sign-off

| Rol | Nombre | Fecha | Aprobado |
|---|---|---|---|
| Code reviewer | | | ☐ |
| Tech lead (si alto riesgo) | | | ☐ |
| QA / testing (si hay cambios de UX) | | | ☐ |

---

## Observaciones generales

<!-- Cualquier contexto adicional relevante para este release -->
