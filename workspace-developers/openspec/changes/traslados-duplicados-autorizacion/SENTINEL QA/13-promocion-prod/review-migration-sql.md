# Migration Review — INI-2 · Promoción a producción

**Archivo revisado:** `INI-2-promocion-produccion.sql` (1.492 líneas)
**Change:** `traslados-duplicados-autorizacion` — autorización de traslados duplicados del mismo día
**Base:** MariaDB 10.5 · esquema `cs` · SAS Colonia Suiza
**Servicios impactados:** `wsturnos`, `wslogistica`
**Skill aplicado:** `mariadb-migration-review`
**Modo:** sólo revisión — no se ejecutó ninguna sentencia del script y no se modificó el archivo.

---

## Veredicto

| | |
|---|---|
| **Status** | 🔴 **NO aplicar tal cual** |
| **Riesgo prod** | **Alto** |
| **Bloqueantes** | 2 |
| **Altas** | 5 |
| **Medias** | 6 |
| **Bajas** | 5 |

El script está muy por encima del promedio: la idempotencia está bien pensada, los `DELIMITER` están correctos, las FK son sanas y el razonamiento sobre el `MAX+1` es **correcto y lo verifiqué empíricamente**. Los dos bloqueantes no son errores de SQL: son (1) una **divergencia de esquema contra TEST** que el script introduce y que nunca se autocorrige, y (2) un **modo de falla del bloque 4** que deja los cuatro SP caídos en producción si la sesión que lo corre no tiene el `sql_mode` correcto.

### Checklist del skill

| # | Sección | Estado | Nota |
|---|---------|--------|------|
| 1 | Seguridad estructural | 🟡 | Idempotente y `ENGINE=InnoDB` explícito. Falta charset/collation explícito. PK correcta. |
| 2 | Performance e impacto en prod | 🔴 | `ALTER` sobre `traslados` (2 GB, 159 columnas) sin `ALGORITHM=INSTANT`: fallback silencioso a COPY. |
| 3 | Consistencia y rollback | 🔴 | El `COMMIT` comentado del bloque 3 no es un gate real: el DDL del bloque 4 lo confirma solo. Rollback incompleto. |
| 4 | Compatibilidad con código vivo | 🟢 | Orden BD→servicios correcto. Columnas nullable, sin `DROP`, sin renombres. El SP nuevo devuelve columnas de más, que Hibernate ignora. |
| 5 | Impacto cruzado | 🟡 | 4 SP compartidos entre `wsturnos` y `wslogistica`, con ventana de segundos sin procedure. Advertido, pero sin verificación de permisos previa. |
| 6 | PII / datos sensibles | 🟢 | No toca columnas con PII. Sin datos de producción en comentarios. |
| 7 | Linting y style | 🟡 | Dos bloques numerados «2». Cualificación de esquema inconsistente. |

---

## Contexto verificado en la base

Todo lo que sigue lo consulté con los conectores **read-only de DEV y TEST**. No se tocó producción.

| Objeto | DEV | TEST |
|---|---|---|
| `autorizaciones.id_autorizacion` | `int(11)` signed, PK, InnoDB, `latin1_swedish_ci` | — |
| `traslados.id_traslado` | `int(11)` signed, PK, auto_increment | — |
| `traslados_transporte_publico.id_traslado` | `int(11)` signed, **PK** | — |
| `traslados` | 1.406.525 filas · 2,0 GB datos · 0,85 GB índices · **159 columnas** · `ROW_FORMAT=Dynamic` | — |
| `traslados_transporte_publico` | 19.668 filas · `Dynamic` | — |
| `autorizaciones` | 1.872.029 filas | — |
| `turnos` | 4.518.706 filas | — |
| Default del esquema `cs` | `latin1` / `latin1_swedish_ci` | — |
| Versión | `10.5.29-MariaDB-log` | — |
| `id_permiso` de `autorizar_traslado_mismo_dia` | **1000** | **101** |
| `MAX(id_permiso)` | **1000** (`AUTO_INCREMENT=1001`) | **101** |
| Perfiles objetivo | `jefe_de_siniestros`=2, `referente_siniestros`=3 (existen) | — |
| `autorizaciones_traslado_duplicado` | existe, con **6 índices** | existe, con **6 índices** |

---

## BLOQUEANTES

### 🔴 B-1 — El `CREATE TABLE` omite `idx_atd_solicitante_visto`: producción quedaría con un esquema distinto al validado en TEST

**Bloquea la aplicación en producción: SÍ.**

DEV y TEST tienen este índice en `autorizaciones_traslado_duplicado`, y el script **no lo crea**:

```sql
KEY `idx_atd_solicitante_visto` (`id_solicitante`,`estado`,`fecha_visto_solicitante`)
```

Verificado en los dos ambientes bajos (`SHOW CREATE TABLE`, salidas idénticas en ese punto). El script declara sólo `idx_atd_estado`, `idx_atd_autorizacion` e `idx_atd_traslado`; el cuarto índice que aparece en DEV/TEST (`fk_atd_traslado_tp`) lo crea InnoDB solo para sostener la FK, así que ése no es problema. El que falta es el de solicitante.

No es un índice decorativo: es exactamente el que sirve la rama «mis duplicados resueltos» de `consulta_turnos_tramitadores_sp`, que en el propio script (líneas 592-593) arma:

```sql
AND ATD.id_solicitante = <id>
AND ATD.estado IN (2, 3)
```

Sin el índice, el optimizador queda con `idx_atd_estado` — tres valores distintos, selectividad nula — o con full scan de la tabla. Hoy la tabla arranca vacía y no se nota; con volumen de pedidos acumulados sí, y en el peor momento (la card del gestor se consulta en cada home).

**Por qué es bloqueante y no una simple observación:** por el `CREATE TABLE IF NOT EXISTS`. Una vez creada la tabla sin el índice, **una segunda corrida del script no lo agrega nunca**. El script es idempotente pero por eso mismo no autocorrige la omisión, y ninguna verificación del bloque 5 mira índices. Producción quedaría permanentemente con un esquema distinto del que se probó en TEST, en silencio.

**Corrección concreta.** El índice incluye `fecha_visto_solicitante`, que se agrega en el bloque 2 — así que **no puede ir dentro del `CREATE TABLE`**, tiene que ir después del `ALTER` del bloque 2, e idempotente:

```sql
-- Bloque 2, después del ADD COLUMN de fecha_visto_solicitante.
-- Sirve la rama «mis duplicados resueltos» de consulta_turnos_tramitadores_sp:
--   WHERE ATD.id_solicitante = ? AND ATD.estado IN (2,3)
-- y el contador de la card del solicitante, que filtra por fecha_visto_solicitante IS NULL.
ALTER TABLE cs.autorizaciones_traslado_duplicado
    ADD INDEX IF NOT EXISTS idx_atd_solicitante_visto
        (id_solicitante, estado, fecha_visto_solicitante);
```

La tabla está vacía en el momento de aplicarlo, así que el costo es cero.

---

### 🔴 B-2 — El bloque 4 recrea los 4 SP sin fijar `sql_mode`: si la sesión difiere, el `DROP` ya pasó y el `CREATE` falla

**Bloquea la aplicación en producción: SÍ.**

MariaDB **congela el `sql_mode` de la sesión dentro de la definición del procedure** en el momento del `CREATE`, y también lo usa para parsear el cuerpo. El script no fija ninguno, así que hereda lo que traiga el cliente del operador. Dos construcciones de estos cuerpos son sensibles a eso:

1. **`NO_BACKSLASH_ESCAPES`.** Línea 250:
   ```sql
   DECLARE comodin_like_inicio VARCHAR(3) DEFAULT '\'%';
   ```
   Con `NO_BACKSLASH_ESCAPES` activo, `'\'` deja de ser una comilla escapada y el literal se parte: error de sintaxis en el `CREATE`.

2. **`ANSI_QUOTES`.** Los cuerpos usan comillas dobles como literales de cadena y como alias:
   ```sql
   CONCAT(PS.nombre, " ", PS.apellido) as "solicitanteDuplicado"
   ```
   Con `ANSI_QUOTES`, `" "` pasa a ser un identificador. Acá es peor que un error de sintaxis: puede crear el procedure y **romper en la primera llamada real** — justo después de que el operador haya visto los 4 controles del bloque 4 en verde.

El modo de falla es el que importa: el `DROP PROCEDURE IF EXISTS` ya se ejecutó. Si el `CREATE` falla, **el procedure no existe** en producción, la grilla de logística y la de tramitadores quedan caídas, y la salida hay que reconstruirla a mano desde el respaldo del bloque 0.5 — que además tiene sus propios problemas (ver A-3).

**Corrección concreta.** Capturar el `sql_mode` original en el preflight y fijarlo antes del bloque 4:

```sql
-- 0.7 OBLIGATORIO — sql_mode y charset con que estan creados los 4 SP hoy.
--     Se replican en la sesion antes del bloque 4: MariaDB congela el sql_mode
--     dentro de la definicion y lo usa para parsear el cuerpo.
SELECT ROUTINE_NAME, SQL_MODE, CHARACTER_SET_CLIENT, COLLATION_CONNECTION, DEFINER, SECURITY_TYPE
  FROM information_schema.ROUTINES
 WHERE ROUTINE_SCHEMA = 'cs'
   AND ROUTINE_NAME IN ('consulta_turnos_tramitadores_sp',
                        'consulta_traslado_remis_amb_logistica',
                        'consulta_traslados_aereos_logistica',
                        'consulta_traslados_internos_logistica');
```

y al abrir el bloque 4:

```sql
-- Pegar aca EXACTAMENTE el SQL_MODE devuelto por 0.7. No dejar el default del cliente.
SET SESSION sql_mode = '<valor de 0.7>';
```

Recomendación adicional, barata: correr el bloque 4 en TEST desde **el mismo cliente y la misma cuenta** con que se va a correr en producción, antes de la ventana. Es la única forma de descartar B-2 y A-1 juntos sin adivinar.

---

## ALTAS

### 🟠 A-1 — `definer = admin@'%'` sin verificar quién ejecuta

**Bloquea: SÍ, si el operador no es `admin`.** No bloquea si lo es.

Los cuatro `CREATE` fijan ``DEFINER=`admin`@`%` ``. Para crear una rutina con un definer distinto del usuario actual hace falta `SUPER` (o `SET USER` en versiones recientes). En RDS el usuario maestro **no** tiene `SUPER`, así que esto funciona **sólo si la sesión es literalmente `admin@%`**. Si no, error 1227 — y otra vez, con el `DROP` ya hecho.

El preflight no verifica esto. Falta:

```sql
-- 0.8 Quien va a correr el bloque 4. Tiene que dar admin@% o el CREATE del bloque 4 falla
--     con error 1227 DESPUES del DROP, y los 4 SP quedan caidos.
SELECT CURRENT_USER() AS definer_efectivo, USER() AS conexion;
```

No cambiar el `DEFINER` a otro valor: los cuatro SP ya son `admin@%` y son `SQL SECURITY DEFINER`; cambiarlo altera los privilegios con que corren en runtime.

### 🟠 A-2 — El `COMMIT` comentado del bloque 3 no es un gate: el DDL del bloque 4 confirma la transacción solo

**Bloquea: NO** (el efecto neto es el correcto), **pero invalida el control** y hay que documentarlo.

El bloque 3 abre `START TRANSACTION`, y deja `COMMIT` / `ROLLBACK` comentados a propósito. Pero `DROP PROCEDURE` es DDL, y en MariaDB **el DDL hace commit implícito**. Si el operador corre el archivo de arriba a abajo:

1. Bloque 3 inserta y no confirma.
2. Bloque 4 arranca con `DROP PROCEDURE IF EXISTS` → **commitea el bloque 3**.
3. El operador cree que nada se confirmó y que todavía puede hacer `ROLLBACK`. No puede.

El script dice «NO confirmar a ciegas», que es lo correcto, pero no dice que a partir del bloque 4 el `ROLLBACK` del bloque 3 dejó de existir. Agregar al encabezado del bloque 4:

```
--  ATENCION: este bloque es DDL y hace COMMIT IMPLICITO. Si el bloque 3 quedo abierto sin
--  confirmar, el primer DROP de aca lo CONFIRMA. Resolver el COMMIT/ROLLBACK del bloque 3
--  ANTES de entrar. A partir de esta linea el rollback del permiso es el bloque 6.1, no un ROLLBACK.
```

Y en el encabezado del archivo, explícito: **este script no se corre como archivo único**, se corre bloque por bloque leyendo cada control. El `DELIMITER` refuerza esto — es comando de cliente `mysql`/DBeaver y no existe por JDBC ni en muchos runners.

### 🟠 A-3 — El respaldo del bloque 0.5 no es restaurable tal como se captura

**Bloquea: NO, pero es el único rollback del bloque 4**, así que la exposición es alta.

`SHOW CREATE PROCEDURE` tiene tres problemas para este uso:

- La salida **no trae `DELIMITER`**. Para volver atrás hay que re-envolverla a mano, bajo presión de incidente, con cuerpos de 400+ líneas.
- Muchos clientes **truncan** la columna `Create Procedure` (es `LONGTEXT`); el CLI de `mysql` la corta según ancho de terminal si no se usa `-B`/`--raw`. Un respaldo truncado es peor que no tener respaldo, porque parece existir.
- El `sql_mode` viene en columna aparte y hay que aplicarlo antes de restaurar (ver B-2).

**Corrección concreta.** Reemplazar 0.5 por un dump real, fuera de la sesión SQL:

```bash
mysqldump -h <host> -u admin -p --no-data --no-create-info --routines \
  --skip-triggers --skip-events cs \
  > backup-sp-cs-$(date +%Y%m%d-%H%M).sql
```

Ese archivo ya trae `DELIMITER`, `DEFINER` y el `sql_mode` de cada rutina, y se restaura con `mysql < archivo`. Dejar el `SHOW CREATE PROCEDURE` como control visual, no como respaldo.

### 🟠 A-4 — `ALTER TABLE ... ADD COLUMN` sin `ALGORITHM` sobre `traslados` (2 GB, 159 columnas)

**Bloquea: NO, pero puede convertir «unos segundos» en varios minutos de escrituras bloqueadas.**

Buena noticia primero: en MariaDB 10.5, con `ROW_FORMAT=Dynamic` (verificado en las dos tablas) y agregando la columna **al final**, `ADD COLUMN` es *instant* — no copia la tabla. Los dos `ALTER` del bloque 2 cumplen las dos condiciones.

El problema es que el script **no lo pide explícitamente**. Sin `ALGORITHM=INSTANT`, MariaDB elige, y si por cualquier razón no puede hacerlo instant (tabla que quedó necesitando rebuild, límite de alteraciones instant acumuladas — `traslados` ya tiene 159 columnas y arrastra historia), **degrada en silencio a INPLACE o COPY**. Sobre 2 GB de datos y 0,85 GB de índices eso son minutos, con MDL exclusivo al entrar y al salir, y con `COPY` las escrituras quedan bloqueadas. En medio de la ventana, nadie va a distinguir «tarda» de «se colgó».

**Corrección concreta** — pedirlo explícito para que **falle rápido** en lugar de copiar:

```sql
ALTER TABLE cs.traslados
    ADD COLUMN IF NOT EXISTS es_duplicado_autorizado TINYINT(1) DEFAULT NULL
    COMMENT 'Segundo traslado del mismo dia con excepcion autorizada: no cancelar por duplicado',
    ALGORITHM = INSTANT;
```

Si eso falla, es información valiosa: significa que hay que planificar un online schema change y no seguir a ciegas. Idem para `traslados_transporte_publico` (19.668 filas — ahí el fallback es barato, pero conviene la simetría).

### 🟠 A-5 — El rollback del bloque 6 está incompleto en dos puntos

**Bloquea: NO la aplicación. Sí compromete la vuelta atrás.**

Lo que está bien: el orden es correcto (6.1 asignaciones → permiso, 6.2 columnas, 6.3 tabla); borrar `perfiles_permisos_sas` antes que `permisos_sas` respeta la FK `fk_permisos_perfiles_permisos` (verificada en DEV); el `DROP TABLE` no choca con nada porque ninguna tabla referencia a `autorizaciones_traslado_duplicado`; y advierte que hay que exportar antes de borrar.

Lo que falta:

1. **No dice que los servicios se revierten PRIMERO.** El script insiste, con razón, en que en la aplicación la base va antes que el despliegue. En el rollback el orden se invierte y no está escrito: si se corre 6.2/6.3 con el código nuevo todavía arriba, el código nuevo queda pegando contra columnas y tabla que ya no existen. Agregar como paso 6.0: revertir `wsturnos` y `wslogistica` a la versión anterior, y sólo después tocar la base.

2. **6.2 es mucho más caro que el apply, y se corre bajo presión.** `DROP COLUMN` sobre `traslados` (2 GB) no tiene la misma garantía de instantaneidad que el `ADD COLUMN` y puede reconstruir la tabla completa. Recomendación operativa: en un rollback de emergencia **no ejecutar 6.2**. La columna es nullable, está en `NULL` en todas las filas y ningún código viejo la mira: dejarla es inocuo y se limpia después en una ventana propia. Dejarlo escrito en el bloque, porque en el momento nadie lo va a razonar.

---

## MEDIAS

### 🟡 M-1 — La tabla nueva no declara charset ni collation

**Bloquea: NO. Verificar antes de la ventana.**

El `CREATE TABLE` no trae `DEFAULT CHARSET` / `COLLATE`, así que hereda el default del esquema. En DEV eso es `latin1` / `latin1_swedish_ci` (verificado: `@@character_set_database = latin1`), y por eso la tabla en DEV y TEST quedó `latin1_swedish_ci`, igual que el resto del esquema.

El riesgo es que el default del esquema `cs` **en producción** no sea el mismo. Si fuera `utf8mb4`, la tabla se crearía con otro charset que DEV/TEST, y `justificacion` / `dictamen` (`VARCHAR(1000)`) podrían disparar *illegal mix of collations* al concatenarse o compararse con columnas `latin1` en el SQL dinámico de los SP. Es un error en runtime, no en la migración: aparecería después.

**Corrección:** declararlo explícito, que además es lo que pide el checklist del skill:

```sql
) ENGINE = InnoDB DEFAULT CHARSET = latin1 COLLATE = latin1_swedish_ci;
```

Sí, `latin1` y no `utf8mb4`: acá la prioridad es paridad con el esquema existente. Migrar el charset es otro change. Y agregar al preflight:

```sql
-- 0.9 Default de charset del esquema. Tiene que dar latin1 / latin1_swedish_ci,
--     igual que DEV y TEST.
SELECT @@character_set_database AS cs_db, @@collation_database AS coll_db;
```

### 🟡 M-2 — Cualificación de esquema inconsistente

**Bloquea: NO.**

Casi todo el script cualifica `cs.`, pero tres sentencias dependen del `USE cs` de la línea 42:

- El `CREATE TABLE IF NOT EXISTS autorizaciones_traslado_duplicado` del bloque 1, y sus tres `REFERENCES` sin esquema.
- 4.1: ``create definer = admin@`%` procedure consulta_turnos_tramitadores_sp(...)`` — sin esquema.
- 4.4: ``create definer = admin@`%` procedure consulta_traslados_internos_logistica(...)`` — sin esquema.

En cambio 4.2 y 4.3 sí usan `` `cs`.`nombre` ``. La asimetría viene de que 4.1 y 4.4 se copiaron de un volcado distinto. Funciona con el `USE`, pero en un script de producción que se corre bloque por bloque —y donde un `DROP` cualificado (`cs.`) puede convivir con un `CREATE` no cualificado— conviene cualificar todo. El escenario feo: `DROP PROCEDURE cs.x` borra el bueno y `CREATE PROCEDURE x` crea en otro esquema si la sesión se reconectó sin el `USE`.

### 🟡 M-3 — La idempotencia no reactiva filas dadas de baja lógicamente

**Bloquea: NO. Es un límite a documentar.**

Ambas tablas usan baja lógica (`activo`, `fecha_baja`, `usuario_baja` — verificado en el DDL real de `permisos_sas` y `perfiles_permisos_sas`).

- 3.1 filtra `NOT EXISTS (... WHERE permiso = 'autorizar_traslado_mismo_dia')` **sin mirar `activo`**. Si el permiso existe con `activo = 0`, la segunda corrida no inserta ni reactiva: el script «sale bien» y el permiso queda apagado.
- 3.2 igual: el `NOT EXISTS` matchea por `(id_perfil, id_permiso)` —que además es la PK— sin mirar `activo`.

O sea: el script es idempotente para *crear*, no para *garantizar el estado deseado*. Es defendible, pero el bloque 5 no lo detecta. Las verificaciones 5.4 y 5.5 devuelven `activo` pero no lo afirman. Mínimo: cambiar el texto de 5.4/5.5 para que diga «`activo` tiene que dar 1 en todas las filas; si da 0, reactivar a mano», o agregar el `UPDATE` de reactivación (`SET activo = 1, fecha_baja = NULL, usuario_baja = NULL`) dentro de la misma transacción.

### 🟡 M-4 — La verificación 5.7 compara contra un valor que el preflight nunca captura

**Bloquea: NO.**

5.7 dice: *«Comparar contra el valor anotado ANTES de correr el script: el total tiene que ser el de antes + 2»*. Pero el bloque 0 no incluye ese conteo en ninguna de sus seis consultas. Como está, 5.7 es inejecutable: el operador llega al final y no tiene contra qué comparar. Agregar al preflight:

```sql
-- 0.10 Total de asignaciones perfil-permiso ANTES del cambio. ANOTAR: 5.7 compara
--      contra este numero + 2.
SELECT COUNT(*) AS total_asignaciones_antes FROM cs.perfiles_permisos_sas;
```

### 🟡 M-5 — Faltan verificaciones en el bloque 5

**Bloquea: NO, pero el bloque 5 no alcanza para dar la promoción por buena.**

Lo que verifica bien: existencia de la tabla y que está vacía (5.1), las tres columnas nuevas (5.2 — y confirmé en DEV que ninguna otra tabla de `cs` tiene columnas con esos nombres, así que «esperado 3 filas» es exacto), que ninguna marca quedó encendida (5.3), unicidad del permiso sin atarse a un id (5.4, correcto), los perfiles asignados (5.5) y la existencia de los cuatro SP (5.6).

Lo que **no** verifica, en orden de importancia:

1. **Que los SP recreados contengan las columnas nuevas.** 5.6 sólo mira `ROUTINE_NAME` y `LAST_ALTERED`: un cuerpo viejo pegado por error pasa el control. Es el riesgo central de todo el change, y es el único que rompe la pantalla.
   ```sql
   -- 5.6b Los cuerpos exponen lo nuevo.
   SELECT ROUTINE_NAME,
          ROUTINE_DEFINITION LIKE '%autorizaciones_traslado_duplicado%' AS usa_tabla_nueva,
          ROUTINE_DEFINITION LIKE '%es_duplicado_autorizado%'            AS usa_marca
     FROM information_schema.ROUTINES
    WHERE ROUTINE_SCHEMA = 'cs'
      AND ROUTINE_NAME IN ('consulta_turnos_tramitadores_sp',
                           'consulta_traslado_remis_amb_logistica',
                           'consulta_traslados_aereos_logistica',
                           'consulta_traslados_internos_logistica');
   ```
   Esperado según el propio script: `consulta_turnos_tramitadores_sp` con `usa_tabla_nueva=1`; `consulta_traslado_remis_amb_logistica` y `consulta_traslados_aereos_logistica` con `usa_marca=1`; `consulta_traslados_internos_logistica` devuelve `NULL as es_duplicado_autorizado` (literal), así que ahí `usa_marca=1` también pero sin leer la columna.

2. **Que las 3 FK y los índices se crearon** — es lo que habría cazado B-1:
   ```sql
   -- 5.8 Constraints e indices de la tabla nueva. Esperado: 3 FK y 6 indices
   --     (PRIMARY, idx_atd_estado, idx_atd_autorizacion, idx_atd_traslado,
   --      fk_atd_traslado_tp, idx_atd_solicitante_visto).
   SELECT CONSTRAINT_NAME, CONSTRAINT_TYPE FROM information_schema.TABLE_CONSTRAINTS
    WHERE TABLE_SCHEMA = 'cs' AND TABLE_NAME = 'autorizaciones_traslado_duplicado';
   SELECT INDEX_NAME, SEQ_IN_INDEX, COLUMN_NAME FROM information_schema.STATISTICS
    WHERE TABLE_SCHEMA = 'cs' AND TABLE_NAME = 'autorizaciones_traslado_duplicado'
    ORDER BY INDEX_NAME, SEQ_IN_INDEX;
   ```

3. **Charset, collation y engine de la tabla nueva** (cierra M-1):
   ```sql
   SELECT ENGINE, TABLE_COLLATION FROM information_schema.TABLES
    WHERE TABLE_SCHEMA = 'cs' AND TABLE_NAME = 'autorizaciones_traslado_duplicado';
   ```

4. **`DEFINER` y `SQL_MODE` de los SP recreados vs. los de 0.7** (cierra B-2 y A-1 del lado de la verificación).

5. **5.6 no filtra por fecha.** «Se recrearon hoy» no se comprueba; agregar `AND LAST_ALTERED >= CURDATE()`.

6. **Ningún smoke `CALL`.** Un procedure puede crearse y romper en la primera invocación (es el caso de `ANSI_QUOTES` de B-2, y cualquier error en el SQL dinámico armado por `CONCAT` sólo aparece en el `PREPARE`). Una llamada de humo a cada uno de los cuatro, con filtros mínimos y un rango de fechas chico, es la única verificación que prueba lo que le importa al usuario. Vale más que 5.1 a 5.7 juntas.

### 🟡 M-6 — Sin guarda de `lock_wait_timeout` para los DDL sobre tablas calientes

**Bloquea: NO.**

El bloque 1 crea una tabla con FK hacia `autorizaciones` (1,87 M) y `traslados` (1,4 M / 2 GB), y el bloque 2 hace `ALTER` sobre `traslados`. La validación de las FK es gratis porque la tabla hija está vacía, pero **abrir las tablas padre requiere un metadata lock**. Si hay una transacción o un `SELECT` largo sobre `traslados` —y en logística los hay—, el DDL se queda esperando, y mientras espera **todo lo que llega detrás se encola atrás suyo**. Es el clásico: el `ALTER` no bloquea nada por sí mismo, la cola sí.

Recomendación, al inicio del bloque 1:

```sql
-- Que un DDL trabado falle rapido en lugar de encolar trafico detras suyo.
SET SESSION lock_wait_timeout = 10;
SET SESSION innodb_lock_wait_timeout = 10;
```

Y en el preflight, mirar qué hay corriendo antes de entrar:

```sql
-- 0.11 Transacciones largas abiertas. Si hay algo de mas de unos segundos sobre
--      traslados o autorizaciones, esperar: el DDL se va a trabar detras.
SELECT trx_id, trx_started, TIMESTAMPDIFF(SECOND, trx_started, NOW()) AS seg, trx_query
  FROM information_schema.INNODB_TRX ORDER BY trx_started;
```

---

## BAJAS

### 🔵 X-1 — Hay dos bloques numerados «2», y el encabezado no coincide

**Bloquea: NO.** Línea 139 abre «2. traslados — la marca que ve logística» y línea 160 abre «2. DDL — la columna de 'visto'». El encabezado del archivo dice que el bloque 1 lleva «la tabla + 2 columnas de marca», pero las marcas están en el primer bloque «2», no en el 1. En un script que se corre bloque por bloque leyendo controles, la numeración es parte de la seguridad operativa. Renumerar a 2 y 3, y correr el resto (el DML pasa a 4, los SP a 5, verificaciones 6, rollback 7).

### 🔵 X-2 — El preflight 0.4 afirma un id que ya no se sostiene en los ambientes bajos

**Bloquea: NO. Es indiferente para el comportamiento.** El comentario dice que en producción `MAX(id_permiso) = 101` (`editar_cie10_bloqueado`) y que el permiso nuevo «debería quedar en 102». Los ambientes bajos hoy dicen otra cosa:

- **DEV:** `MAX = 1000`, y `autorizar_traslado_mismo_dia` ya está ahí con `id_permiso = 1000` (`AUTO_INCREMENT = 1001`); `editar_cie10_bloqueado` es el **105**, no el 101; el 101 es `log_cirugias`, eso sí coincide con lo que dice el script.
- **TEST:** `MAX = 101`, y el 101 **es el permiso nuevo**.

O sea: el espacio de ids divergió más de lo que el comentario refleja, y en DEV hay un salto a 1000 que rompe cualquier expectativa de «el que sigue». No importa para el resultado —las dos puntas resuelven por nombre (D7) y `MAX+1` no puede colisionar con el contador `AUTO_INCREMENT`, que va por delante—, pero el operador puede leer «debería quedar en 102» como una aserción, ver otro número y frenar la ventana sin motivo. Reescribir 0.4 como lo que es: informativo, sin valor esperado.

### 🔵 X-3 — El rollback borra el permiso físicamente, contra la convención de la tabla

**Bloquea: NO.** 6.1 hace `DELETE FROM cs.permisos_sas`. Las dos tablas están diseñadas para baja lógica (`activo`, `fecha_baja`, `usuario_baja`). El `DELETE` funciona y el orden respeta la FK, pero pierde la traza de que el permiso existió y **libera el id**, que después reaparece por otro lado — exactamente el tipo de confusión de ids que este script se esforzó en evitar. Alternativa alineada con la convención:

```sql
-- UPDATE cs.perfiles_permisos_sas ppp
--   JOIN cs.permisos_sas perm ON perm.id_permiso = ppp.id_permiso
--    SET ppp.activo = 0, ppp.fecha_baja = NOW(), ppp.usuario_baja = 1
--  WHERE perm.permiso = 'autorizar_traslado_mismo_dia';
-- UPDATE cs.permisos_sas SET activo = 0, fecha_baja = NOW(), usuario_baja = 1
--  WHERE permiso = 'autorizar_traslado_mismo_dia';
```

Con el `DELETE` como opción B si se quiere el esquema limpio.

### 🔵 X-4 — `estado` sin FK ni CHECK

**Bloquea: NO.** `estado INT(11) NOT NULL DEFAULT 1`, con los códigos 1/2/3 documentados en comentario y deliberadamente sin depender de `estados_autorizaciones`. La decisión está argumentada y la acompaño. Si en algún momento se quiere blindar sin acoplar al catálogo, un `CHECK (estado IN (1,2,3))` es gratis en 10.5. Sólo como nota.

### 🔵 X-5 — `traslados_transporte_publico.es_duplicado_autorizado` no lo lee ninguno de los cuatro SP

**Bloquea: NO.** Los SP leen `t.es_duplicado_autorizado` sólo en 4.2 y 4.3 (`consulta_traslado_remis_amb_logistica`, `consulta_traslados_aereos_logistica`) y 4.4 devuelve el literal `NULL as es_duplicado_autorizado`. La columna de `traslados_transporte_publico` no aparece en ninguno. Puede estar bien —la debe consumir otro camino de `wslogistica`, o queda para el listado de transporte público— pero conviene confirmarlo antes de agregar una columna a producción: si no la lee nadie, es peso muerto que después nadie se anima a borrar. Verificar contra el código de `wslogistica`.

---

## Lo que revisé y está bien

Vale dejarlo escrito, porque es donde estaba el riesgo esperado y no hay hallazgo.

**Idempotencia del `id_permiso` — el razonamiento del script es correcto, verificado.** Probé las dos formas en DEV:

- `SELECT <constantes> WHERE NOT EXISTS (SELECT 1 FROM cs.permisos_sas WHERE permiso = 'no_existe_xyz')` → **1 fila**.
- La misma con el permiso ya existente → **0 filas**.

Es decir: la forma elegida (el `MAX+1` en su propio `SET @id_permiso_nuevo`, y el `INSERT ... SELECT <constantes> WHERE NOT EXISTS`) **es idempotente**. En la segunda pasada `@id_permiso_nuevo` se recalcula y no se usa, y el `INSERT` no inserta nada. Y el diagnóstico del comentario sobre por qué la otra forma falla es exacto: `SELECT MAX(...) FROM permisos_sas WHERE NOT EXISTS (...)` es una agregación sin `GROUP BY`, devuelve **siempre una fila**, con `MAX()` en `NULL` cuando el `WHERE` filtró todo → `COALESCE(NULL,0)+1 = 1` → segunda inserción con `id_permiso = 1`. El bug estaba bien identificado y bien resuelto. Tampoco hay colisión posible con el contador: `permisos_sas` es `AUTO_INCREMENT` y su contador va por delante de `MAX(id_permiso)` (en DEV, 1001 contra 1000), así que una inserción explícita en `MAX+1` no pisa nada ni se pisa después.

**Idempotencia del resto, sentencia por sentencia.** Segunda pasada:

| Sentencia | 2.ª pasada | Veredicto |
|---|---|---|
| `CREATE TABLE IF NOT EXISTS` | no-op | Idempotente. **Pero enmascara divergencia de esquema** → es la causa de que B-1 no se autocorrija. |
| `ADD COLUMN IF NOT EXISTS` ×3 | no-op con warning 1060 (nota, no error) | Idempotente |
| `SET @id_permiso_nuevo` | recalcula, no se usa | Idempotente |
| `INSERT ... permisos_sas ... NOT EXISTS` | 0 filas afectadas | Idempotente (salvo `activo=0`, M-3) |
| `INSERT ... perfiles_permisos_sas ... CROSS JOIN + NOT EXISTS` | 0 filas afectadas; el `NOT EXISTS` es redundante con la PK `(id_perfil, id_permiso)` pero evita el error 1062 | Idempotente (salvo `activo=0`, M-3) |
| `DROP PROCEDURE IF EXISTS` + `CREATE` ×4 | recrea | Idempotente |
| Bloque 5 | sólo lectura | Idempotente |

**No encontré ninguna sentencia donde la segunda pasada haga algo distinto de la primera.** Los dos matices son M-3 (no reactiva bajas lógicas) y el efecto lateral de B-1 (lo que no se creó la primera vez no se crea nunca).

**Los `DELIMITER` están correctos.** `$$` aparece exactamente 8 veces en el archivo, y las 8 son marcadores: `DELIMITER $$` en 246, 669, 944 y 1196; `$$` de cierre en 657, 932, 1184 y 1414, cada uno seguido de `DELIMITER ;` en 658, 933, 1185 y 1415. Cuatro pares balanceados, ningún anidamiento, y **ningún `$$` dentro de los cuerpos** — que es lo que cortaría una definición antes de tiempo. Los `;` internos (cientos, entre `DECLARE`, `SET`, `PREPARE`, `IF/END IF`) son seguros justamente porque están dentro de un `$$`. Revisé además los cuatro `END` de cierre en 656, 931, 1183 y 1413; los `END` internos (891, 1144, 1374) son cierres de `IF`/`CASE`, no de bloque. Sin hallazgos acá.

**Las FK son sanas.** Los tres tipos coinciden exactamente contra lo que hay en la base (consultado en DEV):

| FK | Columna hija | Columna padre | Coincide |
|---|---|---|---|
| `fk_atd_autorizacion` | `id_autorizacion INT(11) NOT NULL` | `autorizaciones.id_autorizacion` `int(11)` signed, **PRI** | ✅ |
| `fk_atd_traslado` | `id_traslado INT(11) NULL` | `traslados.id_traslado` `int(11)` signed, **PRI**, auto_increment | ✅ |
| `fk_atd_traslado_tp` | `id_traslado_transporte_publico INT(11) NULL` | `traslados_transporte_publico.id_traslado` `int(11)` signed, **PRI** | ✅ |

Todas `int(11)` **con signo** en ambos lados (un `UNSIGNED` desparejo es el error clásico acá, y no está), todas las padre son InnoDB, y el charset/collation no juega porque son columnas numéricas. Las tres padre tienen índice —son PK— así que no falta índice del lado referenciado. Y la tabla hija **se crea vacía**: no hay filas que puedan violar la constraint, así que no hay riesgo de que las FK fallen por datos existentes ni costo de validación. Las dos columnas de traslado son nullable, coherente con que un pedido apunte a uno u otro. `traslados_transporte_publico` sí es el nombre correcto de la tabla y su PK sí se llama `id_traslado` (no `id_traslado_transporte_publico`), que era el otro punto donde esto podía estar mal escrito.

**Los índices declarados sirven, con una excepción.** Contrastados contra las consultas que el circuito hace de verdad, leídas del propio SP:

- `idx_atd_autorizacion (id_autorizacion)` — sirve el join `ATD.id_autorizacion = AUT.id_autorizacion` **y** la subconsulta del último pedido, `(SELECT MAX(ATD2.id_autorizacion_traslado_duplicado) FROM ... WHERE ATD2.id_autorizacion = AUT.id_autorizacion)`. Y la resuelve de forma óptima: InnoDB agrega la PK al final de todo índice secundario, así que este índice es de hecho `(id_autorizacion, id_autorizacion_traslado_duplicado)` y el `MAX` sale *index-only*, sin tocar la tabla. No hace falta declarar el compuesto: está bien como está.
- `idx_atd_estado (estado)` — sirve el `AND ATD.estado = 1` de la grilla del autorizante y el contador de la card. Selectividad pobre (3 valores), pero el filtro llega después del join que arranca por `turnos`/`autorizaciones`, así que no es el índice que decide el plan. Correcto que exista.
- `idx_atd_traslado (id_traslado)` — sostiene `fk_atd_traslado` y sirve la búsqueda del pedido a partir de un traslado (el tooltip de logística).
- `fk_atd_traslado_tp` — lo crea InnoDB solo para la FK. No hace falta declararlo.
- **El que falta: `idx_atd_solicitante_visto (id_solicitante, estado, fecha_visto_solicitante)`** → B-1.

**El orden de despliegue está bien planteado y bien argumentado.** BD antes que servicios es lo correcto con mapeo por `resultClasses`: el SP nuevo contra el código viejo devuelve columnas que el mapeo ignora, mientras que el código nuevo contra el SP viejo no encuentra las columnas que espera y rompe. Y dentro del script el orden interno es consistente con eso: el bloque 4 recrea SP que referencian `autorizaciones_traslado_duplicado` (creada en el bloque 1) y `t.es_duplicado_autorizado` (agregada en el bloque 2), así que las dependencias están en el orden correcto.

**Compatibilidad con código vivo: sin hallazgos.** Las tres columnas nuevas son nullable y sin `NOT NULL` sin default, así que no rompen los `INSERT` del código viejo; no hay `DROP COLUMN` ni renombres en el apply; la tabla nueva no la mira nadie hasta que sube el código. La única discontinuidad real es la ventana del `DROP`+`CREATE` del bloque 4, que el script advierte explícitamente y para la que pide horario de bajo tráfico y respaldo previo. Correcto.

**Los perfiles del bloque 3.2 existen con esos nombres exactos** (`referente_siniestros` = 3, `jefe_de_siniestros` = 2 en DEV), y el preflight 0.6 ya cubre el riesgo que tiene el `CROSS JOIN`: si un nombre no matchea, no asigna nada y no avisa. La resolución por nombre en lugar de por id es la decisión correcta dado que los ids de perfil divergen entre ambientes. La diferencia deliberada con DEV/TEST (dos perfiles en lugar de cuatro) está documentada en tres lugares del script y la verificación 5.5 la comprueba.

**PII: sin hallazgos.** Ninguna columna nueva guarda datos personales. `justificacion` y `dictamen` son texto libre escrito por el gestor —podría acabar conteniendo datos del paciente, pero eso es política de uso, no de esquema— y los `id_solicitante` / `id_autorizante` son FK a `personas`, no datos en claro. No hay ejemplos con datos de producción en los comentarios.

---

## Plan de corrección, en orden

**Antes de pedir la ventana:**

1. **B-1** — agregar el `ALTER ... ADD INDEX IF NOT EXISTS idx_atd_solicitante_visto` después del bloque 2. Confirmar con el autor que el índice es parte del change y no un agregado manual de DEV/TEST.
2. **B-2** — agregar el preflight 0.7 (`SQL_MODE`, charset, `DEFINER`, `SECURITY_TYPE` de las 4 rutinas) y el `SET SESSION sql_mode` al abrir el bloque 4.
3. **A-1** — agregar el preflight 0.8 (`SELECT CURRENT_USER(), USER()`) y confirmar que el operador es `admin@%`.
4. **A-3** — reemplazar el respaldo del bloque 0.5 por un `mysqldump --routines --no-data`, guardado en archivo y **verificado** (que abra, que tenga los cuatro `CREATE`, que no esté truncado).
5. **A-4** — agregar `ALGORITHM = INSTANT` a los dos `ALTER` del bloque 2.
6. **M-1** — declarar `DEFAULT CHARSET = latin1 COLLATE = latin1_swedish_ci` en el `CREATE TABLE`, y agregar el preflight 0.9.
7. **M-4 / M-6** — agregar los preflight 0.10 (conteo previo de asignaciones) y 0.11 (transacciones largas), y las guardas de `lock_wait_timeout`.
8. **M-5** — agregar las verificaciones 5.6b (cuerpos de los SP), 5.8 (constraints e índices), charset/engine de la tabla, y el smoke `CALL` a los cuatro SP.
9. **A-2 / M-2 / X-1** — la advertencia de commit implícito en el encabezado del bloque 4, cualificar `cs.` en las tres sentencias que no lo hacen, y renumerar los bloques.
10. **A-5** — agregar el paso 6.0 (revertir servicios primero) y la nota de no ejecutar 6.2 en un rollback de emergencia.

**Ensayo obligatorio antes de producción:** correr el script corregido **completo, bloque por bloque, en TEST**, desde el mismo cliente y con la misma cuenta con que se va a correr en producción, tomando el tiempo de los dos `ALTER`. Es lo único que descarta B-2, A-1 y A-4 sin adivinar. TEST ya tiene la tabla y el permiso aplicados, así que ese ensayo además prueba **la segunda pasada**, que es justo lo que hay que probar de un script idempotente.

**Las Bajas (X-1 a X-5)** no requieren corrección para aplicar; conviene resolverlas en el mismo pasaje para no dejar deuda.

---

## Preguntas al autor

1. **`idx_atd_solicitante_visto`**: ¿es parte del change (y el generador lo perdió al armar el `CREATE TABLE`), o se agregó a mano en DEV y TEST para un problema puntual? La respuesta define si B-1 es una omisión o una decisión.
2. **¿Con qué cuenta y con qué cliente se corre en producción?** Si no es `admin@%`, A-1 se vuelve bloqueante y hay que resolverlo antes. Y si el cliente no soporta `DELIMITER` (cualquier runner por JDBC), el bloque 4 no se puede ejecutar tal como está.
3. **¿Se conoce el `sql_mode` con que están creados hoy los cuatro SP en producción?** Si alguien lo tiene anotado, B-2 se cierra sin esperar la ventana.
4. **`traslados_transporte_publico.es_duplicado_autorizado`**: ¿qué lo consume? Ninguno de los cuatro SP lo lee.
5. **¿El default de charset del esquema `cs` en producción es `latin1`?** Es la única incógnita de M-1 que no pude verificar por acá.
6. **¿Se contempló dejar `es_duplicado_autorizado` en su lugar en un rollback de emergencia**, en vez de ejecutar 6.2 sobre una tabla de 2 GB?

---

## Límites de esta revisión

- **No se ejecutó nada** del script, en ningún ambiente.
- **No se consultó producción.** El MCP de MariaDB apunta a PROD y quedó sin usar por indicación explícita. Todos los datos de esquema salen de los conectores read-only de **DEV** y **TEST**. Los valores de producción (charset del esquema, `MAX(id_permiso)`, `sql_mode` de las rutinas, cuenta del operador) quedan como puntos a verificar en el preflight.
- No se validó la semántica de negocio del change ni la lógica interna de los cuatro SP más allá de lo necesario para juzgar índices y `DELIMITER`.
- No reemplaza el ensayo en TEST.

---

Generado por Vanesa Yanina Burman — Líder Técnica · 21/08/2026
