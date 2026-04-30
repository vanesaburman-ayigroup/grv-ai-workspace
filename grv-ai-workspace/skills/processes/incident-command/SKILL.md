---
name: incident-command
version: v1
maturity: alpha
owner: "[OWNER_NAME]"
category: processes
related_skills: [deploy-post-mortem, release-readiness, cross-team-impact, observability-blueprint]
related_agents: [grv-tech-lead]
triggers:
  - "tenemos un incident"
  - "hay un problema en prod"
  - "qué hago ahora"
  - "servicio caído"
  - "usuarios reportando errores"
  - "incident activo"
---

# Skill: incident-command

## Propósito

Playbook para gestionar un incident **activo** en producción. No reemplaza al post-mortem (`deploy-post-mortem`) — ese viene después. Este skill cubre los primeros minutos y horas del incident: qué verificar, cuándo rollback vs rollforward, cómo comunicar.

## Cuándo usarme

- Hay un error en producción con impacto a usuarios.
- Hay alertas activas (Sentry, monitoreo) que indican problema.
- El equipo no sabe qué hacer primero.

## Cuándo NO usarme

- El incident ya está resuelto → usá `deploy-post-mortem` para el análisis.
- Es un ambiente de staging/dev → el proceso de incident no aplica allí.

## Los primeros 5 minutos

Antes de cualquier cambio, evaluar:

```
1. ¿Está caído completamente o es degradación parcial?
   - Caído total: prioridad máxima, rollback si hay opción
   - Degradación parcial: investigar antes de actuar

2. ¿Cuándo empezó? ¿Coincide con algún deploy reciente?
   → Revisar: último deploy en Jenkins, última migración SQL aplicada

3. ¿Cuántos usuarios están afectados?
   → Revisar Sentry: ¿cuántos eventos por minuto? ¿es un usuario específico o todos?

4. ¿Hay error específico en Sentry o en los logs?
   → Copiar el stack trace antes de hacer cualquier cambio

5. ¿El problema está en el frontend, backend, o BD?
   → Si la API devuelve 500: backend. Si la API está bien y el UI roto: frontend.
```

## Roles en el incident

| Rol | Responsabilidad |
|---|---|
| **Incident Commander** | Coordina, toma decisiones, autoriza cambios. No escribe código. |
| **Investigador técnico** | Diagnostica la causa. Lee logs, ejecuta queries, revisa el código. |
| **Comunicador** | Notifica a stakeholders internos y externos. Escribe las actualizaciones de estado. |

En equipos pequeños una persona puede tener múltiples roles, pero el Incident Commander siempre debe ser alguien diferente del que está debugging — evita el tunnel vision.

## Árbol de decisión: rollback vs rollforward

### Rollback inmediato si:
- El incident empezó justo después de un deploy
- La causa es conocida (bug obvio, migración mala)
- El rollback se puede hacer en < 5 minutos
- El impacto es crítico (usuarios no pueden operar)

### Rollforward (fix en caliente) si:
- La migración SQL no es reversible sin pérdida de datos
- El rollback rompería algo diferente
- El fix es simple y hay alta confianza de que resuelve

### Investigar antes de decidir si:
- No coincide con un deploy reciente
- El impacto es parcial (no todos los usuarios afectados)
- La causa es desconocida

## Procedimiento de rollback en GRV

```
1. Identificar el último deploy estable en Jenkins
2. Deployar la versión anterior del servicio (Jenkins: "Deploy build anterior")
3. Si hay migración SQL: el código anterior debe ser compatible con el schema actual
   (razón por la que las migraciones deben ser siempre backward compatible)
4. Verificar que los errores en Sentry se detuvieron
5. Confirmar con el Comunicador que se informa a stakeholders
```

## Mitigación parcial (cuando no hay rollback posible)

Si el rollback no es opción y el fix va a demorar:
- **Feature flag OFF**: si la feature afectada tiene flag, desactivarla
- **Rate limiting**: si el problema es sobrecarga, configurar rate limit temporalmente
- **Redirect**: si un endpoint específico está roto, retornar error claro en lugar de 500 genérico
- **Comunicación proactiva**: mejor decirle al usuario "esta función no está disponible" que dejar que falle silenciosamente

## Comunicación durante el incident

### A stakeholders internos (cada 15-30 minutos):

```
[HH:MM] Incident en curso — <servicio>
Estado: Investigando / Mitigando / Resuelto
Impacto: <qué funcionalidad está afectada, cuántos usuarios>
Última acción: <qué se hizo en los últimos 15 min>
Próxima actualización: HH:MM
```

### A stakeholders externos (cuando el impacto es visible al cliente):

Consultar con el equipo antes de comunicar externamente. Mensaje simple, sin jerga técnica.

## Registro del timeline (alimenta el post-mortem)

Durante el incident, registrar en un doc compartido:
- HH:MM — primer alerta / primer reporte de usuario
- HH:MM — equipo notificado
- HH:MM — causa identificada: [descripción]
- HH:MM — acción tomada: [rollback / fix / mitigación]
- HH:MM — incident resuelto, usuarios impactados: N

## Post-incident (al resolverse)

1. Cerrar el incident formalmente: confirmar que Sentry está en verde
2. Notificación de resolución a todos los stakeholders
3. Programar post-mortem en las próximas 24-48 horas
4. Usar `deploy-post-mortem` para el análisis

## Límites

- Alpha: sin integración con herramienta de incident management (PagerDuty, OpsGenie).
- El skill no puede acceder a Jenkins, Sentry ni los logs directamente — el equipo debe proveer esa información.
- El árbol de decisión es orientativo; el Incident Commander tiene la autoridad final.

## TODO para promover a beta

- [ ] Usado en 1 incident real y retroalimentación incorporada
- [ ] Agregar contacts de escalamiento a `context/team.yaml`
- [ ] Integrar con Sentry MCP cuando esté disponible
