# GLPI 2883 - Lote de cartas SG "Solicitud de CD (GCBA AUTOSEGURO)" (tipo 158)

Pedido: Agustin Mesplet (Gestor de Registros y Afiliaciones) el 1/10; Laila Chaina (Team Leader) agrego "Respuesta a Telegrama" el 1/10 16:04. Reenvia Agustin Scandizzo (Mesa de Ayuda).
Verificado el 2026-10-07 contra PROD (`@@hostname` = ip-172-19-1-132, solo SELECT). Tabla `cd_cartas` en latin1, UK `(id_modulo, numero_carta)`, `id_carta` AUTO_INCREMENT (no se fija).
Consumidores: ver `../GLPI-2632/03-consumers.md` (mismo mecanismo; el combo se llena por consulta: no hace falta tocar codigo ni redeploy). Un modulo nuevo tambien sale solo (`findByActivoTrue`).

## Altas (18 cartas + modulo nuevo)
| Carta (texto exacto del pedido) | Modulo (id_modulo) | numero_carta | Pidio |
|---|---|---|---|
| Citación a Turno Médico con prórroga | ABANDONO (1) | 10 (libre; hay 1..9) | Mesplet |
| Alta por telemedicina. Adecuada a Res. 20-2026. | ALTAS (3) | 5 (hay 1..4) | Mesplet |
| Se revoca alta por dictamen. | ALTAS (3) | 6 | Mesplet |
| Comunicación resultado de Hipoacusia detectada en exámenes periódicos. | ALTAS (3) | 7 | Mesplet |
| Suspensión de Tratamiento por afección inculpable. | ALTAS (3) | 8 | Mesplet |
| Rectificación Alta con incapacidad a sin incapacidad. | ALTAS (3) | 9 | Mesplet |
| Suspensión plazos 298 Derechohabientes. Pedido de documentación | MORTALES (nuevo, id 9 por AUTO_INCREMENT) | 1 | Mesplet |
| Aceptación 298 Derechohabientes: Solicitud de documentación no recibida | MORTALES | 2 | Mesplet |
| Rechazo ACV. Mortal y otros (cardiopatías, edemas pulmonares) no derivados ni de accidentes ni de enfermedades | MORTALES | 3 | Mesplet |
| Rechazo por prescripción (fecha del hecho) | MORTALES | 4 | Mesplet |
| Rechazo por prescripción (fecha de la denuncia) | MORTALES | 5 | Mesplet |
| Rechazo por falta de datos objetivos: Solicitud de autopsia | MORTALES | 6 | Mesplet |
| Rechazo por falta de datos objetivos: Solicitud de documentación relacionada jornada laboral - recorrido del siniestro | MORTALES | 7 | Mesplet |
| Rechazo mortal-trabajador fuera de nómina | MORTALES | 8 | Mesplet |
| Rechazo Accidente dentro de su domicilio - No configura in itinere | RECHAZOS (8) | 19 | Mesplet |
| Reversión de rechazo con citación a recibir prestaciones (caso rechazado sin alta médica). Indicación de S.R.T. | RECHAZOS (8) | 20 | Mesplet |
| Reversión de rechazo. Caso sin alta. Citación | RECHAZOS (8) | 21 | Mesplet |
| Reversión de rechazo. Caso con alta. | RECHAZOS (8) | 22 | Mesplet |

Modulo nuevo: `MODULO MORTALES` (convencion de nombre de los otros 8: `MODULO X`; Mesplet escribio "MÓDULO MORTALES").
Numeracion de RECHAZOS: 1..16 activas, 17 inactiva (PENDIENTE DEFINICION POR CLIENTE, no se toca), 18 reservada por GLPI 2632, de ahi 19+.
En OTRAS CITACIONES el 7 queda para "Respuesta a Telegrama" (ya acordada en GLPI 2632 con ese nombre, no se repite aca; la pidio Laila) y el 8 para la ambigua "Deslinde".

## Bajas pedidas ("se debe borrar") - baja logica, no DELETE
| Carta | id_carta | Solicitudes que la usan | Accion |
|---|---|---|---|
| OTRAS CITACIONES 6 "Suspensión plazos 298. Derechohabientes. Pedido de documentación" (se mueve a MORTALES 1) | 34 | 9 | `activo = 0` |
| RECHAZOS 14 "Rechazo por accidente no laboral (ej. En su domicilio)" (la reemplaza RECHAZOS 19) | 48 | 73 | `activo = 0` |
Borrado fisico no corresponde: las solicitudes historicas apuntan por `id_cd_carta`.

## Ambiguas / dudas (comentadas en 01-script.sql, no se insertan)
| Carta pedida | Modulo | Duda |
|---|---|---|
| Rechazo PMI anterior a vigencia de Autoseguro | RECHAZOS | GLPI 2632 ya propone "EP FECHA PMI ANTERIOR VIGENCIA" (RECHAZOS 18, sin ejecutar). Si es la misma, renombrar en 2632 y no insertar esta; si son dos cartas, esta seria la 23. |
| Deslinde de responsabilidad por abandono en caso de serológico | OTRAS CITACIONES | Ya existe en ABANDONO (id 64, nro 9): "Se notifica deslinde de Responsabilidad por inasistencia. Casos Serológicos..." (18 solicitudes). Confirmar si es otra carta o la misma mal ubicada. |
| Rechazo pluriempleo. Lugar de destino de otra A.R.T. | RECHAZOS | Existe id 50, nro 16, "RECHAZO PLURIEMPLEO" (3 solicitudes). ¿Carta nueva o renombre? |
| Rechazo por no concurrir a citación | RECHAZOS | Parecida a id 39, nro 5, "Rechazo Inasistencia Citación médica con conocimiento de fecha de notif. Fehaciente". |
| Rechazo por alteración del trayecto IN ITINERE | RECHAZOS | Parecida a id 38, nro 4, "Rechazo evaluación médica + altera In itinere". |

Otras dudas menores (incluidas en el script):
- "Alta por telemedicina. Adecuada a Res. 20-2026." convive con ALTAS 4 "Alta por telemedicina" (id 19, 1577 solicitudes): se inserta como carta nueva (nro 5), no como renombre. Confirmar.
- "Suspensión plazos 298 Derechohabientes" se escribe sin el punto despues de 298 (como en el pedido); la carta vieja lo tenia con punto.
- "Rechazo mortal-trabajador fuera de nómina" y las "prescripción" de MORTALES son distintas de RECHAZOS 9 ("Rechazo trabajador fuera de nómina") y 13 ("Rechazo prescripción") por estar en otro modulo.

## Orden de aplicacion
1. GLPI 2632 (`../GLPI-2632/01-script.sql`), 2. este `01-script.sql` en bajo, luego PROD. Verificacion con HEX y chequeo de `?` (latin1) incluidos. Rollback en `02-rollback.sql` (chequea uso previo).
