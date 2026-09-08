# Despliegue a STAGE — GRV-2239 / SE-258

**Ramas listas y compiladas.** Falta crear las MRs, correr el SQL y desplegar.

---

## 1. El SQL que hay que correr

> **Correr ANTES de desplegar.** Las entidades JPA mapean las dos columnas nuevas: si el código sube antes que el `ALTER`, los servicios no arrancan.
>
> **Base de STAGE.** El host sale de `application-stage.properties` de cualquiera de los ws.

### Orden de ejecución

| # | Script | Qué hace | Dónde está |
|---|---|---|---|
| 1 | `GRV-2239-01-alter-autorizaciones-aprobacion-automatica.sql` | Columna `autorizaciones.es_aprobacion_automatica` | `wsturnos/src/main/resources/sql/scripts/` |
| 2 | `GRV-2239-bloqueo-edicion-cie10.sql` | Columna `edicion_bloqueada`, marca de los 4 códigos, parámetro y permiso | `wscie10/src/main/resources/sql/migrations/` |
| 3 | `GRV-2239-02-cie10-trazadores-severidad-dias.sql` | Severidad, días y apagado de autoaprobación de los 4 códigos | `wsturnos/src/main/resources/sql/scripts/` |

**El 3 va último a propósito**: minimiza la ventana en que el catálogo queda en Grave sin el código nuevo desplegado, y evita chocar con el `ALTER` del script 2 sobre la misma tabla.

### Contenido, en orden

```sql
-- Que falle rápido si hay contención, en vez de encolar la plataforma.
-- El lock_wait_timeout global de estos servidores es de 24 horas.
SET SESSION lock_wait_timeout = 5;

-- ============================================================
-- 1) autorizaciones.es_aprobacion_automatica
-- ============================================================
-- INSTANT: cambio de metadatos, no reconstruye la tabla. No necesita ventana de
-- mantenimiento, pero conviene evitar el pico de tableros de la mañana.
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
-- para revisar la verificación antes de confirmar.

-- Estado previo, para dejar registro
SELECT codigo, id_severidad, dias_baja_leve, dias_baja_moderado, dias_baja_grave,
       habilita_autoaprobacion
  FROM `cs`.`diagnosticos_cie10`
 WHERE codigo IN ('S31.8', 'T14.1', 'T06.8', 'S61.8');
-- Esperado antes: id_severidad = 1, los tres días = 10, habilita_autoaprobacion = 1

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

### Verificación posterior

```sql
SELECT codigo, id_severidad, dias_baja_leve, habilita_autoaprobacion, edicion_bloqueada
  FROM `cs`.`diagnosticos_cie10`
 WHERE codigo IN ('S31.8','T14.1','T06.8','S61.8');
SELECT * FROM `cs`.`parametros` WHERE param_name = 'BLOQUEO_EDICION_CIE10';
SELECT id_permiso, permiso, activo FROM `cs`.`permisos_sas` WHERE permiso = 'editar_cie10_bloqueado';
SHOW COLUMNS FROM `cs`.`autorizaciones`     LIKE 'es_aprobacion_automatica';
SHOW COLUMNS FROM `cs`.`diagnosticos_cie10` LIKE 'edicion_bloqueada';
```

### Rollback

```sql
-- Apagar el bloqueo, en caliente y sin desplegar:
UPDATE `cs`.`parametros` SET param_value = '0' WHERE param_name = 'BLOQUEO_EDICION_CIE10';

-- Revertir el catálogo (valores previos verificados):
UPDATE `cs`.`diagnosticos_cie10`
   SET id_severidad = 1, dias_baja_leve = 10, dias_baja_moderado = 10, dias_baja_grave = 10,
       habilita_autoaprobacion = 1
 WHERE codigo IN ('S31.8','T14.1','T06.8','S61.8');

-- NO dropear las columnas: DROP COLUMN sí reconstruye la tabla (1,2 GB en autorizaciones).
-- Para revertir el comportamiento alcanza con revertir el deploy; las columnas quedan inertes.
```

---

## 2. Ramas de promoción — listas y compiladas

Todas se llaman **`promo/GRV-2239-stage`** y salen de `origin/stage`, con cherry-pick selectivo de los commits de GRV-2239. **No se mergea `develop` ni `release` entero**: arrastran resumen clínico, SE66, SE-260 y reca.

| Repo | Commits | Nota |
|---|---:|---|
| `backend/wscie10` | 5 | |
| `backend/wsauditoria` | 2 | Hubo **conflicto resuelto a mano**: `stage` ya tenía el `@Autowired` de `RecalificacionHelper` en la misma posición. Se conservan los dos |
| `backend/wsturnos` | 4 | Incluye el fix de BUG-001 (AUT-14) y el cupo «hasta 3» |
| `frontend/auditoriamedica` | 2 | |

Los tres backend compilan sobre `stage` (`mvn clean compile`).

### Orden de deploy

`wscie10` → `wsauditoria` → `wsturnos` → `auditoriamedica`

---

## 3. Antes de dar el OK a STAGE

- [ ] **QA aprobó en TEST**, incluido el reejecutado de AUT-14 con el fix, y los casos nuevos AUT-04b, AUT-14b y AUT-14c.
- [ ] **Auditoría Médica confirmó por escrito** los seis efectos del cambio de catálogo. El más visible: el indicador «a vencer» pasa de avisar 5 días antes a 60.
- [ ] Está claro que el permiso `editar_cie10_bloqueado` **no se asigna a nadie** y que las correcciones van por Mesa de Ayuda sobre la base.

## 4. Advertencias de ejecución

**El `ALTER` sobre `cs.autorizaciones` es instantáneo** pese al tamaño de la tabla —2,2 M de filas en producción— porque es un cambio de metadatos. **No necesita ventana de mantenimiento.** El riesgo no es el volumen sino el lock de metadatos que necesita para entrar: si hay una consulta larga en curso, espera. Por eso el `lock_wait_timeout` corto, y por eso conviene evitar la primera hora de la mañana, cuando corren los SPs de tableros que hacen `CREATE TABLE ... AS SELECT` sobre esa tabla.

**El script 3 va sí o sí en sesión interactiva.** Si se corre por un runner, la transacción queda abierta con los locks tomados sobre el catálogo CIE-10 y, con el `lock_wait_timeout` global de 24 horas, cualquier `ALTER` posterior encola las lecturas de media plataforma.
