---
name: database-design-heavy-table
version: v1
maturity: alpha
owner: "[OWNER_NAME]"
category: engineering
related_skills: [mariadb-migration-review, architecture-patterns, db-versioning-audit]
related_agents: [grv-architect, grv-migration-guard]
triggers:
  - "agregar columna a siniestros"
  - "índice en tabla heavy"
  - "cambio en auditoria_facturacion_log"
  - "cómo modifico una tabla con millones de filas"
  - "ALTER TABLE sin lock"
  - "migration en tabla grande"
---

# Skill: database-design-heavy-table

## Propósito

Estrategia especialista para cambios de schema en las tablas heavy de GRV — aquellas con millones de filas donde un `ALTER TABLE` estándar puede bloquear la tabla durante minutos u horas en producción.

## Tablas heavy conocidas

De `context/heavy-tables.yaml`:

- `siniestros` — tabla principal, crecimiento continuo
- `datos_denuncia_srt_logs` — logs de envíos SRT, muy alta frecuencia de escritura
- `auditoria_facturacion_log` — auditoría de facturación, compartida entre servicios

Ante cualquier cambio en estas tablas, usar este skill primero.

## Información requerida antes de proponer estrategia

Preguntar siempre:
1. ¿Cuántas filas tiene la tabla aproximadamente? (orden de magnitud: miles, millones, decenas de millones)
2. ¿Cuál es la versión exacta de MariaDB? (`SELECT VERSION()`)
3. ¿Hay ventana de mantenimiento disponible?
4. ¿La operación necesita ser online (sin downtime) o se puede hacer con mantenimiento?
5. ¿gh-ost está disponible en el entorno?

## Estrategias por tipo de cambio

### Agregar columna nullable

**La más segura**: MariaDB InnoDB soporta online DDL para columnas nullable en versiones recientes.

```sql
ALTER TABLE siniestros
  ADD COLUMN estado_ampliado VARCHAR(50) NULL
  ALGORITHM=INPLACE, LOCK=NONE;
```

**Verificar**: `ALGORITHM=INPLACE, LOCK=NONE` falla con error si no es soportado — en ese caso MariaDB te avisa antes de ejecutar.

Riesgo bajo. Usar `mariadb-migration-review` para el script final.

### Agregar columna NOT NULL con valor default

**Requiere strategy**:

Opción A — Online DDL con default (MariaDB 10.3+):
```sql
ALTER TABLE siniestros
  ADD COLUMN fuente_denuncia VARCHAR(20) NOT NULL DEFAULT 'MANUAL'
  ALGORITHM=INPLACE, LOCK=NONE;
```
Si la tabla es InnoDB y la versión lo soporta, es la opción más simple.

Opción B — Shadow column + backfill (para defaults no triviales):
1. Agregar columna nullable primero (INPLACE)
2. Backfill por batches (UPDATE con LIMIT para no bloquear):
   ```sql
   UPDATE siniestros SET fuente_denuncia = 'MANUAL' WHERE fuente_denuncia IS NULL LIMIT 5000;
   -- Repetir hasta que no haya más NULLs
   ```
3. Agregar constraint NOT NULL una vez que no hay NULLs

### Agregar índice

Online en InnoDB:
```sql
CREATE INDEX idx_siniestros_fecha_accidente ON siniestros (fecha_accidente)
  ALGORITHM=INPLACE, LOCK=NONE;
```

**Atención**: aunque es online, el build del índice consume IO. Hacerlo en horario de bajo tráfico.

Índice en columna con alta cardinalidad baja (ej: `tipo_siniestro` con 3 valores): evaluar si el índice realmente ayuda. Para low-cardinality puede ser más lento.

### Remover columna

**Nunca directo en producción sin deprecación previa**:

1. **Deprecar**: dejar de escribir en la columna desde el código (sin tocar la BD todavía)
2. **Esperar un ciclo de deploy completo**: verificar que nada lea la columna
3. **Remover la columna**: puede hacerse con `ALGORITHM=INPLACE` en InnoDB

Si la columna tiene un índice, remover el índice primero.

### Cambiar tipo de columna

**Casi siempre requiere tabla shadow** (el alter no es online para cambios de tipo):

1. Crear nueva columna con el nuevo tipo: `fuente_denuncia_v2 TEXT`
2. Dual write: el código escribe en ambas columnas
3. Backfill de los datos existentes (por batches)
4. Migrar lecturas a la nueva columna
5. Dejar de escribir en la vieja
6. Renombrar: `ALTER TABLE ... RENAME COLUMN fuente_denuncia TO fuente_denuncia_old, RENAME COLUMN fuente_denuncia_v2 TO fuente_denuncia`
7. Remover la vieja en un deploy posterior

### Rename de columna

MariaDB soporta RENAME COLUMN como online DDL desde 10.5.2:
```sql
ALTER TABLE siniestros
  RENAME COLUMN fecha_denuncia TO fecha_registro
  ALGORITHM=INPLACE, LOCK=NONE;
```
Verificar versión antes de usar.

### gh-ost (cuando está disponible)

Para cambios que no son online con los mecanismos anteriores, gh-ost hace la migración en una tabla fantasma sin bloquear:

```bash
gh-ost \
  --host=<host> \
  --database=<db> \
  --table=siniestros \
  --alter="ADD COLUMN campo_nuevo VARCHAR(100) NOT NULL DEFAULT ''" \
  --execute
```

Requiere acceso a replicación. Confirmar disponibilidad con el equipo de ops.

## Checklist pre-migración en tabla heavy

```
□ Versión MariaDB confirmada
□ ALGORITHM=INPLACE, LOCK=NONE probado en dev primero
□ Script de backfill por batches si aplica (no UPDATE sin WHERE)
□ Rollback plan: ¿cómo se deshace si falla?
□ Ventana de mantenimiento o confirmación de que es online
□ Script revisado por grv-migration-guard
□ Plan de comunicación a equipos que usan la tabla
```

## Límites

- Alpha: los comandos exactos dependen de la versión MariaDB — siempre verificar en dev primero.
- No propone cambios en tablas MyISAM (legacy): para MyISAM no hay online DDL, requiere decisión de migrar el engine primero.
- La disponibilidad de gh-ost no está confirmada en el entorno GRV.

## TODO para promover a beta

- [ ] Confirmar versión exacta de MariaDB en prod (bloquea muchas decisiones)
- [ ] Confirmar disponibilidad de gh-ost
- [ ] Ejemplo real documentado: migración ejecutada en una de las tablas heavy
- [ ] Actualizar `context/heavy-tables.yaml` con datos de filas actualizados
