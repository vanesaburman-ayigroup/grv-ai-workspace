# Incident Runbook

**Escenario**: <!-- nombre descriptivo del escenario de error -->  
**Servicio afectado**: <!-- nombre del servicio -->  
**Versión**: <!-- versión del runbook, ej: v1 -->  
**Última revisión**: <!-- YYYY-MM-DD -->  
**Owner**: <!-- equipo responsable -->

---

## Síntomas observables

<!-- Cómo se manifiesta el problema para el usuario / para el monitoreo:
- "Los usuarios reciben error 500 al acceder a /v1/siniestros/{id}"
- "Sentry muestra NullPointerException en PrestacionService cada 5 minutos"
- "La cola SQS de ws-notificaciones está creciendo (más de 1000 mensajes pendientes)" -->

---

## Servicios afectados

| Servicio | Impacto |
|---|---|
| <!-- nombre --> | <!-- descripción del impacto --> |

---

## Pasos de diagnóstico

### 1. Verificar el estado del servicio

```bash
# Health check del servicio
curl -s https://<host>/actuator/health | jq .

# Estado del pod / proceso
# TODO: agregar comando según infra GRV (Docker / Kubernetes)
```

### 2. Revisar Sentry

- Ir a Sentry → proyecto `<nombre>`
- Filtrar por los últimos 30 minutos
- Copiar el stack trace del error más reciente

### 3. Revisar los logs

```bash
# TODO: comando para ver logs del servicio en el entorno GRV
# Ejemplo: docker logs <container-name> --tail 100 | grep ERROR
```

Buscar en los logs:
- Mensajes de error o excepción
- El `siniestroId` o `traceId` del request que falla
- Timeout o connection refused a servicios externos

### 4. Verificar la base de datos (si aplica)

```sql
-- Verificar que la BD responde
SELECT 1;

-- Verificar conexiones activas
SHOW STATUS LIKE 'Threads_connected';

-- Ver queries lentos o bloqueados
SHOW PROCESSLIST;
```

Credenciales: usar el MCP de MariaDB dev (nunca credenciales prod en el chat).

### 5. Verificar integraciones externas (si aplica)

```bash
# TODO: endpoint de health de la integración afectada
# Ejemplo: curl -s https://satapp.grv.internal/health
```

---

## Acciones de mitigación

### Opción A: Rollback (si el problema empezó con un deploy reciente)

```
1. Identificar el último deploy estable en Jenkins
2. Deployar la versión anterior: <instrucciones específicas de Jenkins>
3. Verificar que Sentry deja de registrar el error
4. Notificar a stakeholders que el servicio volvió a la versión anterior
```

**Tiempo estimado**: <!-- ej: 5-10 minutos -->

### Opción B: Fix en caliente (si el rollback no es viable)

<!-- Describir los pasos para el fix específico de este escenario -->

### Opción C: Mitigación parcial (mientras se investiga)

```
# Desactivar el feature flag si aplica:
# TODO: instrucciones para desactivar el flag

# Retornar error claro en lugar de 500:
# TODO: configuración de feature flag o circuit breaker
```

---

## Rollback plan

**¿La migración SQL es reversible?**: Sí / No  
**Script de rollback**: `scripts/rollback-vX.Y.sql` / N/A  
**Impacto del rollback en datos**: <!-- ninguno / se pierden datos de X / requiere backfill -->

---

## Escalamiento

Si el problema no se resuelve en **15 minutos**:

| Tiempo | Acción |
|---|---|
| T+15min | Notificar a tech lead: <!-- contacto --> |
| T+30min | Escalamiento a: <!-- contacto --> |
| T+60min | Notificación a stakeholders: <!-- template de mensaje --> |

---

## Post-incident

Una vez resuelto:
1. Confirmar que Sentry está en verde
2. Notificar resolución a stakeholders
3. Programar post-mortem en las próximas 24-48 horas
4. Usar `deploy-post-mortem` skill para el análisis

---

## Historial de incidentes

| Fecha | Duración | Causa | Resuelto por |
|---|---|---|---|
| <!-- YYYY-MM-DD --> | <!-- X min --> | <!-- causa --> | <!-- nombre --> |
