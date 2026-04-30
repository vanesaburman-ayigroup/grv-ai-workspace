---
name: mariadb-migration-review
version: v1
maturity: beta
owner: "[OWNER_NAME]"
category: engineering
related_skills: [grv-arquitectura-plataforma, grv-bugs-conocidos, db-versioning-audit]
related_agents: [grv-migration-guard]
triggers:
  - "usuario pide revisar una migración SQL"
  - "aparece un archivo SQL en db/migration/ en el diff"
  - "usuario dice 'voy a tocar la BD' o 'agregué una columna'"
---

# Skill: mariadb-migration-review

## Propósito

Revisar migraciones SQL antes del commit/merge con un checklist exhaustivo
orientado a la realidad de la plataforma de GRV: AWS RDS MariaDB/MySQL,
30+ servicios compartiendo recursos, tablas críticas sensibles a lock wait,
histórico de migraciones heterogéneas por historia del proyecto.

## Fuente de verdad

- `context/microservices.yaml` — para identificar servicios impactados y sus tablas críticas.
- `context/heavy-tables.yaml` — tablas donde cualquier operación requiere cuidado extra.
- `context/known-bugs.yaml` — para cruzar con bugs conocidos (ej: lock wait en `auditoria_facturacion_log`).

**Nota importante**: no usamos Flyway. El proceso exacto de aplicación de
migraciones está pendiente de documentar en `CLAUDE.md` → `[TODO]`. Mientras
tanto, este skill revisa el SQL por mérito propio, no asume un runner
específico.

## Cuándo usarme

- Review de cualquier archivo SQL que vaya a cambiar schema o datos.
- Antes de un commit que modifica archivos en carpetas de migración.
- Al diseñar una migración compleja y querer validar el plan antes de escribirla.

## Cuándo NO usarme

- Para queries de consulta (SELECT) — ese es trabajo del MCP de MariaDB dev.
- Para stored procedures o triggers complejos — ese es otro review (crear skill si hace falta).
- Para cambios de infraestructura de RDS (parámetros, versiones, replicas) — eso es dominio de devops.

## Información que pido antes de revisar

1. **El archivo SQL completo** (contenido, no solo el path).
2. **Servicio al que pertenece** (para consultar `microservices.yaml` y ver impacto en tablas críticas).
3. **¿Cuál es el objetivo de negocio del cambio?** Sin esto no puedo evaluar si el cambio es el correcto — solo si es seguro.
4. **¿Se aplicó en dev ya? ¿Con qué resultado?** Si ya corrió en dev, sé que sintácticamente funciona.
5. **¿Hay ventana de mantenimiento prevista para prod?** Algunas migraciones no pueden correr en caliente.

Si falta info crítica, pido antes de proceder.

## Checklist (el corazón del skill)

Voy sección por sección. Cualquier ítem que no aplica, lo marco como N/A.

### 1. Seguridad estructural

- [ ] **Nombre del archivo**: sigue la convención del repo del servicio (secuencia, prefijo, descripción). *[TODO: documentar convención exacta en `CLAUDE.md`.]*
- [ ] **Idempotencia**: usa `IF NOT EXISTS`, `IF EXISTS`, `CREATE ... IF NOT EXISTS` donde corresponda. Correrla dos veces no debe romper nada.
- [ ] **Motor de tabla**: `ENGINE=InnoDB` explícito. Nunca MyISAM para tablas nuevas (aunque existan legacy). *Si el servicio trabaja contra tablas MyISAM existentes, alertar.*
- [ ] **Charset y collation**: declarado explícitamente si crea tabla (`utf8mb4 / utf8mb4_unicode_ci`).
- [ ] **PK definida**: toda tabla nueva tiene PK. Preferentemente `BIGINT AUTO_INCREMENT` o `UUID` según convención del servicio.

### 2. Performance e impacto en prod

- [ ] **Tamaño estimado de la tabla afectada**: si es una `heavy-table` (ver YAML), alerta de alto impacto.
- [ ] **ALTER sobre tabla grande**: si es ALTER sobre tabla con muchos registros, evaluar `ALGORITHM=INPLACE, LOCK=NONE` o alternativas (pt-online-schema-change, gh-ost, shadow table).
- [ ] **Índices nuevos**: crear índices sobre tablas grandes bloquea. Evaluar timing y estrategia.
- [ ] **Índices redundantes o duplicados**: no crear un índice que ya está cubierto por otro.
- [ ] **Foreign keys**: ¿las necesitamos? Evaluar costo vs beneficio; en tablas de alta escritura a veces son un problema.
- [ ] **DEFAULT en columnas nuevas**: si agrega columna NOT NULL sin DEFAULT a tabla grande, la migración se rompe o tarda horas. Exigir DEFAULT o hacer el cambio en dos pasos.

### 3. Consistencia y rollback

- [ ] **DML de backfill**: si la migración popula datos, ¿es idempotente? ¿Es seguro re-correrla?
- [ ] **Transaccionalidad**: MariaDB/MySQL no hace DDL transaccional. Si la migración mezcla DDL + DML y falla a la mitad, queda estado inconsistente. Separar en archivos distintos.
- [ ] **Rollback plan**: el autor tiene claro qué hacer si falla en prod. Preferir migraciones reversibles.
- [ ] **Backup previo**: para cambios irreversibles (DROP, modificación de tipos), exigir backup explícito de la tabla afectada.

### 4. Compatibilidad con código vivo

- [ ] **Backward compatibility**: durante el deploy, el código viejo y el nuevo conviven. La migración no puede romper al código viejo.
  - Agregar columna `NOT NULL` sin DEFAULT ⇒ rompe el INSERT del código viejo.
  - Eliminar columna ⇒ rompe el SELECT del código viejo.
  - Renombrar columna ⇒ rompe ambos. Hacer en dos migraciones: (1) agregar nueva + copiar, (2) eliminar vieja después del deploy.
- [ ] **Nullable vs NOT NULL**: ¿el código de la app maneja bien el NULL? Si es columna nueva NOT NULL con DEFAULT, el código debe saberlo.

### 5. Impacto cruzado (multi-servicio)

- [ ] **Servicios consumers**: ¿qué otros servicios leen/escriben esta tabla? Cruzar con `microservices.yaml`. Una migración en `wssiniestralidad` que toca `datos_denuncia_srt_logs` afecta a muchos.
- [ ] **Tablas compartidas**: casos como `auditoria_facturacion_log` (compartida entre `wsauditoriafacturacion` y `wsauditoriatraslados`) requieren coordinación. Ver `bug-lock-wait-auditoria` en `known-bugs.yaml`.
- [ ] **Hikari pool**: si la migración introduce queries lentas, puede agotar el pool. Evaluar timing.

#### Checklist adicional para `auditoria_facturacion_log`

Esta tabla tiene historial de lock wait en producción (ver `bug-lock-wait-auditoria` en `known-bugs.yaml`). Cualquier migración que la toque requiere:

- [ ] `ALGORITHM=INPLACE, LOCK=NONE` verificado en dev antes de aplicar (y confirmado que la versión de MariaDB lo soporta para este tipo de cambio)
- [ ] El cambio no introduce nueva escritura en el INSERT path principal (si hay INSERT frecuente + lock = desastre)
- [ ] Revisado con `database-design-heavy-table` para la estrategia de cambio
- [ ] Coordinación con el equipo owner de `wsauditoriafacturacion` (son consumers de esta tabla)
- [ ] Ventana de mantenimiento recomendada si el cambio no es online
- [ ] Plan de rollback específico para esta tabla documentado antes del deploy

### 6. PII y datos sensibles

- [ ] **¿Toca columnas con PII?** (DNI, nombre, dirección, historia clínica). Si sí, extra cuidado con backups y logs.
- [ ] **¿Loguea datos reales en comentarios/output?** No commitear ejemplos con datos de producción.

### 7. Linting y style

- [ ] **Statements terminados con `;`**.
- [ ] **Identificadores consistentes con el resto del schema del servicio** (snake_case, mayúsculas/minúsculas).
- [ ] **Sin `SELECT *`** en migraciones (explicitar columnas).
- [ ] **Comentarios** que expliquen el "por qué", no solo el "qué".

## Flujo del skill

1. Pedir el archivo completo + información contextual (sección "Información que pido").
2. Identificar el servicio y consultar `context/microservices.yaml` para ver si la tabla es crítica.
3. Cruzar con `context/heavy-tables.yaml` para evaluar impacto en prod.
4. Ejecutar el checklist sección por sección.
5. Generar reporte: verde / amarillo / rojo por sección + recomendaciones priorizadas.
6. Si el usuario pide más profundidad en algún ítem, expandir.

## Output

```
===========================================================
MIGRATION REVIEW — <nombre del archivo>
Servicio: <servicio>
Fecha: <fecha>
===========================================================

RESUMEN
  Status general: [🟢 OK | 🟡 OK con observaciones | 🔴 NO mergear sin cambios]
  Riesgo para prod: [bajo | medio | alto]

CHECKLIST

1. Seguridad estructural .......... 🟢 / 🟡 / 🔴
   [notas específicas]

2. Performance e impacto .......... 🟢 / 🟡 / 🔴
   [notas específicas]

3. Consistencia y rollback ........ 🟢 / 🟡 / 🔴
   [notas específicas]

4. Compatibilidad con código ...... 🟢 / 🟡 / 🔴
   [notas específicas]

5. Impacto cruzado (multi-servicio) 🟢 / 🟡 / 🔴
   [notas específicas]

6. PII y datos sensibles .......... 🟢 / 🟡 / 🔴
   [notas específicas]

7. Linting y style ................ 🟢 / 🟡 / 🔴
   [notas específicas]

BUGS CONOCIDOS POTENCIALMENTE RELACIONADOS
  [lista con ids o "ninguno"]

RECOMENDACIONES PRIORIZADAS
  1. [crítica]
  2. [importante]
  3. [opcional]

PREGUNTAS AL AUTOR
  [cosas que no pude evaluar sin más contexto]
```

## Ejemplo

**Usuario**: Revisame esta migración:
```sql
ALTER TABLE siniestros ADD COLUMN origen_canal VARCHAR(50) NOT NULL;
```

**Respuesta**:
```
Antes de revisar, necesito confirmarte tres cosas:

1. ¿A qué servicio pertenece esta migración? (asumo wssiniestralidad
   pero confirmame.)

2. ¿Cuál es el objetivo de negocio? (¿nueva feature de tracking?
   ¿refactor?)

3. ¿Ya corrió en dev? ¿Con qué resultado?

Mientras tanto, te adelanto dos observaciones críticas sin contexto
adicional:

🔴 COMPATIBILIDAD CON CÓDIGO VIVO
   ADD COLUMN NOT NULL sin DEFAULT rompe los INSERT del código actual
   durante el deploy. El código viejo no sabe de esta columna y va a
   fallar al insertar.
   Fix: agregar DEFAULT, o hacer en dos pasos (nullable primero, backfill,
   después NOT NULL).

🔴 TABLA HEAVY
   `siniestros` está en context/heavy-tables.yaml como tabla con cientos
   de miles de filas. ADD COLUMN NOT NULL sobre tabla grande puede
   tardar minutos y bloquear escrituras durante el ALTER.
   Fix: ALGORITHM=INPLACE, LOCK=NONE (si la versión de MariaDB lo permite)
   o usar herramienta online schema change.

No mergear esto sin revisar. ¿Seguimos cuando me des el contexto de
las 3 preguntas?
```

## Límites

- No reemplaza la ejecución real en un ambiente de staging.
- No conoce herramientas de aplicación de migraciones que no sean SQL puro
  (pendiente de documentar la herramienta que usa AYI).
- No valida semánticamente el cambio (si lo que hace es correcto de negocio);
  eso es responsabilidad del autor y del reviewer humano.
