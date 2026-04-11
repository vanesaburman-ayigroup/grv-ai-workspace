---
name: deploy-post-mortem
version: v1
maturity: alpha
owner: "[DEVOPS_REFERENT]"
category: processes
related_skills: [grv-bugs-conocidos, spring-boot-review, automation-finder]
related_agents: [grv-process-analyst]
triggers:
  - "usuario reporta incidente post-deploy"
  - "spike de errores en Sentry detectado"
  - "usuario pide 'armá el post-mortem de lo de ayer'"
---

# Skill: deploy-post-mortem

## Propósito

Armar un post-mortem estructurado cuando un deploy rompe algo en
producción. El skill **recolecta y correlaciona**; no busca culpables ni
concluye sin evidencia.

## Filosofía

Un post-mortem útil responde 5 preguntas:

1. **¿Qué pasó?** — hechos observables, sin interpretación.
2. **¿Por qué pasó?** — root cause, no síntoma.
3. **¿Cómo lo detectamos?** — y cuánto tardamos.
4. **¿Cómo lo mitigamos?** — y cuánto tardó.
5. **¿Cómo evitamos que vuelva a pasar?** — acciones concretas con dueño.

Las 5 preguntas son obligatorias; ninguna puede quedar en blanco. Si no
sabemos una, la marca del skill es "pendiente de investigar" y queda
como action item.

## Fuentes que correla

- **Sentry** — spikes de errores (via Sentry MCP si está conectado).
- **Logs** del servicio afectado (si están accesibles).
- **MRs mergeados** en la ventana del deploy.
- **Commits** del servicio en las últimas X horas.
- **Alertas** (Clarity, monitoring) en la ventana.
- **`context/known-bugs.yaml`** — ¿matchea con un pattern conocido?
- **Timeline de deploys** del servicio afectado.

## Cuándo usarme

- Después de un incidente, idealmente en las primeras 24h.
- Cuando el post-deploy spike de Sentry excede el threshold del equipo.
- Cuando el PM pide "¿qué pasó con el deploy de ayer?".

## Flujo

1. Pedir el evento: servicio afectado, ventana temporal aproximada,
   síntoma observado.
2. Consultar Sentry MCP (si está disponible) para cuantificar el impacto
   y obtener stack traces.
3. Consultar los MRs mergeados al servicio en las ~24h previas al incidente.
4. Cruzar con `known-bugs.yaml` — ¿pattern conocido?
5. Generar timeline detallada (minuto a minuto si los datos permiten).
6. Proponer hipótesis de root cause con evidencia que la sustenta.
7. Armar el reporte siguiendo el template.
8. Listar las cosas que **no pudimos** determinar con la info disponible.

## Regla importante

**Este skill no asigna culpa**. El reporte es sobre el sistema, no sobre
las personas. Si una persona cometió un error, lo que se documenta es
**qué salvaguarda del sistema falló al no atraparlo**, no quién tipeó.

## Output

Ver `templates/postmortem-template.md`. El skill lo completa.

## Ejemplo (fragmento)

**Usuario**: Ayer después del deploy de wsturnos empezaron a aparecer
errores de NullPointerException en Sentry. Empezó a las 15:30 y duró
hasta que hicimos rollback 17:00.

**Respuesta**:
```
Recolectando info para el post-mortem.

TIMELINE (preliminar, a completar con tu ayuda)
  15:15 (aprox) — Deploy de wsturnos aplicado a prod.
                  MR: [a identificar — lo busco en git log]
  15:30 — Primer NPE en Sentry. [a verificar volumen]
  15:xx — ¿Cómo lo detectamos? ¿Alerta, usuario reportó, dashboard?
  16:xx — ¿Primera mitigación intentada? ¿Cuál?
  17:00 — Rollback ejecutado. ¿Quién lo corrió? ¿Fue automático?

Preguntas que necesito responder para cerrar el post-mortem:

1. ¿Qué MR se mergeó justo antes del deploy? ¿Hay solo uno o varios?
2. ¿Tenemos el stack trace completo del NPE? (Busco en Sentry si me
   confirmás que puedo usar el MCP de Sentry.)
3. ¿Cómo se detectó el problema? (Tiempo a detección es métrica clave.)
4. ¿Hubo alguna alerta automática o lo vieron los usuarios primero?
5. Después del rollback, ¿quedó algún dato inconsistente en BD?

Mientras tanto, una hipótesis inicial (baja confianza, a validar):
el NPE pudo haber sido una columna nueva que el código asume no-null
pero que tiene filas legacy en null. Patrón conocido — matchea
parcialmente con bug-booltosn-null en context/known-bugs.yaml.

Apenas me respondas las preguntas, completo el post-mortem en formato
templates/postmortem-template.md.
```

## Límites

- **Alpha**: depende de que Sentry MCP esté conectado y autenticado.
  Sin eso, el skill recolecta manualmente lo que el usuario aporta.
- No reemplaza una reunión de post-mortem con el equipo. Es insumo
  para esa reunión.
- No detecta root causes profundos sin acceso a logs detallados.

## TODO para promover a beta

- [ ] Integración estable con Sentry MCP
- [ ] Correlación automática con GitLab (MRs mergeados en ventana)
- [ ] Primer post-mortem real documentado en `docs/case-studies/`
