# Plan de pruebas — CIE-10 trazadores, bloqueo de edición y autoaprobación de protocolo

| | |
|---|---|
| **Change** | `cie10-severidades-protocolo-leves` |
| **Tickets** | GRV-2239 · SE-258 |
| **Ambiente** | **TEST** — `db.test.sas.colonia-suiza.com.ar`, instancia `sastest` |
| **Fecha** | 06/08/2026 |
| **Estado del ambiente** | Código desplegado y base migrada. Listo para probar |

---

## 1. Qué se está probando

Dos cambios encadenados:

1. **Corrección del catálogo** de cuatro CIE-10 de patologías trazadoras (`S31.8`, `T14.1`, `T06.8`, `S61.8`): pasan a severidad Grave con 120 días de baja y se les apaga la autoaprobación.
2. **Bloqueo de edición** del diagnóstico en esos cuatro códigos para el auditor médico, con permiso de excepción y kill switch.
3. **Reposición de la autoaprobación** de prestaciones de protocolo en el ingreso del siniestro, condicionada por severidad.

### Servicios desplegados en TEST

| Componente | Qué aporta |
|---|---|
| `wscie10` | Bloqueo en dos vías + endpoint `edicion-bloqueada` |
| `wsauditoria` | Bloqueo en las otras dos vías |
| `wsturnos` | Autoaprobación de protocolo y trazabilidad |
| `auditoriamedica` (MFE) | Campo deshabilitado y mensaje al usuario |

---

## 2. Precondiciones

### 2.1 Estado de la base — verificar antes de empezar

```sql
-- Los 4 códigos deben estar en Grave (2), 120 días y sin autoaprobación
SELECT codigo, id_severidad, dias_baja_leve, dias_baja_moderado, dias_baja_grave,
       habilita_autoaprobacion, edicion_bloqueada
  FROM cs.diagnosticos_cie10
 WHERE codigo IN ('S31.8','T14.1','T06.8','S61.8');
-- Esperado: 4 filas · id_severidad=2 · 120/120/120 · habilita_autoaprobacion=0 · edicion_bloqueada=1

-- Kill switch encendido
SELECT param_value FROM cs.parametros WHERE param_name = 'BLOQUEO_EDICION_CIE10';
-- Esperado: 1

-- Permiso creado (en TEST quedó con id 86)
SELECT id_permiso, permiso, activo FROM cs.permisos_sas WHERE permiso = 'editar_cie10_bloqueado';

-- Columnas nuevas
SHOW COLUMNS FROM cs.autorizaciones     LIKE 'es_aprobacion_automatica';
SHOW COLUMNS FROM cs.diagnosticos_cie10 LIKE 'edicion_bloqueada';
```

### 2.2 Usuarios necesarios

| Usuario | Para qué | Cómo prepararlo |
|---|---|---|
| **Auditor médico** | Casos de bloqueo. Debe tener `area = 'AUDITORIA MEDICA'` | Usuario habitual de auditoría en TEST |
| **Gestor de mesa** | Casos de autoaprobación (carga las prestaciones al ingreso) | Usuario de mesa de carga |

### 2.3 El permiso de excepción NO se asigna a nadie — decisión tomada

`editar_cie10_bloqueado` queda **creado y sin asociar a ningún perfil, en los tres ambientes**. Decisión de la líder técnica del 06/08, con el riesgo evaluado y aceptado:

> Si aparece un caso que haya que corregir, **se resuelve por Mesa de Ayuda de sistemas, directamente sobre la base de datos**. Se puede convivir con eso.

**Consecuencia para QA — no es un defecto, no reportarlo:**

- **BLQ-06 no se ejecuta.** No queda pendiente: no aplica.
- **BLQ-11 se ejecuta parcialmente**: sólo la mitad que verifica `true`.
- El resto del plan **no se ve afectado**: el bloqueo se prueba igual, porque ningún usuario tiene la excepción.

**Las dos válvulas de escape que sí quedan operativas:**

1. El **kill switch** `BLOQUEO_EDICION_CIE10` (BLQ-07), que apaga la restricción para todos.
2. La **corrección directa en base** por Mesa de Ayuda — procedimiento en el Anexo A.

### 2.4 Denuncias de prueba

Preparar **cuatro denuncias** en TEST, todas con `protocolo_completa = 1`:

| Ref | CIE-10 principal | `id_severidad_denuncia` | Para qué |
|---|---|---|---|
| **D-LEVE** | cualquiera leve, ej. `S60.0` | 1 (Leve) | Camino feliz de autoaprobación |
| **D-MODERADA** | cualquiera leve | 2 (Moderado sin internación) | Debe caer a pendiente |
| **D-TRAZADORA** | `T06.8` | 1 (Leve) | Bloqueo de edición |
| **D-SECUNDARIO** | leve como principal + un secundario Grave | 1 (Leve) | Doble puerta de severidad |

> **Ojo con las dos escalas de severidad, no son intercambiables.**
> `severidades_denuncias` (la denuncia): 1 Leve · 2 Moderado sin internación · 3 Moderado con internación · 4 Grave · 5 Mortal.
> `severidades` (el catálogo CIE-10): 1 Leve · **2 Grave** · 3 Muerte · 4 Crónico · 5 Moderado.

---

## 3. Casos de prueba — Autoaprobación de protocolo

> Todos se ejecutan **desde la carga de prestaciones del gestor al ingresar el siniestro**.
> Verificación en base tras cada caso:
> ```sql
> SELECT a.id_autorizacion, a.id_estado_autorizacion, a.es_aprobacion_automatica,
>        t.id_estado_turno
>   FROM cs.autorizaciones a LEFT JOIN cs.turnos t ON t.id_turno = a.id_turno
>  WHERE a.id_denuncia = <ID_DENUNCIA> ORDER BY a.id_autorizacion DESC;
> ```
> Estados de autorización: **0 = CONFECCIONADA (aprobada)** · 1 = pendiente de aprobación · 2 = aprobada.

| # | Caso | Pasos | Resultado esperado |
|---|---|---|---|
| **AUT-01** | FKT de protocolo en denuncia leve | En D-LEVE, generar autorización de FKT con **3 turnos por región**, sin traslado | Autorización en **estado 0**, `es_aprobacion_automatica = 1`, con autorizante cargado |
| **AUT-02** | Consulta de primera asistencia | En D-LEVE, cargar turno de **tipo consulta** con la prestación **CONSULTA EN GUARDIA (42.03.05, no nomenclada, id 1693)**, sin traslado | Autorización en **estado 0**, `es_aprobacion_automatica = 1` |
| **AUT-03** | Estado del turno autoaprobado | Tras AUT-02, mirar el turno | Turno en **pendiente de programación** (`id_estado_turno = 16`), **no** en pendiente de aprobación |
| **AUT-04** | Cuarta sesión de FKT | En D-LEVE, generar FKT con **4 turnos** en una región | **Pendiente** (estado 1). No se rechaza |
| **AUT-04b** | Menos de 3 sesiones | En una denuncia leve **sin FKT previas**, generar FKT con **2 turnos** en una región | **Aprobada** — el cupo es de *hasta* 3, no exactamente 3 |
| **AUT-05** | Dos regiones × 3 turnos | Generar FKT con 3 turnos en cada una de 2 regiones | Aprobada — el cupo es **por región** |
| **AUT-06** | Denuncia moderada | Repetir AUT-01 y AUT-02 en **D-MODERADA** | **Pendiente** en ambos |
| **AUT-07** | Denuncia sin severidad | Denuncia con `id_severidad_denuncia` en NULL | **Pendiente** |
| **AUT-08** | CIE-10 principal grave | Denuncia con `T06.8` (ya corregido a Grave) | **Pendiente** — ninguna prestación se autoaprueba |
| **AUT-09** | CIE-10 **secundario** grave | En **D-SECUNDARIO** (principal leve, secundario grave), cargar FKT de protocolo | **Pendiente** — es la segunda puerta de severidad |
| **AUT-10** | Con traslado | Repetir AUT-01 marcando que **requiere traslado** | **Pendiente** |
| **AUT-11** | Consulta de control | Cargar una consulta de control (prestación distinta de guardia) | **Pendiente** — excluida por decisión clínica |
| **AUT-12** | Estudio / radiografía | Cargar un estudio | **Pendiente** — los estudios se auditan siempre |
| **AUT-13** | Protocolo incompleto | Denuncia con `protocolo_completa = 0` | **Pendiente** |
| **AUT-14** | Segundo paquete de FKT | Sobre una denuncia que **ya tiene FKT de protocolo autoaprobadas**, generar un nuevo pedido de 3 turnos | **Pendiente** — el protocolo corre una sola vez, al ingreso |
| **AUT-14b** | Segunda primera asistencia | Sobre una denuncia que ya tiene una consulta de guardia autoaprobada, cargar otra | **Pendiente** |
| **AUT-14c** | Guardia y FKT en el mismo ingreso | Cargar la consulta de guardia (se autoaprueba) y **a continuación** las FKT de protocolo | **Ambas aprobadas** — que exista la consulta no bloquea las FKT del mismo ingreso |

---

## 4. Casos de prueba — Bloqueo de edición del CIE-10

> **Las cuatro vías hay que probarlas todas.** Cada una es un camino distinto en el código; que una funcione no implica que las otras estén cubiertas.

| # | Vía | Cómo llegar | Resultado esperado |
|---|---|---|---|
| **BLQ-01** | Auditoría médica — pantalla de denuncia completa | Con **D-TRAZADORA**, entrar como auditor médico e intentar cambiar el diagnóstico | El campo aparece **deshabilitado**, con el mensaje visible. No se puede editar |
| **BLQ-02** | Popover de las grillas | Desde el listado de siniestros (internados / quirúrgicos), abrir el popover de CIE-10 sobre D-TRAZADORA | Campo y botón **Guardar deshabilitados**, con el mensaje |
| **BLQ-03** | `/aud-medica/save` directo | `POST` al endpoint con el CIE-10 cambiado sobre D-TRAZADORA | **HTTP 400** con el mensaje funcional. **Verificar en base que el diagnóstico NO cambió** |
| **BLQ-04** | `/auditoria-medica/save` (MFE contrataciones) | `POST` con el CIE-10 cambiado | **HTTP 400**, diagnóstico sin cambios |
| **BLQ-05** | `modifyByIdDenuncia` directo | `POST /wscie10/diagnosticoCie10/modifyByIdDenuncia` con otro código | **HTTP 400**, diagnóstico sin cambios |
| ~~**BLQ-06**~~ | ~~Excepción por permiso~~ | **NO EJECUTABLE en esta vuelta** — el permiso no está asignado a ningún perfil (ver 2.3) | Pendiente hasta que se defina el perfil |
| **BLQ-07** | Kill switch | `UPDATE cs.parametros SET param_value='0' WHERE param_name='BLOQUEO_EDICION_CIE10';` y repetir BLQ-01 | **Se permite editar** aunque el usuario no tenga el permiso. **Volver a poner en 1 al terminar** |
| **BLQ-08** | Guardar sin tocar el diagnóstico | En D-TRAZADORA, guardar la pantalla modificando **otro** campo | **Guarda normalmente**. Reenviar el mismo código no es una edición |
| **BLQ-09** | Borrar el diagnóstico | `POST save-multiple-cie10` con el código **vacío o nulo** sobre D-TRAZADORA | **HTTP 400**. El diagnóstico **no se borra** — era un bypass detectado en revisión |
| **BLQ-10** | Código no bloqueado | Cambiar el CIE-10 de una denuncia **sin** código trazador | **Se permite** — el bloqueo no alcanza al resto del catálogo |
| **BLQ-11** | Endpoint de consulta | `POST /wscie10/diagnosticoCie10/edicion-bloqueada` con `{"idDenuncia":<D-TRAZADORA>,"idUsuario":<auditor>}` | `body = true`. *(La contraparte `false` con usuario habilitado queda pendiente junto con BLQ-06)* |

**Mensaje esperado al usuario, textual:**

> El diagnóstico de este siniestro no se puede modificar porque corresponde a una patología trazadora ya informada a la SRT. Si hay que corregirlo, solicitarlo al equipo del SAS.

---

## 5. Casos de prueba — Catálogo y fechas

| # | Caso | Verificación |
|---|---|---|
| **CAT-01** | Denuncia **nueva** con `T06.8` | La fecha probable de fin de ILT se calcula con **120 días**, no con 10 |
| **CAT-02** | Denuncia **vieja** con `T06.8` | `fecha_probable_fin_ilt` **no cambió**. Comparar contra el valor previo |
| **CAT-03** | Severidad heredada | Una denuncia nueva con estos códigos nace con severidad **Grave** |
| **CAT-04** | Días en el desplegable | Al elegir `T06.8` en el buscador de CIE-10 del auditor, la etiqueta muestra **120 días** |

---

## 6. Regresión — lo que NO debe cambiar

> Esta sección es tan importante como las anteriores. Varios de estos comportamientos son **intencionales** y no deben reportarse como bug.

| # | Caso | Resultado esperado |
|---|---|---|
| **REG-01** | **Resonancias** de rodilla, hombro y columna sin traslado | Siguen quedando **pendientes de aprobación**. Antes del apagado de febrero se autoaprobaban; ahora **no**, porque los estudios se auditan siempre |
| **REG-02** | Materiales quirúrgicos | La autorización hija sigue naciendo en estado **6** (padre pendiente) |
| **REG-03** | Autorizaciones de rehabilitación que no son de protocolo | Sin cambios de comportamiento |
| **REG-04** | Alta de turnos en denuncia cerrada | La regla SE-214 sigue bloqueando turnos futuros |
| **REG-05** | Alta de CIE-10 en el catálogo | Se puede seguir dando de alta un diagnóstico nuevo — la columna `edicion_bloqueada` es nullable justamente para esto |
| **REG-06** | Guardado de auditoría médica en denuncias comunes | Sin degradación ni errores nuevos |

---

## 7. Efectos colaterales a observar (no son bugs, hay que constatarlos)

Estos cambios **son consecuencia esperada** del ajuste de catálogo. Conviene verificarlos y dejar evidencia, porque impactan a usuarias de Auditoría Médica.

| # | Qué observar | Efecto esperado |
|---|---|---|
| **EFE-01** | Indicador **«a vencer»** en la grilla de auditoría médica | El aviso pasa de 5 a **60 días** antes en denuncias leves, y de 7 a **84** en moderadas. Van a aparecer denuncias que antes no figuraban |
| **EFE-02** | Columna **«días CIE-10»** en auditoría médica y en el listado de logística | Muestra **120** en todas las denuncias con estos códigos, incluidas históricas y cerradas |
| **EFE-03** | **Topes de prestaciones** | Al ser Grave, los topes de FKT, consultas y estudios quedan **sin límite** para estos códigos |
| **EFE-04** | **Estadísticas por severidad** del tablero de gestores | Las denuncias con estos códigos pasan del bucket «leves» al de moderados/graves, de forma retroactiva |
| **EFE-05** | Excel exportable de auditoría médica | La columna de días dice 120 también en históricas |
| **EFE-06** | Consumo del tope al solicitar FKT | Las 3 sesiones autoaprobadas **consumen el tope al solicitarse**, no al aprobarse |

---

## 8. Puntos frágiles detectados en revisión — verificar con atención

Salieron de las cinco revisiones de código. No están corregidos porque exceden el alcance del change, pero **conviene confirmarlos en TEST** para dimensionar el impacto.

| # | Qué mirar | Por qué |
|---|---|---|
| **FRA-01** | **Portal de prestadores** (`ws-sasconnect`): comparar el **contador** de autorizaciones contra las filas de la **grilla** | El contador incluye el estado CONFECCIONADA y la grilla no: puede mostrar un número que no coincide con lo listado |
| **FRA-02** | **Portal de clientes**: cómo se ve una autorización autoaprobada | Puede mostrar el literal **«CONFECCIONADA»** sin color, porque matchea por descripción |
| **FRA-03** | Color del chip de estado en los distintos MFEs | `auditoriamedica` lo pinta amarillo; `tramitadores` y `auditoriafacturacion`, verde |
| **FRA-04** | Que una autorización autoaprobada **no vuelva** a pendiente | Existe un camino que reescribe el estado a 8 (pendiente de valorización) |
| **FRA-05** | **Nuevos Ingresos**: el bloqueo del CIE-10 en el popover | Esa grilla no trae el código, así que el campo aparece habilitado y el rechazo llega recién al guardar. Es limitación conocida |

---

## 9. Trazabilidad — requisito ↔ caso

| Requisito | Casos |
|---|---|
| RF-1 Severidad y días de los 4 códigos | CAT-01, CAT-03, CAT-04, EFE-01 a EFE-05 |
| RF-2 Apagado de la autoaprobación en esos códigos | AUT-08 |
| RF-3 Bloqueo de edición | BLQ-01 a BLQ-05, BLQ-09 |
| RF-3.1 Vía de corrección e interruptor | BLQ-06, BLQ-07 |
| RF-4 Sólo en el ingreso | AUT-13, AUT-14 |
| RF-5 Prestaciones alcanzadas y cupo | AUT-01, AUT-02, AUT-04, AUT-05 |
| RF-6 Prestaciones excluidas | AUT-10, AUT-11, AUT-12, REG-01 |
| RF-7 Severidad como condición | AUT-06, AUT-07, AUT-08, AUT-09 |
| RF-8 Trazabilidad de la aprobación automática | AUT-01, AUT-02 (campo `es_aprobacion_automatica`) |
| No retroactividad | CAT-02 |

---

## 10. Criterios de salida

Para dar el change por probado:

1. **Todos** los casos AUT y BLQ en verde, **excepto BLQ-06 y la contraparte de BLQ-11**, que quedan explícitamente fuera de alcance de esta vuelta (ver 2.3). Los cuatro caminos de bloqueo probados por separado, no sólo la pantalla.
2. Regresión completa sin hallazgos, con **REG-01 confirmado explícitamente** (las resonancias deben seguir pendientes).
3. Efectos colaterales de la sección 7 **constatados y comunicados a Auditoría Médica** antes de pasar a producción.
4. CAT-02 verificado: ninguna denuncia histórica cambió su fecha.
5. Los puntos frágiles de la sección 8 revisados, con decisión registrada sobre cada uno.

## 11. Pendiente de definición funcional

No bloquean la prueba técnica, pero sí el pasaje a producción:

- ~~Perfiles que reciben `editar_cie10_bloqueado`~~ — **resuelto el 06/08: no se asigna a nadie.** El bloqueo se despliega **encendido** (`BLOQUEO_EDICION_CIE10 = 1`) en los tres ambientes, y las correcciones se hacen por Mesa de Ayuda sobre la base (Anexo A). Riesgo evaluado y aceptado por la líder técnica.
- **Confirmación por escrito de Auditoría Médica** sobre los seis efectos de la sección 7.

---

## Anexo A — Corregir un CIE-10 bloqueado desde Mesa de Ayuda

Como ninguna persona tiene el permiso de excepción (ver 2.3), **ésta es la única vía de corrección individual**. Aplica cuando llega un caso con un código trazador mal cargado que no se puede editar desde la pantalla.

### Antes de tocar nada

```sql
-- 1) Estado actual de la denuncia
SELECT id_denuncia, nro_asignado, diagnostico_cie10, id_patologia_trazadora,
       id_severidad, id_severidad_denuncia, fecha_probable_fin_ilt, protocolo_completa
  FROM cs.denuncias
 WHERE nro_asignado = '<NRO_SINIESTRO>';

-- 2) ¿El código nuevo es válido para la trazadora de esa denuncia?
SELECT c.codigo_cie10, d.descripcion
  FROM cs.config_trazadora_cie10 c
  JOIN cs.diagnosticos_cie10 d ON d.codigo = c.codigo_cie10
 WHERE c.id_patologia_trazadora = <ID_TRAZADORA> AND c.activo = 1;
```

### La corrección

```sql
START TRANSACTION;

UPDATE cs.denuncias
   SET diagnostico_cie10 = '<CODIGO_NUEVO>'
 WHERE id_denuncia = <ID_DENUNCIA>;
-- Verificar que afecte exactamente 1 fila antes de confirmar.

-- Dejar rastro de quién y por qué (el cambio por pantalla lo hace solo)
INSERT INTO cs.log_cie10_denuncias (id_denuncia, id_cie10, id_responsable_carga, fecha_carga)
VALUES (<ID_DENUNCIA>, '<CODIGO_NUEVO>', <ID_PERSONA_MESA>, NOW());

-- COMMIT;
-- ROLLBACK;
```

### Después

1. **Revisar la fecha probable de fin de ILT.** No se recalcula sola con un `UPDATE` directo: si el código nuevo tiene otros días de baja, hay que ajustarla o hacer que el auditor guarde la pantalla para que se recalcule.
2. **Si la denuncia ya se informó a la SRT o a Provincia ART**, el cambio de diagnóstico no reabre esa presentación: hay que emitir la modificación por el circuito de siniestralidad.
3. Registrar el caso en el ticket correspondiente, con el número de siniestro y el motivo.

> **Alternativa para casos masivos:** si aparecen varios casos seguidos, conviene apagar el kill switch un rato en lugar de hacer muchos `UPDATE` a mano:
> `UPDATE cs.parametros SET param_value = '0' WHERE param_name = 'BLOQUEO_EDICION_CIE10';`
> y volverlo a `'1'` al terminar. Toma efecto sin desplegar y sin reiniciar nada.
- **Fecha que viaja a la SRT**: en 567 denuncias con estos códigos la fecha probable de fin de ILT está en NULL y se recalcula en vivo; para 43 que siguen abiertas, lo informado pasaría de +10 a +120 días. Conviene probar un envío a la SRT en TEST antes de producción.
