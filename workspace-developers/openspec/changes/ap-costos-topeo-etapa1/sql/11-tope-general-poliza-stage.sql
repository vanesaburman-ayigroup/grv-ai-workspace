-- -----------------------------------------------------------------------------
-- 11 — TOPE GENERAL DE PÓLIZA: columna nueva + datos de prueba (DEV / STAGE)
-- -----------------------------------------------------------------------------
-- Change OpenSpec: ap-costos-topeo-etapa1
-- Autor: Vanesa Burman — Fecha: 2026-08-10
-- Ambientes: DEV y STAGE. Aplicado y verificado el 2026-08-10.
--
-- POR QUÉ EXISTE
-- El modelo del tope quedó cerrado el 10/08/2026 como TOPE GENERAL DE PÓLIZA +
-- EXCEPCIONES. En la reunión el cliente lo dijo así: "aseguro a todos mis
-- empleados por cinco millones, A CADA UNO". Es decir: el monto es el mismo
-- para todos los asegurados de la póliza y se aplica individualmente a cada
-- uno, y `cs`.`polizas_ap_topes` guarda SÓLO a los que se apartan de ese
-- número (o a los que se les autorizó una ampliación).
--
-- Ese tope general necesita una columna que no existía:
-- `cs`.`polizas_ap`.`suma_asegurada`.
--
-- QUIÉN ES EL DUEÑO DE LA COLUMNA
-- `polizas_ap` es de **wsmesacarga**, así que la MIGRACIÓN VERSIONADA de esta
-- columna es un entregable de ese repo (V35, en
-- sql/migrations/wsmesacarga/), junto con el alta obligatoria del tope en la
-- pantalla de la póliza. Este archivo NO la reemplaza: aplica exactamente el
-- mismo ALTER (idempotente, con IF NOT EXISTS) en dev y stage para poder
-- desbloquear la resolución del tope en vivo del motor de consumo de
-- wsaccidentespersonales y regenerar el fixture de paridad. Si la migración de
-- wsmesacarga corre después, el IF NOT EXISTS la deja pasar sin efecto.
--
-- NULLABLE a propósito: en stage ya hay 30 pólizas cargadas sin tope general.
-- La obligatoriedad es del ALTA (validación de wsmesacarga), no de la columna:
-- un NOT NULL con default inventaría un tope para todo lo viejo, que es
-- justamente lo que el semáforo no tiene que hacer.
--
-- Falta decidir con negocio (NO se asumió acá):
--   · si la columna merece un CHECK (suma_asegurada > 0). El motor ya trata el
--     cero como "sin tope", así que hoy no cambia el resultado.
--   · si el tope general necesita ventana / moneda propias. Hoy el motor
--     devuelve ventana NULL y deja que el servicio aplique el default ARS.
-- -----------------------------------------------------------------------------


-- =============================================================================
-- 1) LA COLUMNA (dev y stage). Idempotente.
-- =============================================================================
ALTER TABLE cs.polizas_ap
  ADD COLUMN IF NOT EXISTS suma_asegurada DECIMAL(16,2) DEFAULT NULL
  COMMENT 'Tope GENERAL de la poliza, CON IVA incluido. Aplica a CADA asegurado de la poliza por separado (no es una bolsa comun). Obligatorio en el alta de la poliza; NULL solo en las polizas cargadas antes de este cambio. Las excepciones por asegurado van en polizas_ap_topes y PISAN a este valor. DECIMAL, nunca float'
  AFTER detalle_cobertura;


-- =============================================================================
-- 2) DATOS DE PRUEBA — SÓLO STAGE
-- =============================================================================
-- NO son topes de negocio: son el denominador sintético que hace que el motor
-- produzca los 6 niveles del semáforo y las 3 ramas de la resolución del tope
-- (EXCEPCION / GENERAL / SIN_TOPE) con consumo REAL de stage.
--
-- `polizas_ap` no tiene columna de observación ni historial, así que estos
-- valores NO quedan marcados como dato de prueba en la base. La marca es este
-- archivo. El cleanup está al pie.
--
-- ⚠ REVISIÓN DEL 2026-08-10 (tarde) — LOS VALORES CAMBIARON. LEER.
-- La primera carga puso topes generales CHICOS (200.000 / 500.000 / 70.000) para
-- forzar que el semáforo dibujara MEDIO y MUY_ALTO. Eso estaba mal ubicado: un
-- tope general de 70.000 no existe en el negocio (Verónica habló de 5.000.000,
-- 6.000.000 y 8.000.000 POR ASEGURADO) y hacía que la demo a negocio se apoyara
-- en un número que nadie va a reconocer.
--
-- El recorte se movió a donde el modelo dice que va: el tope GENERAL quedó
-- realista en las 7 pólizas con denuncias activas, y los asegurados que topean
-- bajo pasaron a ser EXCEPCIONES en `cs`.`polizas_ap_topes` (bloque 2.B). El
-- semáforo sigue dibujando los 5 niveles, pero ahora por el motivo correcto.
--
-- CONSECUENCIA QUE HAY QUE DECIRLE A NEGOCIO, no esconder: con el tope general
-- realista, 50 de 61 siniestros AP de stage quedan en BAJO y ninguno pasa del
-- 4% del tope. El valor del semáforo NO está en la cartera general: está en los
-- asegurados con tope reducido/excepción y en los pocos casos con cirugía. Si se
-- espera "ver muchos amarillos", la expectativa está mal calibrada.

-- -----------------------------------------------------------------------------
-- 2.A) TOPE GENERAL REALISTA — las 7 pólizas con denuncias AP activas en stage
-- -----------------------------------------------------------------------------
--   póliza 46 '983320' (51 siniestros): 5.000.000  ← el número que dijo Verónica
--   póliza 28 '17885'  ( 3 siniestros): 6.000.000
--   póliza 45 '982176' ( 2 siniestros): 6.000.000
--   póliza 51 '983781' ( 2 siniestros): 8.000.000
--   póliza 52 '983881' ( 1 siniestro) : 8.000.000
--   póliza 29 '847797' ( 1 siniestro) : 5.000.000
--   póliza 43 '981398' ( 1 siniestro) : 5.000.000
--
-- NO queda ninguna póliza con denuncias activas sin tope general: SIN_TOPE pasa
-- de 54 (antes de la resolución en vivo) a 0. El caso de control de SIN_TOPE ya
-- no se cubre con datos de stage — se cubre con test unitario
-- (`SemaforoApEscalaTest`), que es donde corresponde: un caso de control que
-- depende de que nadie cargue un tope en un ambiente compartido no es un control.
--
-- El WHERE por valor esperado (y no `IS NULL`) es lo que hace esto re-corrible:
-- pisa los valores chicos de la primera carga y NO pisa un tope que alguien haya
-- cargado después desde la pantalla de la póliza.
UPDATE cs.polizas_ap SET suma_asegurada = 5000000.00 WHERE id_poliza = 46 AND (suma_asegurada IS NULL OR suma_asegurada = 5000000.00);
UPDATE cs.polizas_ap SET suma_asegurada = 6000000.00 WHERE id_poliza = 28 AND (suma_asegurada IS NULL OR suma_asegurada =  200000.00);
UPDATE cs.polizas_ap SET suma_asegurada = 6000000.00 WHERE id_poliza = 45 AND (suma_asegurada IS NULL OR suma_asegurada =  500000.00);
UPDATE cs.polizas_ap SET suma_asegurada = 8000000.00 WHERE id_poliza = 51 AND  suma_asegurada IS NULL;
UPDATE cs.polizas_ap SET suma_asegurada = 8000000.00 WHERE id_poliza = 52 AND (suma_asegurada IS NULL OR suma_asegurada =   70000.00);
UPDATE cs.polizas_ap SET suma_asegurada = 5000000.00 WHERE id_poliza = 29 AND  suma_asegurada IS NULL;
UPDATE cs.polizas_ap SET suma_asegurada = 5000000.00 WHERE id_poliza = 43 AND  suma_asegurada IS NULL;

-- -----------------------------------------------------------------------------
-- 2.B) EXCEPCIONES nuevas — 5 filas (id_tope 8..12)
-- -----------------------------------------------------------------------------
-- Estas SÍ quedan marcadas en la base: el motivo del historial arranca con
-- 'DATO DE PRUEBA ap-costos-topeo-etapa1', que es por donde las borra el 99.
--
--   (52, doc 46900519,     70.000,00) → SW498032: reubica como excepción el tope
--                                       general chico. Sigue en MUY_ALTO 90,36%.
--   (28, doc 55358305,    200.000,00) → SW475289: idem. MEDIO 42,57%.
--   (28, doc 53802912,    200.000,00) → SW479979: idem. MEDIO 49,97%.
--   (46, doc 25549372,    400.000,00) → SW496878: VERIFICA que la excepción pisa
--                                       al general de 5.000.000. BAJO 3,97% →
--                                       MEDIO 49,64%, origen EXCEPCION.
--   (46, doc 39804776,    190.704,77) → SW510548: VERIFICA el borde. El tope es
--                                       EXACTAMENTE la proyección, así que da
--                                       100,00% y tiene que salir MUY_ALTO
--                                       (EXCEDIDO se decide comparando montos:
--                                       proyección > tope, y acá es igual).
--                                       El monto es absurdo como tope de negocio
--                                       — es un caso de borde, no un tope.
--
-- Se cargan con el script `ap_cargar_topes_stage.py --aplicar` (replica campo por
-- campo lo que escribe TopeApServiceImpl.crear + TopeApHistorialAsentador
-- .asentarAlta) porque wsaccidentespersonales todavía NO está desplegado en
-- stage: el Jenkinsfile sólo tiene el stage de PROD. Cuando el ws esté arriba,
-- esto se hace por POST /api/v1/ap/topes y este bloque deja de existir.
--
-- ⚠ Una excepción es por (id_poliza, nro_doc, ventana), NO por siniestro: aplica
-- a TODAS las denuncias activas de ese asegurado en esa póliza. Los 5 documentos
-- elegidos tienen exactamente 1 denuncia AP activa cada uno (verificado), así que
-- el efecto es de a un caso. Si mañana el asegurado tiene otro siniestro, hereda
-- la excepción — y eso es lo correcto, no un efecto colateral.


-- =============================================================================
-- 3) VERIFICACIÓN (lo que devolvió stage el 2026-08-10)
-- =============================================================================
-- Se corre con `ap_semaforo_e2e.py --tabla`, que EXTRAE el SQL de la constante
-- MotorConsumoSql.MOTOR del propio repo (no una copia) y aplica la escala de
-- SemaforoApServiceImpl. Parámetros vigentes: umbral_bajo 40,00 · umbral_medio
-- 70,00 (90 y 100 fijos en código).
--
--   ANTES · sin ningún tope general    → SIN_TOPE 54 · BAJO 1 · MEDIO 1 · ALTO 1
--                                        · MUY_ALTO 1 · EXCEDIDO 3
--                                        (origen: EXCEPCION 7 · SIN_TOPE 54)
--   ANTES · con los topes chicos       → SIN_TOPE 4 · BAJO 48 · MEDIO 3 · ALTO 1
--     (primera carga del 10/08)          · MUY_ALTO 2 · EXCEDIDO 3
--                                        (origen: EXCEPCION 7 · GENERAL 50 · SIN_TOPE 4)
--   DESPUÉS · tope realista + 5 excep. → SIN_TOPE 0 · BAJO 50 · MEDIO 4 · ALTO 1
--                                        · MUY_ALTO 3 · EXCEDIDO 3
--                                        (origen: EXCEPCION 12 · GENERAL 49)
--
-- Los 5 niveles de la escala quedan poblados y NINGÚN siniestro queda sin
-- semáforo.
SELECT id_poliza, poliza, suma_asegurada
  FROM cs.polizas_ap
 WHERE suma_asegurada IS NOT NULL
 ORDER BY id_poliza;


-- =============================================================================
-- 4) CLEANUP
-- =============================================================================
-- El rollback vive en 99-cleanup-datos-prueba-stage.sql (bloque 7 para el tope
-- general, y los bloques 1..5 ya cubren las excepciones nuevas porque matchean
-- por la marca del historial, no por rango de ids).
--
-- La columna NO se dropea: es estructura del modelo nuevo, no dato de prueba. Si
-- hubiera que revertirla, es
-- ALTER TABLE cs.polizas_ap DROP COLUMN IF EXISTS suma_asegurada;
-- y hay que coordinarlo con wsmesacarga, que es su dueño.
