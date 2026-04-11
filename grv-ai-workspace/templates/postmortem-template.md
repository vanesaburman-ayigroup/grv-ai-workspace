# Post-Mortem — <Título del incidente>

**Fecha del incidente**: YYYY-MM-DD
**Duración**: <minutos/horas>
**Severidad**: P0 | P1 | P2 | P3
**Servicios afectados**: <lista>
**Escrito por**: <nombres>

> Este post-mortem es **blameless**. El objetivo es aprender del sistema,
> no buscar culpables. Si una persona cometió un error, lo que queremos
> entender es qué salvaguarda del sistema no lo atrapó.

## 1. Qué pasó

Descripción en prosa del incidente. Hechos observables, sin interpretación.
Qué se vio, cuándo, por cuánto tiempo.

## 2. Impacto

- **Usuarios afectados**: <estimación>
- **Operaciones perdidas o degradadas**: <ej. denuncias no registradas>
- **Duración visible para el usuario**: <HH:MM>
- **Datos perdidos o corruptos**: <sí/no, detalle>
- **Costo estimado** (si aplica): <...>

## 3. Timeline

Minuto a minuto si los datos permiten. Incluir eventos externos (deploys,
alertas, acciones del equipo).

| Hora (AR) | Evento | Fuente |
|-----------|--------|--------|
| HH:MM     | Deploy de <servicio> aplicado | CI/CD |
| HH:MM     | Primer error observado en Sentry | Sentry |
| HH:MM     | Detectado por <quién> | <cómo> |
| HH:MM     | Primera mitigación intentada: <qué> | <quién> |
| HH:MM     | Mitigación exitosa | |
| HH:MM     | Rollback ejecutado | |
| HH:MM     | Servicio restaurado | |

## 4. Detección

- **¿Cómo lo detectamos?**: <alerta automática | reporte de usuario | monitoreo manual>
- **¿Cuánto tardamos en detectarlo?**: <minutos desde el evento>
- **¿La detección fue suficiente?**: <sí/no, qué faltó>

## 5. Mitigación

- **Qué hicimos**: ...
- **¿Cuánto tardamos en mitigar?**: ...
- **¿Fue la primera acción intentada?**: <sí/no, qué se intentó antes>

## 6. Root cause

### Causa directa
¿Qué línea de código / config / dato hizo fallar al sistema?

### Causa raíz
¿Por qué esa línea llegó a producción? ¿Qué falló en el proceso que
debería haberlo atrapado? (Review, tests, canary, alertas, ADR...)

### Factores contribuyentes
Otras cosas que empeoraron el incidente o demoraron la resolución.

## 7. ¿Qué salió bien?

Cosas que funcionaron. No todo es para flagelarse. La detección rápida,
la comunicación del equipo, el rollback exitoso, todo cuenta.

## 8. ¿Qué no salió bien?

Cosas que fallaron o fueron más lentas de lo deseable.

## 9. Acciones correctivas

| # | Acción | Responsable | Fecha | Estado |
|---|--------|-------------|-------|--------|
| 1 | <acción concreta> | <nombre> | YYYY-MM-DD | abierta |
| 2 | ... | ... | ... | ... |

Reglas:
- Toda acción debe tener dueño y fecha.
- "Ser más cuidadoso" no es una acción — es un deseo.
- Mejor 3 acciones concretas que 10 vagas.

## 10. Referencias

- Ticket de incidente: ...
- MR(s) sospechoso(s): ...
- Link a logs: ...
- Link a Sentry: ...
- Reunión de post-mortem: <link Granola>
