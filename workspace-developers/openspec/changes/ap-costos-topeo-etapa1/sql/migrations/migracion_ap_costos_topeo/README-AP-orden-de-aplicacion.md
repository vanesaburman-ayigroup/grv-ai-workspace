# AP Costos y Topeo (etapa 1) — cómo aplicar estas migraciones

Estas migraciones **se ejecutan a mano**: el ecosistema no tiene Flyway ni tabla de control.
Nadie va a avisar si un script quedó sin aplicar, si se aplicó en el orden equivocado o si se
aplicó sobre una tabla que ya existía con otra forma. Por eso el orden y la verificación de
cada archivo no son detalles: son el único control.

**Change OpenSpec:** `ap-costos-topeo-etapa1`
**Ticket Jira:** PENDIENTE — todavía no existe. Mientras no exista, la trazabilidad es el
change de OpenSpec. Al crearlo hay que reemplazar el placeholder `GRV-NNNN` en los ocho
archivos (V32, V33, V34, V35, V36, V001, V002, V003); están marcados como `PENDIENTE` a propósito.

> ⚠ **Colisión de numeración pendiente de decidir (detectada el 10/08/2026).** El repo
> `wsmesacarga` ya tiene en `src/main/resources/sql/` un
> `V32__FIX_predicado_sargable_patologia_trazadora.sql` (commit `34e2f2e`, 07/08/2026, change
> **DE-01-intake**). O sea que el `V32` de ESTE change choca por número con uno ajeno. El
> máximo real en el repo es V32, así que **V35 y V36 están libres**, pero si se decide renumerar
> los archivos de AP para resolver la colisión, se mueven los **cinco** (V32→V33→V34→V35→V36
> pasarían a V33→V34→V35→V36→V37) y hay que rehacer la correspondencia con lo ya aplicado en dev y
> stage. **No renumerar por iniciativa propia**: es una decisión de quien integre las dos ramas.
>
> ⚠ Ninguno de los cinco archivos está todavía copiado a `wsmesacarga/src/main/resources/sql/`
> (verificado el 10/08/2026: el repo sólo tiene hasta `V32__FIX_...`). La copia es parte de la
> misma decisión de integración, no un olvido: copiarlos antes de resolver la numeración deja dos
> `V32` distintos en la misma carpeta. Las columnas **sí** están aplicadas en dev y stage.

---

## 1. El modelo del tope: dos niveles, y por qué

Decisión de negocio del **10/08/2026**. En la reunión, Verónica lo dijo así: «aseguro a todos
mis empleados por cinco millones, **a cada uno**». El monto es el mismo para todos los
asegurados de la póliza y se aplica **individualmente** a cada uno — no es una bolsa
compartida que se agota entre todos.

| Nivel | Dónde vive | Quién lo carga | Cuándo |
|---|---|---|---|
| **1. Tope GENERAL** | `polizas_ap.suma_asegurada` (**V35**) + su historial (**V36**) | negocio, en la pantalla de la póliza | **obligatorio en el alta** de toda póliza nueva |
| **2. EXCEPCIONES** | `polizas_ap_topes` (**V32**) + su historial (**V33**) | negocio, con motivo | sólo para el asegurado cuyo tope **se aparta** del general |

Los **dos** niveles comparten la misma tabla de historial (`polizas_ap_topes_historial`), y se
distinguen por `id_tope`: `NULL` = cambio del general (con `id_poliza`), no nulo = cambio de una
excepción. El «por qué una sola tabla y no dos» está en el banner de V36.

Quién escribe cada nivel: el **general** lo escribe `wsmesacarga` (dueño de `polizas_ap`), las
**excepciones** `wsaccidentespersonales` (dueño del dominio AP). Ninguno de los dos toca el nivel
del otro.

**Resolución, en vivo, en el motor de `wsaccidentespersonales`:**

```
excepción por (id_poliza, nro_doc, ventana)   →   si no hay, TOPE GENERAL de la póliza
```

Tres consecuencias que hay que tener presentes al aplicar y al leer los controles:

- **Las 6 columnas de `denuncia_poliza` (V34) son CACHE OPCIONAL.** El motor **no depende de
  ellas**. Por eso cargar o corregir un tope se refleja **al instante**, sin backfill, sin
  tocar `wsdocumento` (dueño de `denuncia_poliza`) y sin escribir dentro de un GET.
- **La excepción tapa la falta del general.** Una póliza sin tope general puede tener parte de
  sus siniestros perfectamente resueltos, porque la excepción resuelve sola y tiene prioridad.
  Al contar pendientes, **contar denuncias activas a secas sobreestima el problema**: la
  bloqueada de verdad es la del asegurado que **no** tiene excepción propia. La query de
  control 4.A de V35 ya hace esa distinción.
- **Si el nivel 2 crece mucho, algo salió mal.** Una excepción por cada asegurado es la
  planilla que este cambio vino a eliminar. El control **4.C de V35** lista las pólizas con
  excepciones y **sin** general justamente para detectar esa deriva; debería tender a 0.

---

## 2. Estado de la base al escribir esto

Producción, medido para V32-V34:

| Qué | Cuánto |
|---|---|
| Denuncias AP activas (`denuncia_poliza`, `activo = 1`) | **73** |
| De ésas, **sin afiliado resuelto** (`id_afiliado` NULL en `denuncias`) | **3** |
| Pólizas AP con siniestros | **7** |

Las **3 sin afiliado** son las que importan para el backfill: sin afiliado no hay documento, y
sin documento no hay tope que resolver. **No son un error del script** — el backfill las va a
dejar en `SIN_TOPE` y ahí se quedan hasta que alguien vincule al accidentado. Si el bloque 4
de V34 devuelve 3 filas por esa causa, está bien.

Ambientes bajos, medido el **10/08/2026 inmediatamente después de aplicar V35**:

| Ambiente | Pólizas AP | Sin tope general | De ésas, con siniestros activos | Denuncias AP activas | Denuncias que quedan `SIN_TOPE` |
|---|---|---|---|---|---|
| **stage** | 30 | **30** | **7** | 61 | **54** |
| **dev** | 12 | **12** | **4** | 12 | **12** |

En stage, `61 − 54 = 7` denuncias se resuelven por excepción: son las **7 excepciones de
prueba** de este change (marcadas `DATO DE PRUEBA ap-costos-topeo-etapa1` en
`polizas_ap_topes_historial.motivo`), todas de la póliza `983320`. **En producción, al aplicar
V35, `polizas_ap_topes` está vacía: todas las denuncias activas cuentan como bloqueadas.**

> **Stage ya se movió, y eso no invalida la tabla de arriba.** Poco después de aplicar V35 se
> cargaron en stage **4 topes generales de prueba** (pólizas `17885` = 200.000, `982176` =
> 500.000, `983320` = **5.000.000** —el caso de Verónica— y `983881` = 70.000). Hoy stage tiene
> **26** pólizas sin tope general y sólo **4** denuncias en `SIN_TOPE` (3 pólizas urgentes).
> Los dos números son correctos: **30/54 es la foto al aplicar** —la que reproduce un ambiente
> limpio y la que va a dar producción— y **26/4 es la foto después de cargar 4 topes**. Al
> validar en stage, comparar contra la segunda; en dev el baseline original sigue intacto.
>
> Ese movimiento es, de paso, la mejor demostración del modelo: **un solo** tope general en la
> póliza `983320` resolvió de una vez las **51** denuncias que estaban en `SIN_TOPE`
> (54 → 4). Eso es lo que 51 excepciones cargadas a mano habrían tenido que hacer.

---

## 3. Orden de ejecución

Estricto y ascendente, **dentro de cada servicio**:

| # | Archivo | Servicio | Qué deja |
|---|---|---|---|
| 1 | `V32__CREATE_polizas_ap_topes.sql` | wsmesacarga | `polizas_ap_topes` — las **EXCEPCIONES** por (póliza, documento, ventana) |
| 2 | `V33__CREATE_polizas_ap_topes_historial.sql` | wsmesacarga | `polizas_ap_topes_historial` — versiona suma, ventana e IVA de las excepciones |
| 3 | `V34__ALTER_denuncia_poliza_ADD_tope.sql` | wsmesacarga | 6 columnas de **cache opcional** del tope en `denuncia_poliza` (**bloques 1 y 2 solamente** — ver sección 4) |
| 4 | `V35__ALTER_polizas_ap_ADD_suma_asegurada.sql` | wsmesacarga | **TOPE GENERAL** en `polizas_ap` (+ `iva_incluido`, `moneda`, `ventana`) + `ck_polizas_ap_suma_positiva`. **Denominador del semáforo en el caso normal** |
| 4b | `V36__ALTER_polizas_ap_topes_historial_ADD_id_poliza.sql` | wsmesacarga | **Historial del tope general**: `id_tope` pasa a NULL-able + `id_poliza` nueva, para que la EDICIÓN del tope general deje quién / cuándo / desde cuánto / con qué motivo. `polizas_ap` no tiene historial propio |
| 5 | `V001__crear_tabla_ap_semaforo_parametros.sql` | **wsaccidentespersonales** | `ap_semaforo_parametros` + la fila de parámetros por defecto (umbrales sin deploy) |
| 6 | `V002__crear_tabla_ap_valores_manuales.sql` | **wsaccidentespersonales** | `ap_valores_manuales` — los valores que hoy viven en una planilla |
| 7 | `V003__crear_tabla_ap_avisos_nivel_siniestro.sql` | **wsaccidentespersonales** | `ap_avisos_nivel_siniestro` — idempotencia del aviso por nivel |

### Por qué el orden importa, archivo por archivo

- **V33 después de V32.** El historial referencia `polizas_ap_topes.id_tope`. No hay FK que lo
  fuerce (el ecosistema no las usa), así que al revés **no falla**: crea el historial y la
  verificación 6 de V33 —"tope activo sin historial"— revienta con «table doesn't exist» en
  lugar de dar 0 filas. Confuso, evitable.
- **V34 después de V32.** V34 denormaliza el tope y guarda `id_tope` apuntando a
  `polizas_ap_topes`. Sin V32, su dry-run y sus controles de gestión no compilan.
- **V35 puede ir en cualquier momento — pero conviene DESPUÉS de V32.** Su `ALTER` es
  independiente de todo (cuatro columnas escalares sobre `polizas_ap`) y se puede aplicar
  solo. Lo que **sí** necesita V32 son sus bloques 4 (query de control) y 5.D (prueba de
  resolución): leen `polizas_ap_topes` y sin ella fallan con «table doesn't exist». Si por
  algún motivo hay que correr V35 antes, sacar el `LEFT JOIN` a topes del bloque 4 y leer
  todas las denuncias activas como bloqueadas — que es la foto correcta cuando todavía no
  existen excepciones posibles.
- **V36 después de V33 y V35.** Altera la tabla que crea V33, y versiona el dato que crea V35. Sin
  V33 falla con «table doesn't exist»; sin V35 deja un historial listo para un dato que no existe.
  Es el único archivo del paquete que **relaja** una restricción (`id_tope` deja de ser NOT NULL):
  no rompe a `wsaccidentespersonales` —su entidad siempre setea `idTope`, y su `nullable = false`
  sólo afecta la generación de DDL, que este ecosistema no usa— pero conviene aplicarlo con eso
  presente. Su bloque 4 tiene el único `UPDATE` de datos del paquete, y es **derivable** (copia
  `polizas_ap_topes.id_poliza`): saltearlo no rompe nada, sólo obliga a leer el historial del
  general con un `OR`.
- **wsaccidentespersonales después de wsmesacarga.** Las tres tablas nuevas son
  independientes entre sí (no se referencian: V001→V002→V003 es convención ascendente, no
  dependencia), pero el semáforo que las consume lee el tope de wsmesacarga. Si se aplican
  primero no rompen nada, pero queda un servicio configurado sin nada que medir.

**Regla simple: los ocho archivos, en este orden, y verificando cada uno antes de pasar al
siguiente.**

### V35 y V36 son los únicos que NO son 100 % idempotentes

Los dos por el mismo motivo (el `CHECK`), y los dos traen su pre-chequeo para no depender de leer el
error: **2.A** en V35 y **3.A** en V36. Lo que sigue vale igual para los dos.


Los `ADD COLUMN IF NOT EXISTS` de V35 sí lo son, pero MariaDB 10.5 **no tiene**
`ADD CONSTRAINT IF NOT EXISTS`. Re-correr el archivo completo falla en el `CHECK` con:

```
ERROR 1826: Duplicate CHECK constraint name 'ck_polizas_ap_suma_positiva'
```

**Ese error es el resultado esperado de una segunda corrida y no deja nada a medias**
(verificado re-corriendo el script entero en dev el 10/08/2026: columnas intactas, datos sin
tocar). Para no depender de leerlo, V35 trae el pre-chequeo **2.A**: si devuelve `1`, saltear
el `2.B`.

El `CHECK` se probó de verdad, no sólo por su existencia (UPDATE en dev dentro de una
transacción con `ROLLBACK`): rechaza `0` y `-5.00` con
`ERROR 4025: CONSTRAINT 'ck_polizas_ap_suma_positiva' failed`, y acepta `5000000.00` y `NULL`.
Cubre el caso que importa —un tope `0` pondría **todos** los siniestros de la póliza en
«Excedido» con un número que parece calculado— sin estorbar a las pólizas que todavía no
tienen tope.

---

## 4. V35 no tiene backfill, y no debe tenerlo

El tope general es un **dato de negocio que sale del contrato de cada póliza**. No se deduce de
nada que ya esté en la base: no hay ninguna columna, ninguna otra tabla y ningún promedio del
que se pueda derivar. Cualquier `UPDATE` masivo sobre `polizas_ap.suma_asegurada` sería
**inventar sumas aseguradas**, y quedarían indistinguibles de las cargadas por negocio.

Por eso `suma_asegurada` es **NULL-able** aunque el alta la exija: la obligatoriedad es de la
**aplicación** (Bean Validation + la validación en la misma transacción de
`PolizaApServiceImpl.crearPoliza`), **no de la columna**. Al aplicar V35 hay pólizas ya
cargadas sin tope — **30 en stage, 12 en dev** — y poner la columna `NOT NULL` deja dos
salidas, las dos peores:

| Si fuera… | Qué pasa |
|---|---|
| `NOT NULL` **sin** default | El `ALTER` **falla** sobre una tabla con filas, o MariaDB inventa el default implícito del tipo (`0.00`) según el `sql_mode`. Un tope `0.00` pone **todos** los siniestros de esa póliza en «Excedido» |
| `NOT NULL` **con** default | Las 30 pólizas quedan con un número **que nadie pactó**, indistinguible de un tope real. Se pierde para siempre la pregunta «¿a esta póliza le falta el tope?» |

Con `NULL`, «falta el tope» es un estado **explícito y consultable**: es lo que alimenta el
estado `SIN_TOPE` del semáforo (que **no** es `0 %`, y la pantalla lo distingue) y la query de
control **4.A/4.B de V35**, que es la lista que negocio tiene que llevar a cero.

> **Ojo con las otras tres columnas de V35** (`iva_incluido`, `moneda`, `ventana`): ésas **sí**
> van `NOT NULL DEFAULT` (`1` / `'ARS'` / `'ANUAL'`), así que las pólizas preexistentes quedan
> con la regla de lectura puesta **sin pasar por ningún proceso**. Es deliberado: son la
> *regla de lectura* del monto, no el monto, y la regla tiene un default correcto y único hoy.
> Esto **parece** contradecir a V34 —donde `ventana` e `iva_incluido` se declararon
> NULL-ables con el argumento «un ANUAL por default mentiría sobre un tope que nadie
> resolvió»— y **no la contradice**: en `denuncia_poliza` son el *cache de una resolución*
> (si no ocurrió, NULL es la única respuesta honesta), y en `polizas_ap` son la *declaración
> de la póliza*. Misma columna, distinto significado según la tabla. **Si alguien las alinea
> "por consistencia", rompe una de las dos.**

Secuencia real de V35: aplicar el `ALTER` → correr el control 4.A → pasarle a negocio el
detalle 4.B → negocio carga los topes **por pantalla** (no con `INSERT`/`UPDATE` sueltos) →
el control 4.A vuelve a correrse hasta dar 0 en `1_URGENTE`. No hay apuro técnico: el semáforo
funciona con `SIN_TOPE`.

---

## 5. El bloque 3 de V34 (backfill) es un paso OPERATIVO POSTERIOR

> Con el modelo de dos niveles cerrado el 10/08/2026, este backfill pasó a ser **opcional**:
> las 6 columnas de `denuncia_poliza` son **cache** y el motor no las lee. Correrlo sólo si se
> quiere poblar el cache; **no correrlo no bloquea nada**. Todo lo de abajo sigue valiendo si
> se decide correrlo.

`V34__ALTER_denuncia_poliza_ADD_tope.sql` tiene el bloque 3 **entero comentado**, y así se
queda al aplicar el paquete. **No es un olvido ni algo que haya que descomentar al desplegar.**

El backfill resuelve el tope de las 73 denuncias AP existentes leyendo `polizas_ap_topes`. Y
al momento del deploy **esa tabla está vacía**: los topes los carga NEGOCIO, póliza por
póliza, después. Corrido antes, el backfill **no tiene nada que resolver**: recorre las 73
filas, no matchea ninguna, y deja todo exactamente como estaba. En el mejor caso es un no-op;
en el peor da la falsa impresión de que el paso ya se hizo.

Secuencia real:

1. Se aplican los ocho archivos (estructura). El semáforo arranca con todo en **`SIN_TOPE`**,
   que es un estado válido y previsto — no es `0 %`, y la pantalla lo distingue.
2. Negocio carga los topes de las **7 pólizas con siniestros**: primero el **general** de cada
   una (V35, en la pantalla de la póliza) y sólo después las **excepciones** de los asegurados
   que se aparten (por pantalla, con motivo, lo que deja la fila de ALTA en el historial de
   V33). En ese orden: cargar excepciones antes que el general es usar el nivel 2 para hacer el
   trabajo del nivel 1, y es lo que el control 4.C de V35 marca.
3. **Recién entonces** se corre el bloque 3 de V34, como tarea aparte y con su propio
   registro: `3.0` pre-chequeo de ambigüedad de ventana (debe dar 0 filas) → `3.1` dry-run →
   `3.2` conteo antes → `3.3` el `UPDATE` dentro de una transacción, confirmado contra el
   dry-run → verificación.
4. El bloque `3.4` (re-resolución de un tope ampliado o corregido) **no es parte del
   backfill**: es mantenimiento recurrente, se corre cada vez que el control `4.C` de V34
   detecte vínculos desincronizados.

Si el paso 2 no pasó, el paso 3 no se corre. No hay apuro: el semáforo funciona con
`SIN_TOPE`.

---

## 6. Verificar cada script NO es opcional

Los cuatro `CREATE TABLE` del paquete usan `CREATE TABLE IF NOT EXISTS`. Eso los hace
idempotentes **por NOMBRE, no por FORMA**, y es la trampa central de aplicar a mano:

> Si la tabla ya existe —porque alguien la creó a mano en dev para probar, porque se aplicó
> una versión anterior del archivo, o porque se copió de otro ambiente— el
> `CREATE TABLE IF NOT EXISTS` **no falla, no avisa y no corrige nada**. Sale con un warning
> que nadie lee y sigue. La tabla queda **sin el CHECK, sin la UNIQUE, o con `nro_doc` en
> utf8mb4**, y el paquete parece aplicado.

Ninguna de las tres formas de quedar mal da error al aplicar. Las tres dan error o dato
incorrecto **después**, en producción y en silencio:

| Si quedó… | Qué pasa después |
|---|---|
| `nro_doc` en **utf8mb4** en lugar de latin1 | El join contra `cs.afiliados` (VARCHAR(50) latin1_swedish_ci) rompe con *Illegal mix of collations*; y si alguien lo "arregla" con `COLLATE` en el `ON`, MariaDB convierte la columna indexada y **pierde el índice de `afiliados`** → full scan |
| **sin la UNIQUE** `uk_polizas_ap_topes_poliza_doc_ventana` | La misma persona puede terminar con dos topes activos en la póliza. El semáforo toma uno de los dos según el orden del plan: el porcentaje cambia sin que nadie haya tocado un dato |
| **sin el CHECK** `ck_polizas_ap_topes_suma_positiva` | Entra un tope 0 o negativo y **todos** los casos de esa póliza arrancan «Excedido» |
| **sin los 4 campos de ventana/IVA** en el historial (V33) | Un cambio de ANUAL a EVENTO redefine el tope sin dejar rastro; nadie puede contestar por qué un caso pasó a Excedido |

V35 no usa `CREATE TABLE` (es un `ALTER`, y sus `ADD COLUMN IF NOT EXISTS` sí son idempotentes
por forma), pero tiene su propia versión de la misma trampa:

| Si quedó… | Qué pasa después |
|---|---|
| `moneda` o `ventana` en **latin1** en lugar de utf8mb4 | La columna se creó **sin** el `CHARACTER SET` explícito y heredó el de la tabla (`polizas_ap` es latin1). No rompe —MariaDB 10.5 coerciona latin1 → utf8mb4 en `COALESCE`/`CASE`/`=`, verificado en dev— pero es una coerción implícita en el `COALESCE` que el motor corre en cada resolución, que es exactamente lo que **anula el uso de índice** cuando el lado convertido es el indexado. La verificación 5 de V35 lo detecta y el **5.C** trae el `MODIFY` de remediación |
| **sin el CHECK** `ck_polizas_ap_suma_positiva` (porque se salteó el bloque 2) | Entra un tope general `0` o negativo y **todos** los siniestros de esa póliza arrancan «Excedido» — con un número que parece calculado |
| `suma_asegurada` **NOT NULL** (porque alguien "mejoró" el DDL) | Las pólizas preexistentes quedan con un tope que nadie pactó y se pierde la lista de pendientes. Ver la sección 4 |

Cada archivo trae su bloque de **VERIFICACIÓN ejecutable al final** (SELECT reales, no
comentados — el rollback sí va comentado). **Correrlo entero después de cada script y leer el
resultado**, no sólo mirar que no haya salido un error.

V33 además trae un **ALTER de remediación comentado** para el caso de tabla preexistente sin
los campos de versionado (se activa sólo si su verificación 7 devuelve menos de 4). V35 trae el
equivalente en su bloque **5.C** para el charset de `moneda`/`ventana`.

### La regla de charset del paquete (para no leerla como incoherente)

V32 declara `nro_doc` **latin1** a propósito y V35 declara `moneda`/`ventana` **utf8mb4** a
propósito, en una tabla que es latin1. No es contradicción, es una sola regla:

> **Cada columna toma el charset de aquello contra lo que se la va a comparar.**
> `nro_doc` se joinea contra `cs.afiliados` (latin1) → latin1.
> `ventana` y `moneda` se resuelven contra `polizas_ap_topes` (utf8mb4) → utf8mb4.

### Lo puntual que hay que verificar en V32

Dos cosas, y ninguna es negociable:

```sql
-- 1) `nro_doc` tiene que estar en latin1 / latin1_swedish_ci.
--    Si devuelve utf8mb4, la tabla NO se creó con este archivo: hay que recrearla
--    (o ALTERear la columna) ANTES de cargar un solo tope.
SELECT `COLUMN_NAME`, `COLUMN_TYPE`, `CHARACTER_SET_NAME`, `COLLATION_NAME`
  FROM `INFORMATION_SCHEMA`.`COLUMNS`
 WHERE `TABLE_SCHEMA` = 'cs'
   AND `TABLE_NAME`   = 'polizas_ap_topes'
   AND `COLUMN_NAME`  = 'nro_doc';
-- ESPERADO: varchar(50) | latin1 | latin1_swedish_ci

-- 2) La UNIQUE existe y es (id_poliza, nro_doc, ventana) — 3 columnas, en ese orden.
--    NON_UNIQUE tiene que ser 0. Si falta, el control de duplicados no existe.
SELECT `INDEX_NAME`, `NON_UNIQUE`, `SEQ_IN_INDEX`, `COLUMN_NAME`
  FROM `INFORMATION_SCHEMA`.`STATISTICS`
 WHERE `TABLE_SCHEMA` = 'cs'
   AND `TABLE_NAME`   = 'polizas_ap_topes'
   AND `INDEX_NAME`   = 'uk_polizas_ap_topes_poliza_doc_ventana'
 ORDER BY `SEQ_IN_INDEX`;
-- ESPERADO: 3 filas, NON_UNIQUE = 0, en orden id_poliza / nro_doc / ventana
```

Y la prueba que no miente, porque ejecuta el join real (con la tabla vacía da 0 filas; lo que
se está probando es que **compile**):

```sql
SELECT COUNT(*) AS joins_ok
  FROM `cs`.`polizas_ap_topes` t
  JOIN `cs`.`afiliados` a ON a.`nro_doc` = t.`nro_doc`;
```

---

## 7. La UNIQUE de V32 no alcanza sola: el documento tiene que llegar normalizado

Que la UNIQUE exista es condición necesaria y no suficiente. `nro_doc` es texto libre, así que
para el índice `'12345678'`, `'012345678'` y `'12.345.678'` son **tres claves distintas**: la
misma persona con tres topes activos, y el UNIQUE aceptándolos sin un error.

Normalizar **es responsabilidad del servicio** (sin puntos, sin espacios, sin guiones, sin
ceros a la izquierda, antes de insertar). Está documentado en el `COMMENT` de la columna y en
la nota 4.d de V32. Consecuencia operativa: **no cargar topes con un `INSERT` suelto ni con
una carga masiva que no normalice**. Si igual se hizo, la verificación 7 de V32 lo detecta —
correrla después de cada carga de topes.

Esto aplica a las **excepciones**. El **tope general** de V35 no tiene el problema: es una
columna por póliza, sin clave compuesta por documento.

---

## 8. Qué NO revierte el rollback

Los rollbacks están comentados en cada archivo, y son `DROP TABLE` / `DROP COLUMN`. Devuelven
la estructura, pero:

- **Los topes cargados por negocio se pierden.** `polizas_ap_topes` y su historial son datos de
  negocio, no estructura: son la planilla que negocio dejó de mantener a mano. Cualquier
  rollback posterior a la primera carga tiene que respaldarlos antes:

```sql
CREATE TABLE cs.polizas_ap_topes_respaldo           AS SELECT * FROM cs.polizas_ap_topes;
CREATE TABLE cs.polizas_ap_topes_historial_respaldo AS SELECT * FROM cs.polizas_ap_topes_historial;
```

- **El rollback de V35 es el más caro de los cuatro, y el único sin red.** Los topes generales
  **no existen en ningún otro lado**: `polizas_ap` no tiene tabla de historial (las excepciones
  sí, por V33), así que un `DROP COLUMN suma_asegurada` borra el trabajo de carga de negocio y
  **no se reconstruye solo**. Las excepciones de `polizas_ap_topes` son *otro dato*, no una
  copia del general. Respaldar antes:

```sql
CREATE TABLE cs.polizas_ap_respaldo_v35 AS
  SELECT id_poliza, poliza, suma_asegurada, iva_incluido, moneda, ventana FROM cs.polizas_ap;
```

  Y el `CHECK` se dropea **primero**: `DROP COLUMN` con el `CHECK` vivo encima falla. El orden
  está en el bloque 6 de V35.

- **El `DROP COLUMN` de V34 borra el resultado del backfill**, no sólo las columnas: volver a
  aplicarlo obliga a rehacer el bloque 3 completo. Es el menos grave de los cuatro, porque ese
  cache se reconstruye desde `polizas_ap_topes` + `polizas_ap`, que el rollback de V34 no toca.
- `uk_denuncia_poliza_activo` (id_denuncia, activo) en `denuncia_poliza` es un **UNIQUE
  preexistente del legacy, con un bug conocido**. No lo toca ninguno de estos scripts y **no
  hay que tocarlo acá**: si hay que arreglarlo, va en su propio cambio con su propio análisis.

---

## Renumeracion del 10/08/2026 — por que este paquete NO usa `V<N>__`

Estos scripts arrancaron como `V32__` a `V36__` en `src/main/resources/sql/`, y hubo
una **colision real**: `wsmesacarga` ya tiene commiteado
`V32__FIX_predicado_sargable_patologia_trazadora.sql` (commit `34e2f2e`, 07/08/2026,
change `DE-01-intake`). El repo no tiene Flyway ni tabla de control, asi que dos
archivos con el mismo numero no fallan: simplemente conviven y el orden queda
ambiguo para quien los aplique a mano.

Se resolvio adoptando el patron de **subcarpeta por paquete de trabajo** que ya usa
`wsauditoriatraslados` (`sql/migracion_auditoria_agencia/001_..017`): numeracion
propia dentro de la carpeta, cero colision con la secuencia global del repo, y el
paquete se lee completo y en orden.

**Correspondencia con lo YA APLICADO en dev y stage** (se aplicaron con los nombres
viejos; las tablas y columnas son las mismas, solo cambio el nombre del archivo):

| Nombre viejo | Nombre actual |
|---|---|
| `V32__CREATE_polizas_ap_topes.sql` | `001_create_polizas_ap_topes.sql` |
| `V33__CREATE_polizas_ap_topes_historial.sql` | `002_create_polizas_ap_topes_historial.sql` |
| `V34__ALTER_denuncia_poliza_ADD_tope.sql` | `003_alter_denuncia_poliza_add_tope.sql` |
| `V35__ALTER_polizas_ap_ADD_suma_asegurada.sql` | `004_alter_polizas_ap_add_suma_asegurada.sql` |
| `V36__ALTER_polizas_ap_topes_historial_ADD_id_poliza.sql` | `005_alter_polizas_ap_topes_historial_add_id_poliza.sql` |

Los cinco estan aplicados y verificados en **dev** y **stage** al 10/08/2026.
En produccion todavia no se aplico ninguno.
