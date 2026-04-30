# Prompt: Evaluación de Breaking Change

Usá este prompt antes de mergear un cambio que podría romper la compatibilidad con consumers existentes de una API.

---

## Cambio propuesto

**Servicio**: ___  
**Endpoint / recurso afectado**: ___  
**Descripción del cambio**: ___

---

## 1. ¿Es un breaking change?

### Cambios NON-BREAKING (se puede hacer en la versión actual)

- [ ] Agregar campo opcional al response
- [ ] Agregar query param opcional al request
- [ ] Agregar nuevo endpoint
- [ ] Cambiar mensaje de error (mismo status code)
- [ ] Optimización de performance sin cambio de contrato

### Cambios BREAKING (requieren nueva versión o coordinación previa)

- [ ] Eliminar campo del request o response
- [ ] Renombrar campo del request o response
- [ ] Cambiar tipo de campo (String → Integer, etc.)
- [ ] Hacer obligatorio un campo que era opcional
- [ ] Cambiar semántica de un campo (cambia lo que significa un valor)
- [ ] Cambiar método HTTP de un endpoint existente
- [ ] Cambiar el path de un endpoint existente
- [ ] Cambiar códigos HTTP retornados

**¿Es breaking?**: Sí / No / Requiere análisis

---

## 2. Consumers afectados

<!-- Usar cross-team-impact para identificarlos automáticamente -->

| Consumer | Usa el campo/endpoint afectado | Impacto |
|---|---|---|
| | | |

---

## 3. Plan si es breaking change

**Opción A — Versionado** (recomendado si hay consumers externos o múltiples equipos):
1. Mantener `/v1/` con el contrato actual
2. Publicar `/v2/` con el cambio
3. Notificar a todos los consumers con fecha límite de migración (mínimo 90 días)
4. Deprecar `/v1/` con header `Deprecation`
5. Remover `/v1/` una vez que todos migraron

**Opción B — Coordinación de deploy** (viable solo si todos los consumers son del mismo equipo):
1. Preparar los cambios en todos los consumers en branches separados
2. Deploy coordinado en el mismo día (o en ventana de bajo tráfico)
3. Rollback plan si alguno falla

**Opción elegida**: A / B  
**Justificación**: ___

---

## 4. Checklist pre-merge

```
□ Consumers identificados con cross-team-impact
□ Plan de migración comunicado a los teams owners de cada consumer
□ Fecha límite de migración definida (≥90 días desde la publicación de v2)
□ Header Deprecation agregado en /v1/ si aplica
□ openapi.yaml actualizado (ambas versiones documentadas)
□ openapi-validator sin errores en la versión nueva
□ Rollback plan documentado
```

---

## 5. Plantilla de notificación a consumers

```
Asunto: [GRV API] Breaking change en <servicio> — migración requerida antes de <fecha>

Hola equipo <X>,

Se planea introducir un cambio de compatibilidad en el endpoint:
  <MÉTODO> <PATH>

Cambio: <descripción del cambio>

La nueva versión estará disponible en: <MÉTODO> <PATH v2>
La versión actual (v1) seguirá disponible hasta: <fecha>

Acción requerida por tu parte:
  Actualizar <nombre del consumer> para usar la versión v2 antes de <fecha>

¿Tenés preguntas? Contactar a <owner del servicio>.
```
