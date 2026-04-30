---
name: release-readiness
version: v1
maturity: alpha
owner: "[OWNER_NAME]"
category: processes
related_skills: [db-versioning-audit, api-doc-sync, changelog-keeper, cross-team-impact, tech-debt-audit]
related_agents: [grv-tech-lead]
triggers:
  - "estamos listos para deployar"
  - "checklist de release"
  - "pre-deploy review"
  - "podemos mergear esto"
  - "release readiness"
  - "go/no-go"
---

# Skill: release-readiness

## Propósito

Checklist maestro pre-release de un servicio GRV. Responde la pregunta "¿podemos deployar esto?" con evidencia, no con optimismo.

## Cuándo usarme

- Antes de mergear a main y hacer deploy a producción.
- Al evaluar si un MR está listo para review final.
- Al preparar un release con múltiples cambios acumulados.
- Como template de "definition of done" para el equipo.

## Cuándo NO usarme

- Para evaluar la calidad del código → usá `spring-boot-review` / `react-mfe-review`.
- Para gestionar un incident activo → usá `incident-command`.

## Checklist completo

Usar `templates/release-readiness-checklist.md` para el registro formal.

### 1. Schema y migraciones (si aplica)

```
□ Las migraciones SQL son reversibles (o hay script de rollback documentado)
□ Las migraciones fueron revisadas con mariadb-migration-review
□ Si hay tablas heavy: revisadas con database-design-heavy-table
□ db-versioning-audit confirma que el versionado es correcto
□ Las migraciones corren en el environment de staging primero
```

### 2. Contrato de API (si hay cambios en endpoints)

```
□ openapi.yaml está actualizado
□ openapi-validator sin errores (warnings documentados si los hay)
□ No hay breaking changes — o si los hay:
  □ Nueva versión (v2) publicada
  □ Consumers notificados con al menos 90 días de anticipación
  □ Ambas versiones soportadas simultáneamente durante el período de migración
□ cross-team-impact identificó todos los consumers afectados
```

### 3. Tests

```
□ Tests unitarios corren sin fallas (CI verde)
□ Tests de integración corren sin fallas
□ Funcionalidad nueva tiene cobertura al menos en el happy path
□ Si hay bug fix: hay test que lo reproduce primero (y ahora pasa)
```

### 4. Changelog

```
□ CHANGELOG.md actualizado con entry para esta versión
□ El entry incluye: qué cambió, si hay breaking change, cómo migrar
□ La versión en el pom.xml / package.json refleja el cambio semántico
```

### 5. Feature flags (si aplica)

```
□ Feature nueva tiene flag de feature para rollout gradual
□ El flag está configurado en OFF por default en producción
□ Hay runbook para activar/desactivar el flag
```

### 6. Rollback plan

```
□ Rollback documentado: ¿cómo se hace? ¿cuánto tarda?
□ La migración SQL es compatible con la versión anterior del código (para poder rollback sin perder datos)
□ El equipo conoce el procedimiento de rollback
```

### 7. Alertas y monitoreo

```
□ Sentry está configurado para el servicio
□ Hay alertas configuradas para el behavior crítico nuevo
□ Se revisó la configuración del observability-blueprint
□ Métricas custom agregadas si aplica
```

### 8. Runbook (para cambios de alto riesgo)

```
□ Existe runbook en templates/incident-runbook.md para los escenarios de error más probables
□ El runbook tiene los comandos exactos para diagnosticar y resolver
```

### 9. Sign-off

```
□ Code review aprobado por al menos 1 peer
□ Tech lead aprobó si el cambio es de alto riesgo
□ QA / testing confirmó en staging si hay cambios de UX
```

## Criterios de Go / No-Go

**Go**: todos los ítems del 1 al 6 en ✅, o con justificación documentada de por qué el ítem no aplica.

**No-Go**: cualquier ítem marcado como ❌ sin justificación, especialmente:
- Migración SQL sin rollback plan
- Breaking change sin consumers notificados
- CI rojo

## Output

```
RELEASE READINESS — <servicio> <versión>
=========================================
Fecha: YYYY-MM-DD
Evaluado por: <nombre>

RESULTADO: ✅ GO / ❌ NO-GO

ÍTEMS OK
  ✅ Migraciones reversibles — script de rollback en scripts/rollback-v2.3.sql
  ✅ openapi.yaml actualizado y validado
  ✅ CI verde: 147 tests, 0 fallas
  ✅ CHANGELOG.md actualizado

ÍTEMS PENDIENTES (bloquean el deploy)
  ❌ Breaking change en /v1/siniestros/{id}: se removió el campo 'codigo_legacy'
     → ws-facturacion todavía lo consume. Notificar equipo de facturación.

ÍTEMS PENDIENTES (no bloquean pero documentar)
  ⚠️ Feature flag no configurado — se deployará activo desde el inicio. Riesgo aceptado.
  ⚠️ Sin runbook para el escenario de timeout de SATApp. Crear post-deploy.
```

## Límites

- Alpha: la integración con CI/CD (Jenkins) es manual — el skill no puede consultar el estado del pipeline.
- La evaluación depende de la información que el usuario provea sobre el estado de cada ítem.

## TODO para promover a beta

- [ ] 1 release real ejecutado usando este checklist
- [ ] Medir cuántos ítems estaban OK vs faltantes en el primer uso real
- [ ] Integrar con GitLab MCP para verificar CI status automáticamente
