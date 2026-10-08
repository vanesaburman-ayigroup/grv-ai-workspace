-- ============================================
-- Script: feature PORTAL_INCAPACIDAD_DEFINITIVA por grupo
-- Descripcion: habilita en el Portal de Clientes la carga de la incapacidad
--              definitiva a los grupos de GCBA (257, 259 y 283). Es una feature
--              por grupo: se inserta en grupos_features_portal y
--              wsperfilespermisos la anexa a los permisos del usuario.
--
-- CORRER AL FINAL: despues de aplicar la tabla cs.denuncias_incapacidad y de
-- desplegar wsincapacidades, wsdocumento y el front del Portal. Con la feature
-- activa el boton de carga aparece de inmediato; sin el servicio desplegado la
-- carga falla.
--
-- Verificar antes de aplicar (en cada ambiente):
--   SELECT @@hostname;
--      Debe ser el primario del ambiente correcto.
--   SELECT id_grupo, nombre FROM grupos WHERE id_grupo IN (257, 259, 283);
--      Los ids de grupo pueden diferir entre ambientes (el 23 es el piloto de
--      TAR-15): confirmar cuales son los grupos de GCBA en este ambiente y
--      ajustar la lista del INSERT si hace falta.
--   SELECT * FROM grupos_features_portal WHERE feature = 'PORTAL_INCAPACIDAD_DEFINITIVA';
--      Debe dar vacio la primera vez.
--
-- Idempotente: no duplica filas (UNIQUE id_grupo + feature y NOT EXISTS).
-- Ejecutar el bloque entero seleccionado y luego SOLO la linea COMMIT o ROLLBACK.
-- ============================================

START TRANSACTION;

INSERT INTO grupos_features_portal (id_grupo, feature, activo, descripcion)
SELECT g.id_grupo, 'PORTAL_INCAPACIDAD_DEFINITIVA', 1,
       CONCAT('Portal de Clientes - carga de incapacidad definitiva - grupo ', g.id_grupo)
FROM (SELECT 257 AS id_grupo UNION SELECT 259 UNION SELECT 283) g
WHERE NOT EXISTS (SELECT 1 FROM grupos_features_portal x
                  WHERE x.id_grupo = g.id_grupo
                    AND x.feature = 'PORTAL_INCAPACIDAD_DEFINITIVA');

SELECT ROW_COUNT() AS filas_insertadas;

SELECT id_grupo, feature, activo
FROM grupos_features_portal
WHERE feature = 'PORTAL_INCAPACIDAD_DEFINITIVA'
ORDER BY id_grupo;

-- Esperado: una fila activa por cada grupo de la lista.
-- COMMIT;
-- ROLLBACK;

-- ============================================
-- Desactivar la carga (sin borrar filas):
--   UPDATE grupos_features_portal SET activo = 0
--   WHERE feature = 'PORTAL_INCAPACIDAD_DEFINITIVA' AND id_grupo IN (257, 259, 283);
-- Quitarla por completo:
--   DELETE FROM grupos_features_portal
--   WHERE feature = 'PORTAL_INCAPACIDAD_DEFINITIVA' AND id_grupo IN (257, 259, 283);
-- ============================================
