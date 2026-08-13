# Despliegue a PRODUCCIÓN — GRV-2239 / SE-258

**Estado verificado contra la base de producción el 13/08/2026 (lectura).**

MRs a `master`, creadas y sin mergear, con labels `intake` y `master`:

| Repo | MR | Commits |
|---|---|---:|
| `backend/wscie10` | [!74](https://gitlab.com/grvx/backend/wscie10/-/merge_requests/74) | 5 |
| `backend/wsauditoria` | [!816](https://gitlab.com/grvx/backend/wsauditoria/-/merge_requests/816) | 2 |
| `backend/wsturnos` | [!832](https://gitlab.com/grvx/backend/wsturnos/-/merge_requests/832) | 5 |
| `frontend/auditoriamedica` | [!751](https://gitlab.com/grvx/frontend/auditoriamedica/-/merge_requests/751) | 2 |

---

## 0. Estado previo en producción — verificado

Nada de lo que crea este despliegue existe todavía. **Los tres scripts se aplican limpios.**

| Objeto | Estado en prod |
|---|---|
| `autorizaciones.es_aprobacion_automatica` | **No existe** |
| `diagnosticos_cie10.edicion_bloqueada` | **No existe** |
| Parámetro `BLOQUEO_EDICION_CIE10` | **No existe** |
| Permiso `editar_cie10_bloqueado` | **No existe** |

Los cuatro códigos están **idénticos entre sí**, en los valores que el change viene a corregir:

| Código | `id_severidad` | días leve/mod/grave | `habilita_autoaprobacion` | Denuncias |
|---|---:|---|---:|---:|
| `S31.8` | 1 | 10 / 10 / 10 | 1 | 26 |
| `S61.8` | 1 | 10 / 10 / 10 | 1 | 535 |
| `T06.8` | 1 | 10 / 10 / 10 | 1 | 3.539 |
| `T14.1` | 1 | 10 / 10 / 10 | 1 | 42 |
| | | | | **4.142** |

`cs.autorizaciones` tiene **2.238.224 filas**. Ver el punto 4 antes de correr el `ALTER`.

> Como los cuatro comparten exactamente los mismos valores previos, el rollback del catálogo es un único `UPDATE` con constantes. No hace falta guardar una copia fila por fila.

---

## 1. El SQL, en orden

> **Correr ANTES de desplegar.** Las entidades JPA mapean las dos columnas nuevas: si el código sube antes que los `ALTER`, **los servicios no arrancan**.

| # | Script | Qué hace | Dónde está |
|---|---|---|---|
| 1 | `GRV-2239-01-alter-autorizaciones-aprobacion-automatica.sql` | Columna `autorizaciones.es_aprobacion_automatica` | `wsturnos/src/main/resources/sql/scripts/` |
| 2 | `GRV-2239-bloqueo-edicion-cie10.sql` | Columna `edicion_bloqueada`, marca de los 4 códigos, parámetro y permiso | `wscie10/src/main/resources/sql/migrations/` |
| 3 | `GRV-2239-02-cie10-trazadores-severidad-dias.sql` | Severidad, días y apagado de autoaprobación de los 4 códigos | `wsturnos/src/main/resources/sql/scripts/` |

**El 3 va último a propósito**: minimiza la ventana en que el catálogo queda en Grave sin el código nuevo desplegado, y evita chocar con el `ALTER` del script 2 sobre la misma tabla.

```sql
-- Que falle rápido si hay contención, en vez de encolar la plataforma.
-- El lock_wait_timeout global de estos servidores es de 24 horas.
SET SESSION lock_wait_timeout = 5;

-- ============================================================
-- 1) autorizaciones.es_aprobacion_automatica
-- ============================================================
-- INSTANT: cambio de metadatos, no reconstruye la tabla pese a los 2,2 M de filas.
-- No necesita ventana de mantenimiento — pero ver el punto 4 sobre el horario.
-- NO cambiar a NOT NULL: la entidad la mapea y los caminos que no la setean mandan NULL.
ALTER TABLE `cs`.`autorizaciones`
  ADD COLUMN IF NOT EXISTS `es_aprobacion_automatica` TINYINT(1) NULL DEFAULT 0
  COMMENT 'GRV-2239: 1 = aprobada automáticamente por el protocolo de leves; 0/NULL = no',
  ALGORITHM=INSTANT;

-- ============================================================
-- 2) Bloqueo de edición del CIE-10
-- ============================================================
-- NULL y no NOT NULL: 15 entidades JPA mapean esta tabla y ninguna usa @DynamicInsert,
-- así que un alta mandaría NULL explícito y un NOT NULL daría error 1048.
ALTER TABLE `cs`.`diagnosticos_cie10`
  ADD COLUMN IF NOT EXISTS `edicion_bloqueada` TINYINT(1) NULL DEFAULT 0
  COMMENT 'GRV-2239: 1 = el auditor médico no puede cambiar el CIE-10 de una denuncia que tenga este código',
  ALGORITHM=INSTANT;

UPDATE `cs`.`diagnosticos_cie10`
   SET edicion_bloqueada = 1
 WHERE codigo IN ('S31.8', 'T14.1', 'T06.8', 'S61.8');
-- Esperado: 4 filas afectadas

-- Kill switch. Va ENCENDIDO: el permiso no se asigna a nadie y las correcciones
-- puntuales se resuelven por Mesa de Ayuda sobre la base (Anexo A del plan de pruebas).
INSERT INTO `cs`.`parametros` (`param_name`, `param_value`)
VALUES ('BLOQUEO_EDICION_CIE10', '1')
ON DUPLICATE KEY UPDATE `param_value` = `param_value`;

-- usuario_alta es NOT NULL SIN default y el servidor corre con STRICT_TRANS_TABLES:
-- omitirla da error 1364. 2004 es el usuario técnico de las últimas altas de permisos.
INSERT INTO `cs`.`permisos_sas` (`permiso`, `descripcion`, `activo`, `usuario_alta`)
SELECT 'editar_cie10_bloqueado',
       'Permite corregir el CIE-10 en denuncias con código de patología trazadora bloqueado',
       1,
       2004
  FROM DUAL
 WHERE NOT EXISTS (
       SELECT 1 FROM `cs`.`permisos_sas` WHERE `permiso` = 'editar_cie10_bloqueado');

-- ============================================================
-- 3) Catálogo de los 4 CIE-10 trazadores
-- ============================================================
-- ⚠️ EN SESIÓN INTERACTIVA, NUNCA POR RUNNER: el COMMIT va comentado a propósito
-- para revisar la verificación antes de confirmar. Ver el punto 4.

-- Estado previo, para dejar registro en el log de la corrida
SELECT codigo, id_severidad, dias_baja_leve, dias_baja_moderado, dias_baja_grave,
       habilita_autoaprobacion
  FROM `cs`.`diagnosticos_cie10`
 WHERE codigo IN ('S31.8', 'T14.1', 'T06.8', 'S61.8');
-- Esperado (verificado en prod el 13/08): id_severidad = 1, los tres días = 10,
-- habilita_autoaprobacion = 1, en los cuatro.
-- Si algún valor difiere, PARAR: alguien tocó el catálogo y hay que rehacer el rollback.

START TRANSACTION;

UPDATE `cs`.`diagnosticos_cie10`
   SET id_severidad       = 2,   -- Grave, escala del catálogo
       dias_baja_leve     = 120,
       dias_baja_moderado = 120,
       dias_baja_grave    = 120
 WHERE codigo IN ('S31.8', 'T14.1', 'T06.8', 'S61.8');

-- Subir la severidad NO alcanza: el único interruptor por código es este flag.
UPDATE `cs`.`diagnosticos_cie10`
   SET habilita_autoaprobacion = 0
 WHERE codigo IN ('S31.8', 'T14.1', 'T06.8', 'S61.8');

-- Verificación DENTRO de la transacción — revisar antes de confirmar
SELECT codigo, id_severidad, dias_baja_leve, dias_baja_moderado, dias_baja_grave,
       habilita_autoaprobacion
  FROM `cs`.`diagnosticos_cie10`
 WHERE codigo IN ('S31.8', 'T14.1', 'T06.8', 'S61.8');
-- Esperado: 4 filas, id_severidad = 2, los tres días = 120, habilita_autoaprobacion = 0

-- COMMIT;
-- ROLLBACK;
```

---

## 2. Verificación posterior

```sql
SELECT codigo, id_severidad, dias_baja_leve, dias_baja_moderado, dias_baja_grave,
       habilita_autoaprobacion, edicion_bloqueada
  FROM `cs`.`diagnosticos_cie10`
 WHERE codigo IN ('S31.8','T14.1','T06.8','S61.8');
-- 4 filas: severidad 2, días 120/120/120, autoaprobación 0, bloqueo 1

SELECT param_name, param_value FROM `cs`.`parametros`
 WHERE param_name = 'BLOQUEO_EDICION_CIE10';                       -- 1 fila, valor '1'

SELECT id_permiso, permiso, activo FROM `cs`.`permisos_sas`
 WHERE permiso = 'editar_cie10_bloqueado';                          -- 1 fila, activo 1

SHOW COLUMNS FROM `cs`.`autorizaciones`     LIKE 'es_aprobacion_automatica';
SHOW COLUMNS FROM `cs`.`diagnosticos_cie10` LIKE 'edicion_bloqueada';
```

**Que el permiso no le haya quedado a nadie** — es la decisión tomada, y conviene confirmarlo:

```sql
SELECT COUNT(*) AS perfiles_con_el_permiso
  FROM `cs`.`perfiles_permisos_sas` pp
  JOIN `cs`.`permisos_sas` p ON p.id_permiso = pp.id_permiso
 WHERE p.permiso = 'editar_cie10_bloqueado';
-- Esperado: 0
```

**Que la autoaprobación esté funcionando**, a las pocas horas del deploy:

```sql
SELECT DATE(fecha_solicitud) AS dia, COUNT(*) AS autoaprobadas
  FROM `cs`.`autorizaciones`
 WHERE es_aprobacion_automatica = 1
   AND fecha_solicitud >= CURDATE()
 GROUP BY DATE(fecha_solicitud);
```

Si a las pocas horas devuelve 0 filas, algo no está andando: revisar que `wsturnos` haya levantado con la versión nueva.

---

## 3. Rollback

Los valores previos están **verificados en producción**, y los cuatro códigos comparten los mismos.

```sql
-- a) Apagar el bloqueo de edición, en caliente y sin desplegar:
UPDATE `cs`.`parametros` SET param_value = '0'
 WHERE param_name = 'BLOQUEO_EDICION_CIE10';

-- b) Revertir el catálogo a los valores previos:
UPDATE `cs`.`diagnosticos_cie10`
   SET id_severidad = 1, dias_baja_leve = 10, dias_baja_moderado = 10, dias_baja_grave = 10,
       habilita_autoaprobacion = 1, edicion_bloqueada = 0
 WHERE codigo IN ('S31.8','T14.1','T06.8','S61.8');

-- c) La autoaprobación de protocolo se revierte por deploy, no por SQL:
--    volver atrás wsturnos. No hay parámetro que la apague.
```

> **NO dropear las columnas.** `DROP COLUMN` sí reconstruye la tabla, y `autorizaciones` tiene 2,2 M de filas. Para revertir el comportamiento alcanza con revertir el deploy; las columnas quedan inertes y no molestan.

---

## 4. Advertencias de ejecución

**El `ALTER` sobre `cs.autorizaciones` es instantáneo** pese a los 2,2 M de filas, porque `ALGORITHM=INSTANT` sólo toca metadatos. **No necesita ventana de mantenimiento.** El riesgo no es el volumen sino el **lock de metadatos** que necesita para entrar: si hay una consulta larga en curso, espera. Por eso el `lock_wait_timeout` corto, y por eso conviene **evitar la primera hora de la mañana**, cuando corren los SPs de tableros que hacen `CREATE TABLE ... AS SELECT` sobre esa tabla.

**El script 3 va sí o sí en sesión interactiva.** Si se corre por un runner, la transacción queda abierta con los locks tomados sobre el catálogo CIE-10 y, con el `lock_wait_timeout` global de 24 horas, cualquier `ALTER` posterior encola las lecturas de media plataforma.

**Orden de deploy, después del SQL:** `wscie10` → `wsauditoria` → `wsturnos` → `auditoriamedica`.

---

## 5. Qué va a cambiar a la vista, el día del deploy

No se modifica ningún dato de denuncias existentes. Pero los 120 días del catálogo **se leen en vivo** en tres consultas, así que el valor nuevo aparece también en denuncias viejas, incluidas las cerradas:

| Dónde | Qué cambia |
|---|---|
| Grilla del auditor (`s_auditoria_medica_view`) | La columna «días CIE-10» pasa de 10 a 120 en las **4.142** denuncias con esos códigos |
| Indicador «a vencer» | El umbral es `dias_baja_leve * 0.5`: pasa de avisar 5 días antes a **60**. Van a aparecer denuncias que hoy no figuraban |
| ILT vencidas y buscador de auditoría médica | Mismo corrimiento |

Además, en la escala del catálogo **Grave implica sin tope de prestaciones** en `CalculadoraTopesCie10` — que es el comportamiento buscado para un politraumatismo o una herida por arma de fuego.

El grueso del ruido lo aporta `T06.8` con 3.539 denuncias; los otros tres suman 603 entre los tres.

---

## 6. Antes de dar el OK a PRODUCCIÓN

- [ ] **QA revalidó en TEST el estado del turno en FKT autoaprobada** (el fix de !828, promovido a TEST el 13/08).
- [ ] **Auditoría Médica está avisada** de lo que enumera el punto 5, en particular el corrimiento del indicador «a vencer», que es el que miran todos los días.
- [ ] Está claro que el permiso `editar_cie10_bloqueado` **no se asigna a nadie** y que las correcciones puntuales van por Mesa de Ayuda sobre la base (Anexo A del plan de pruebas).
- [ ] El SQL corre **antes** que el deploy, y el script 3 en sesión interactiva.
