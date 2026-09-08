## Why

El control económico de las pólizas de Accidentes Personales (AP) vive **fuera del sistema**: el equipo de gestión (Verónica Marelli, Gabriel Centeno) controla a mano, en Excel y paciente por paciente, cuánto consumió cada siniestro contra la suma asegurada. No se puede automatizar hoy porque **`cs.polizas_ap` no tiene ninguna columna de monto/tope** (verificado con 6 patrones LIKE sobre INFORMATION_SCHEMA → 0 columnas), así que no existe denominador contra el que topear.

El agravante es temporal: la facturación real llega **1–2 meses después y escalonada** (una cirugía sigue erogando materiales y honorarios mientras se siguen autorizando prestaciones). Cuando el gasto facturado aparece, ya se autorizó de más. Esta etapa 1 habilita el topeo **anticipado** sin esperar la factura.

## What Changes

- **Perfiles AP.** Ya existen `analista_accidentes_personales` (id 22) y `gestor_accidentes_personales` (id 25) en `cs.perfiles_sas`, ambos módulo 1 (tramitadores) con los mismos 2 permisos (13 `crear_turnos_analista_quirurgico`, 18 `crear_turnos_laboratorio`). **Se agrega un tercer perfil de gestor comercial de AP** con exactamente los mismos permisos que el analista, por SQL idempotente (transacción + verificaciones previa/posterior).
- **Persistencia del tope.** Tabla nueva `polizas_ap_topes` (suma asegurada **con IVA**, por paciente/asegurado, con ventana y vigencia) + denormalización de `suma_asegurada` en `denuncia_poliza` al asociar. Dueño del modelo: `wsmesacarga`, donde ya vive el CRUD de la póliza. La suma asegurada pasa a ser **obligatoria en el alta** de la póliza AP y **editable** en la póliza vigente, con trazabilidad del cambio. Las pólizas AP preexistentes sin tope se listan como pendientes de regularizar.
- **Motor de consumo y semáforo por proyección.** Vistas `ap_consumo_prestacion` / `ap_consumo_siniestro` + `ap_semaforo_parametros`, que clasifican cada ítem de consumo en tres estados de confianza (**Facturado / Devengado / Estimado**) y exponen dos cifras: el **facturado** (tope oficial, gatilla cierre y débito) y la **proyección** = F+D+E (vigilancia del mes, gatilla la alerta "no autorizar más"). Semáforo de 5 niveles (Bajo <40 / Medio 40-70 / Alto 70-90 / Muy alto 90-100 / Excedido >100; 40 y 70 parametrizables, 90 y 100 fijos).
- **Las cinco vías de valorización entran en esta etapa:** prácticas/turnos, traslados y cirugía (consolidado por componentes, con la regla anti-doble-conteo de materiales) resueltas automáticamente por convenio; **medicación** por **carga manual del valor** (con descripción del medicamento y registro del precio usado, que construye el historial que hoy no existe); **laboratorio** por **multiplicador × precio de la unidad**, que es el mecanismo que negocio ya usa (el multiplicador por determinación existe; se carga el precio). Se agrega además **carga manual del valor para prestaciones no convenidas** (cirugías acordadas por presupuesto, que no están en la grilla).
- **Lo diferido a ETAPA 2** es la **automatización** de esas dos vías: ingesta del feed de precios de medicamentos y sincronización automática del precio de laboratorio. La operación no queda bloqueada: en etapa 1 se puede cargar a mano, como se hace hoy, pero dentro del sistema y con historial.
- **Avisos al cambiar de nivel**, usando los mismos cortes de la escala del semáforo (ingreso a Alto, a Muy alto y a Excedido) — un único criterio, sin una segunda escala de porcentajes en paralelo. Cada aviso se registra una sola vez por nivel y siniestro, y el aviso de cada nivel puede habilitarse o deshabilitarse sin deploy.
- **Consulta de impacto sobre el saldo:** responder si un monto presupuestado (típicamente una cirugía) entra en la suma asegurada. Es el pedido recurrente del cliente antes de aprobar una cirugía.
- **Disparar el estimado al autorizar.** Poblar `turnos.valor_prestacion` (+ `id_tipo_origen_valor=1` CONVENIO) en el alta/aprobación del turno, más un backfill idempotente del histórico. **Precondición dura:** hoy solo el **5,37%** de los turnos realizados tiene el estimado cargado (159.384 de 2.967.213); sin esto el semáforo por proyección queda ciego.
- **Dos perfiles de UI**, cada uno con su maqueta ya aprobada en `docs/ap-costos/maqueta/`: **Gestión y Topeo** (Verónica + Gabriel) y **Comercial y Costos** (Iván + Bruno).
- No hay cambios BREAKING: todo el DDL es aditivo y el modelo de costo (`convenios`, `convenios_prestaciones_nomencladas`) queda intacto y read-only.

## Capabilities

### New Capabilities

- `ap-perfiles-acceso`: perfiles y permisos de AP — el gestor comercial nuevo como copia del analista, el chequeo de permisos en backend y la separación entre el perfil de gestión/facturación y el de comercial/costos.
- `ap-tope-poliza`: persistencia y resolución del tope (suma asegurada con IVA por paciente), su carga en el alta de póliza y la denormalización al vínculo denuncia↔póliza.
- `ap-consumo-topeo`: motor de consumo que agrega las vías por siniestro, clasifica en Facturado/Devengado/Estimado, y expone el facturado (tope oficial) y la proyección (vigilancia), incluidas las reglas anti-doble-conteo.
- `ap-semaforo-gestion`: semáforo de 5 niveles con umbrales parametrizables y su presentación — detalle del siniestro, distribución agregada de cartera y grilla filtrable por nivel.
- `ap-valor-venta`: valor de venta por prestación × zona con vigencia y versionado copy-on-write, separado del costo por convenio (base del margen).

### Modified Capabilities

<!-- Ninguna: openspec/specs/ está vacío (no hay capacidades main sincronizadas), así que
     esta etapa no modifica requisitos de especificaciones existentes. -->

## Impact

- **Base de datos (`cs`, aditivo):** tablas nuevas `polizas_ap_topes`, `valores_venta_prestacion`, `ap_semaforo_parametros`, `ap_valores_manuales` (medicación / no convenidas, con descripción, precio, fuente y fecha) y `ap_avisos_nivel_siniestro`; vistas nuevas `ap_consumo_prestacion`, `ap_consumo_siniestro`, `ap_margen_prestacion`; dos columnas nuevas en `denuncia_poliza`; filas nuevas en `perfiles_sas` / `perfiles_permisos_sas`. Backfill DML del estimado en `turnos`.
- **Backend:** `wsmesacarga` (CRUD del tope en la póliza), `wsturnos` (disparar el estimado al autorizar; ya tiene los anclajes `persistirJustificacionTopeo` en `POST /autorizaciones/dictaminar-autorizacion` y `GET /autorizaciones/consumo-cie10/{idDenuncia}`), y endpoints nuevos de semáforo/consumo/valor de venta. Lectura reusada (sin duplicar lógica) de `wsconvenio` (`POST /presupuestos`, vista NBU precomputada), `wscirugias` (`POST /pedido-materiales/findByDenuncia`), `wsauditoriafacturacion` (`POST /erogaciones`) y `wstraslados`/`wsauditoriatraslados`.
- **Frontend:** MFE de tramitadores (sección Costos y Topeo en el detalle del siniestro, cabecera con mini-barra de tope, home agregado, grilla filtrable) y pantallas del perfil comercial (valor de venta por prestación×zona). Secciones de medicación y laboratorio renderizadas como `EN CONSTRUCCIÓN`.
- **Fuera de alcance de esta etapa:** la **automatización** de precios de medicamentos (feed licenciado) y la sincronización automática del precio de laboratorio; la facturación mensual completa con rendiciones; el margen operativo consolidado; y la capa de IA asistiva.
- **Fuente de diseño:** `docs/ap-costos/AP-Costos-SDD.md` (SDD de 16 secciones con DDL, verificado contra la réplica read-only de `cs` y el código de `repos/grvx/backend`).
