# SDD SE-199 V1.3 — Relación CIE-10 ↔ naturaleza de la lesión ↔ zona corporal

| | |
|---|---|
| **Versión** | **V1.3** — 03/09/2026 (V1.2 + D-21: el catálogo real son 46 relaciones, no 31) |
| **Change** | `SE-199-cie10-naturaleza-zona` |
| **Fecha** | 20/08/2026 |
| **Ticket** | SE-199 — «[SINIESTRALIDAD] Relación entre CIE-10, Naturaleza de la Lesión y Zona Corporal» |
| **Reporta** | Mathias Fraifer · **Asignado** Vanesa Burman |
| **Antecedentes** | GRV-2207 (equivalencias Provincia ART, **en pausa**), change `cie10-severidades-protocolo-leves` (GRV-2239) |
| **Evidencia** | 6.833 denuncias · marzo–agosto 2026 · réplica read-only de producción |

---

## 1. Decisiones firmes

### D-1 · El orden canónico es CIE-10 primero

El diagnóstico se carga primero, y de él se derivan naturaleza y zona.

**Consecuencia**: en la pestaña de Auditoría Médica el orden actual es el inverso — `ComboMultipleCie10.tsx` deja el combo de CIE-10 `disabled` hasta que naturaleza y zona tengan valor. Ese gate se invierte.

> **Corrección del 27/08, al implementar.** Ese gate existe **sólo en el 2º y 3er diagnóstico**, que es lo que gobierna `ComboMultipleCie10`. El análisis original lo tomó por el flujo principal. El **primer** diagnóstico de Auditoría Médica nunca tuvo ese gate: son tres campos planos (`diagnosticoCie10Codigo`, `Descripcion`, `Dias`) y esa pantalla **no tiene naturaleza ni zona del primero**. La inversión aplica entonces al 2º y 3er diagnóstico.

**Advertencia registrada**: invertirlo cambia el flujo de trabajo diario del auditor médico. No es un ajuste técnico. Antes de implementarlo hay que definir qué ocurre con las denuncias que ya tienen los tres campos cargados.

> Aclaración sobre el estado actual: ese `disabled` **no** implica que hoy exista una relación. Es un gate de orden para que los datos estén presentes. `fetchDiagnosticoCie10` no recibe naturaleza ni zona como parámetro: la lista de códigos ofrecida es siempre el catálogo completo.

### D-2 · Lo que no se puede determinar no se sugiere

**Regla general**: el catálogo tiene fila **sólo** para las relaciones que se pueden determinar. Un código cuya naturaleza o zona no es determinable simplemente **no tiene esa relación cargada**, y el sistema no toca el campo: lo carga la persona.

No hay lista de exclusión, no hay validación especial, no hay valor de baja confianza sugerido «por si acaso». La ausencia de fila **es** la decisión.

Consecuencias de diseño:

- El mecanismo es uno solo: eje en `NULL` (D-3) para lo parcialmente determinable, y ausencia de fila para lo indeterminable.
- No hace falta distinguir entre exclusión «definitiva» y «revisable». Si mañana Registros puede determinar una relación que hoy no está, se agrega la fila. El catálogo crece; la regla no cambia.
- El sesgo es asimétrico y deliberado: no sugerir cuesta que alguien cargue dos campos a mano. Sugerir mal mete un dato inventado en un registro que viaja a la SRT.

#### Los códigos de patologías trazadoras caen bajo esta regla

Los 31 códigos configurados en `config_trazadora_cie10` **no son determinables**, y por eso no llevan relación cargada. El fundamento se documenta acá para que nadie cargue una fila más adelante sin entender por qué no estaba.

**Fundamento 1 — el campo tiene dos semánticas superpuestas, por decisión explícita del área médica.** En GRV-2207, comentario del 04/08/2026 (Ignacio Zumbo y Desireé Romero):

> «el sistema usa **un mismo campo de diagnóstico para dos cosas distintas**. Por un lado es el que se informa ante la SRT, y ahí debería salir del listado del ROAM. Por otro es el diagnóstico clínico del paciente, que define los días de ILT, la severidad y las prestaciones.»
>
> «La idea es que el campo siga siendo único… no agregar un campo nuevo.»

Para una denuncia con trazadora, entonces, el CIE-10 **no describe la lesión**: es una etiqueta administrativa tomada del listado ROAM.

**Fundamento 2 — está probado en la base.** Dos códigos sirven a cuatro trazadoras clínicamente incompatibles:

| Código | Trazadoras que sirve | CIE-10 real |
|---|---|---|
| `S05.3` | «Rotura/estallido de vísceras» **y** «Castración o emasculación traumática» | Herida penetrante de órbita con cuerpo extraño |
| `T14.2` | «Fractura expuesta, incluidas abiertas» **y** «Fracturas cerradas de MI o MS» | Fractura de región no especificada del cuerpo |

**Fundamento 3 — naturaleza y zona son el único registro de la lesión real en estos casos.** De las 291 denuncias marcadas como trazadora, **ninguna** tiene naturaleza o zona vacías: siempre las carga una persona, según el paciente real. Y la dispersión lo confirma: `T14.2` acumula 48 combinaciones distintas de naturaleza/zona en 165 casos; `T06.8`, 25 en 47.

```
   DENUNCIA CON TRAZADORA

   CIE-10  ──►  lo fija el sistema desde la trazadora
                (administrativo — no describe la lesión)

   naturaleza ──┐
   zona       ──┴──►  lo carga la persona según el paciente
                      ← ÚNICO lugar donde queda registrada
                        la lesión real
```

Autocompletarlas desde el CIE-10 no sólo pondría un dato falso: **borraría el único dato clínico correcto del registro**.

**Fundamento 4 — el precedente de qué pasa sin válvula de escape.** El caso que lo hace evidente: una denuncia con trazadora «Politraumatismo grave» lleva `T06.8` obligatorio. Los datos históricos dirían zona «Cabeza» (40%), pero un politraumatismo afecta múltiples regiones por definición. Y `T06.8` es uno de los cuatro códigos con `edicion_bloqueada = 1`, así que el auditor **no podría corregirlo**. Sería el mismo callejón sin salida que trabó GRV-2207: un dato incorrecto que el sistema no deja arreglar.

> **Riesgo a seguir**: hoy sólo **4 de los 31** códigos de trazadoras tienen `edicion_bloqueada = 1` (`S31.8`, `S61.8`, `T06.8`, `T14.1`). El RF-3 del change `cie10-severidades-protocolo-leves` pide extender el bloqueo a las diecinueve trazadoras. **No está aplicado.** Si se aplica después de este change, la superficie del riesgo anterior se multiplica.

**Nota sobre los códigos de trazadora anatómicamente específicos.** Los 31 no son homogéneos. Unos no describen anatomía por definición (`T14.2` y `T14.1` «región no especificada», `T06.8` «múltiples regiones», `R99` «causas mal definidas», más `R40.2`, `T65.9`, `F18.0`, `T08`, `S22.9`); otros sí (`S68.0` amputación del pulgar, `S98.1`/`S98.2` dedos del pie, `S05.2` laceración ocular, `S32.8` fractura de pelvis, `T31.1`–`T31.9` quemaduras por porcentaje de superficie).

Bajo la regla general esto no necesita tratamiento aparte: si Registros puede determinar la relación de `S68.0`, se carga la fila; si no, no está y no se sugiere. No se derivan de la estadística porque no hay volumen — esos códigos tienen entre 1 y 3 casos en cinco meses, así que el corte sería semántico y no empírico, justo lo que D-4 descarta.

### D-3 · Sólo se autocompleta lo determinístico — no existe el modo «sugerir»

Un eje se autocompleta **sólo si es determinístico**. No hay categoría de valor sugerido de confianza media: o el valor está determinado, o el campo queda vacío.

**Esto elimina el campo de modo del modelo de datos.** Con dos estados por eje, la presencia del valor ya expresa la decisión:

| `id_zona_afeccion` | Comportamiento |
|---|---|
| con valor | eje determinístico — se autocompleta |
| `NULL` | no determinable — el campo queda vacío y lo carga la persona |

Igual para `id_naturaleza_siniestro`. No hacen falta `modo_zona` ni `modo_naturaleza`.

Lo que se conserva es la **independencia entre ejes**, porque hay grupos reales donde sólo uno de los dos es determinístico:

| Grupo | Zona | Naturaleza | Ejemplo |
|---|---|---|---|
| Terna determinística | valor | valor | `S80.0` contusión de rodilla — 98% / 100% |
| Zona firme, naturaleza legítimamente variable | valor | `NULL` | `S81.8` herida de pierna — puede ser cortante, punzante o contusa |
| Dorsopatía: cuadro de dolor, no lesión | valor | `NULL` | `M54.4` lumbalgia con ciática — zona 98%, naturaleza indefinible |
| Bloque anatómico más amplio que la zona SRT | `NULL` | valor | `S40.0` contusión de hombro **y brazo** — naturaleza 99%, zona reparte entre dos |

**Cobertura resultante.** Quedan con relación cargada **31 de los 133 códigos** analizados — los 16 de terna determinística y los 15 de zona determinística. Sobre los 5.747 casos limpios:

| Grupo | Códigos | Casos | % del volumen |
|---|---|---|---|
| Terna determinística (ambos ejes) | 16 | 1.543 | 26,8% |
| Zona determinística (un eje) | 15 | 728 | 12,7% |
| **Con alguna relación** | **31** | **2.271** | **39,5%** |
| Se renuncia: concentración media (70–89%) | 30 | 661 | 11,5% |
| Sin relación: conflicto + no relacionable | 72 | 2.815 | 49,0% |

31 códigos cubren cerca del 40% del volumen. Los 661 casos de concentración media se dejan de lado deliberadamente: son justamente los que producirían el dato plausible-pero-equivocado que nadie revisa.

> ⚠️ **Esta tabla describe el análisis estadístico, no el catálogo cargado.** Al implementar se agregaron **15 códigos más por criterio anatómico** —11 del bloque C el 27/08 y las 4 dorsopatías el 03/09—, que la estadística por sí sola descartaba. El catálogo real tiene **46 relaciones**: 16 con terna completa y 30 con sólo zona. Ver **D-21**.

**Trade-off aceptado**: sin campo de modo, el catálogo no distingue «este eje no es determinable» de «este eje todavía no se analizó». Si esa distinción hace falta para el mantenimiento (ver Q4), se resuelve con un campo de nota, no reintroduciendo modos.

### D-4 · La moda estadística no es fuente de verdad

El catálogo se puebla con lo que **Registros valide**, no con el valor más frecuente.

Método aplicado para producir la matriz candidata: la estadística propone y el **texto del propio diagnóstico decide**. Si un código se llama «esguinces y desgarros» y la carga histórica dice «Contusiones», no es una relación candidata: es un conflicto.

Resultado sobre 133 códigos con 5 o más casos limpios:

| Veredicto | Códigos | Qué significa |
|---|---|---|
| `AUTOCOMPLETA_TERNA` | 16 | zona ≥90% y naturaleza ≥85%, coherentes con el texto |
| `AUTOCOMPLETA_ZONA` | 15 | zona firme, naturaleza dispersa |
| `SUGIERE` | 30 | concentración media — **no se cargan** (ver D-3) |
| `CONFLICTO` | 13 | el texto contradice la carga histórica |
| `NO_RELACIONAR` | 59 | inespecíficos, multizona o no traumáticos |

El detalle está en `matriz-relaciones-candidatas.tsv`, con una columna final vacía para que Registros escriba su validación.

### D-5 · La fuente de verdad del catálogo es `diagnosticos_cie10`

Existe un segundo catálogo, `certezas_cie10`, con 2.572 filas — pero su PK es un id secuencial, el código real viene embebido en la descripción, y **sólo 241 filas (9,4%) tienen código SRT**. Es un catálogo huérfano.

**Trampa a evitar**: si el endpoint nuevo lee `certezas_cie10`, resuelve el 9% de los casos y falla silenciosamente en el resto.

### D-6 · El alcance sigue a los campos que cada pantalla ya tiene

**Revisado el 27/08 al implementar.** El alcance no se define por número de diagnóstico sino por dónde existen los tres campos hoy:

| Pantalla | Autocompleta | Motivo |
|---|---|---|
| **General (CEM)** | 1er diagnóstico | es el único lugar donde el primero tiene CIE-10 + naturaleza + zona |
| **Auditoría Médica** | 2º y 3er diagnóstico | es lo único que esa pantalla tiene con naturaleza y zona |

**No se agregan campos que hoy no existen**: en particular, no se suma naturaleza ni zona del primer diagnóstico a Auditoría Médica. Sería un cambio de alcance que el ticket no pide.

> **Ampliado por D-12.** La regla no cambió, pero el relevamiento sí: el autocompletado terminó cubriendo **cuatro superficies** — el 1er diagnóstico y el 2º/3º de la pestaña General de CEM, el 2º/3º de Auditoría Médica, y los tres bloques de la Mesa de carga. La tabla de arriba describe el alcance del 27/08, no el alcance final. Ver D-12.

Volumen del multi-diagnóstico, para dimensionar la parte de Auditoría Médica: de 6.835 denuncias con diagnóstico, 370 tienen 2º (5,4%) y 81 tienen 3º (1,2%). Cuando el 2º existe, **siempre** viene con su naturaleza y zona completas — cero incompletos, cero errores `K9`. Es marginal y está sano; el valor grande está en el primer diagnóstico de la pestaña General, que es el que viaja a la SRT como `naturaleza1`/`zona1`.

### D-7 · Indicador de coherencia previo a la presentación — informativo y no bloqueante

Antes de generar el archivo SRT se **muestra la terna cargada** (diagnóstico, naturaleza, zona) junto a un **indicador de coherencia** entre los tres campos.

Tres precisiones que definen qué es y qué no:

- **No predice el veredicto de la SRT.** Evalúa las reglas que el organismo publica en su catálogo de errores, que son las conocidas y no necesariamente todas. Que no haya señalamiento no garantiza aceptación, y decirlo de otro modo sería prometer una certeza que no tenemos.
- **No bloquea.** Una terna señalada se presenta exactamente igual que una coherente: sin pasos extra, sin confirmación adicional, sin modificar el archivo.
- **No corrige.** Informa para que una persona decida.

El valor está tanto en el señalamiento como en **mostrar los tres campos juntos**, que hoy se cargan por separado y nunca se ven como una unidad.

> **Pendiente de diseño**: dónde aparece y con qué forma (indicador en el listado, en el detalle de la denuncia, en el paso previo a generar el archivo). Es una decisión de UX que conviene tomar mirando la pantalla real de presentación.

Replicar `L1`, `L2`, `L3`, `GK` y `FA` antes de generar el archivo SRT **no depende** de D-1 ni del catálogo poblado. Puede construirse y desplegarse primero.

**Matiz honesto sobre el alcance**: parte de las inconsistencias es estructuralmente inevitable, porque en trazadoras la SRT compara un CIE-10 administrativo contra naturaleza y zona clínicas. Medido:

| Error | Denuncias afectadas | De trazadoras | % irreparable |
|---|---|---|---|
| `GJ` | 497 | 26 | 5,2% |
| `FA` | 144 | 13 | 9,0% |
| `JI` | 71 | 8 | 11,3% |
| `GK` | 58 | 0 | 0% |

**~6% es irreparable; el 94% restante sí es atacable.** El asterisco queda puesto acá para que nadie use la cifra bruta de 1.803 sin él.

---

## 2. Modelo de datos

Patrón tomado de `especialidades_cie10_defaults`, que ya guarda esta misma terna (`codigo_cie10` + `id_zona_afeccion` + `id_naturaleza_siniestro`) para resolver el default de tres especialidades médicas.

```
cs.cie10_relaciones_validas
├── codigo_cie10             FK → diagnosticos_cie10.codigo
├── id_naturaleza_siniestro  FK → naturalezas_siniestro   (NULL = no determinable)
├── id_zona_afeccion         FK → zonas_afeccion          (NULL = no determinable)
│                            al menos uno de los dos SHALL tener valor
├── activo
└── auditoría (created_at, updated_at, usuario)
```

Las tres FK ya existen y son las mismas que usa `denuncias_cie10`, la tabla transaccional donde se persiste la terna por denuncia.

---

## 2.bis Confirmación de las relaciones — 27/08/2026

Las **42 relaciones** quedaron confirmadas por **Vanesa Burman**, asignada al ticket, el 27/08/2026. Incluye el bloque C tal como está propuesto: esos 11 códigos reciben su zona y la naturaleza queda libre (D-11).

Alcance de esta confirmación, para no confundirla con otra cosa:

| | |
|---|---|
| **Confirmado** | las 42 relaciones — 16 con terna completa, 15 con sólo zona, 11 del bloque C con zona |
| **Confirmado** | que en el bloque C la naturaleza queda libre, sin valor propuesto |
| **Sigue abierto** | la naturaleza **correcta** de los 13 códigos del bloque C (Q2). Es lo único que falta para la remediación de D-10 |
| **Sigue abierto** | Q5 — quién mantiene la tabla |

Registros no se expidió en el ticket: el comentario del 26/08 no tiene respuesta. La confirmación habilita la implementación; la validación del sector sigue pedida.

---

## 3. Definiciones del equipo de desarrollo — 21/08/2026

Las cuatro decisiones que estaban abiertas se resolvieron **desde el equipo de desarrollo**, para no bloquear el avance. Registros todavía no se expidió: lo que sigue es la definición que adoptamos, no una validación del sector.

| # | Pregunta | Definición adoptada |
|---|---|---|
| **Q1** | ¿El valor determinístico se puede sobrescribir? | **Se puede cambiar.** Ver D-8. |
| **Q3** | ¿Se acepta autocompletar un solo eje? | **Sí, marcando que falta el otro.** Ver D-9 — agrega un requisito que no estaba. |
| **Q4** | `Z20.9` y `V49.4` quedan afuera por dispersión | **Quedan afuera.** |
| **Q6** | Retroactividad | **Sólo a futuro**, más una **propuesta de remediación de los casos activos**. Ver D-10 — amplía el alcance. |

**Relaciones propuestas**: los **31** códigos de los bloques A (16, terna completa) y B (15, sólo zona) se proponen tal como fueron analizados. Quedan listos para cargar una vez confirmados.

> **Lo que sí requiere definición de Registros y Auditoría Médica**: los **13 códigos en conflicto** del bloque C. Ahí el equipo de desarrollo no propone valor — el criterio de D-4 lo impide, porque la carga histórica contradice al diagnóstico. **Los selecciona el sector.**

### D-8 · El valor autocompletado es editable

El sistema completa el campo, y la persona puede cambiarlo. No se bloquea.

Consecuencia: el autocompletado es una ayuda de carga, no un control de integridad. Lo que evita el dato incoherente sigue siendo el chequeo previo a la presentación (D-7), no el autocompletado — conviene no confundir los dos mecanismos al estimar el impacto.

### D-9 · Cuando se completa un solo eje, el otro se marca como pendiente

Se adopta autocompletar un eje solo, con un requisito que agrega el equipo: el campo que queda vacío **se marca visiblemente como pendiente**, para que no se confunda con un campo ya resuelto.

Es un requisito nuevo, no estaba en el análisis inicial. Aplica a los 15 códigos del bloque B y a las dorsopatías. A confirmar con Registros.

### D-10 · Sólo a futuro, más una remediación propuesta para los casos activos

El cambio aplica a las denuncias nuevas — mismo criterio que GRV-2239: «lo que ya se hizo se queda así, porque ya se registró en la SRT».

Se agrega, sin embargo, un entregable que no estaba: **analizar y proponer una remediación de los casos activos**. Es una definición del equipo, a confirmar con Registros. Alcance a delimitar, y conviene hacerlo con cuidado:

- La corrección sólo tiene sentido en casos **todavía activos**, no presentados o aún corregibles ante la SRT. Un caso ya aceptado no se toca.
- El universo natural son las **262 denuncias de los 13 conflictos** (bloque C), que es donde el dato cargado contradice al diagnóstico. Pero eso **depende de Q2**: sin el valor correcto definido, no hay a qué corregir.
- Es una propuesta, no una ejecución: el SQL de remediación lo revisa y aplica un senior, como en GRV-2239.

### D-11 · El conflicto es del eje naturaleza, no de la fila — la zona igual se propone

Corrección a la clasificación original. El veredicto `CONFLICTO` se aplicó **por fila**, y eso dejó a los 13 códigos del bloque C sin ninguna relación cargada. Es inconsistente con D-3: los ejes son independientes, y en estos códigos **sólo la naturaleza está en conflicto**. La zona es tan determinable como en los bloques A y B.

Los 13 pasan entonces a comportarse como el bloque B: **zona propuesta, naturaleza libre a criterio de quien carga**.

| CIE-10 | Diagnóstico | Zona propuesta | Concentración |
|---|---|---|---|
| `S22.4` | Fracturas múltiples de costillas | Tórax | 100% |
| `S83.2` | Desgarro de meniscos | Rodilla | 96% |
| `S63.6` | Esguinces y desgarros de dedos de la mano | Dedos de las manos | 90% |
| `S83.4` | Esguinces de ligamentos colaterales | Rodilla | 89% |
| `S83.6` | Esguinces de otras partes de la rodilla | Rodilla | 88% |
| `S42.0` | Fractura de clavícula | Hombro | 86% |
| `S83.5` | Esguinces del ligamento cruzado | Rodilla | 86% |
| `S53.4` | Esguinces y torceduras del codo | Codo | 75% |
| `S82.1` | Fractura de epífisis superior de la tibia | Rodilla | 75% |
| `S63.1` | Luxación de dedos de la mano | Dedos de las manos | 60% |
| `S62.3` | Fractura de otros huesos metacarpianos | Mano (sin dedos) | 33% |
| `S42.2` | Fractura de epífisis superior del húmero | — **sin zona** | ambigüedad real, la elige el sector |
| `M62.1` | Otros desgarros no traumáticos del músculo | — **sin zona** | el código no indica región |

Notas sobre los casos que no son directos:

- **`S42.0` clavícula**: el catálogo SRT no tiene «clavícula» como zona propia — está incluida en «Hombro (con inclusión de clavícula, omóplato…)». Por eso la zona correcta es Hombro.
- **`S62.3` metacarpianos**: la concentración histórica es baja (33%, repartida entre Mano, Muñeca y Dedos), pero anatómicamente el metacarpiano **es** la mano y no los dedos. Se propone por semántica, no por moda — la dispersión refleja mala carga.
- **`S42.2` húmero**: ambigüedad real. La epífisis superior del húmero forma parte de la articulación del hombro, y el catálogo ofrece «Hombro» y «Brazo (incluyendo articulación del húmero)». **No se propone ninguna**: donde hay dos respuestas defendibles, la elige quien carga. Queda sin relación, por D-2.
- **`M62.1`**: sin zona derivable. Queda sin relación, por D-2.

> **Método**: para el eje zona se excluyeron sólo las denuncias con errores de coherencia **de zona** (`L1`, `L3`, `L5`, `GK`, `FA`), no las de naturaleza. Un caso observado por naturaleza inconsistente sigue siendo evidencia válida sobre su zona.

**Efecto sobre la cobertura**: pasan a tener relación **42 códigos** en lugar de 31. Quedan sin relación `S42.2` (zona ambigua) y `M62.1` (sin región).

**Efecto sobre Q2**: deja de ser bloqueante. La naturaleza de estos 13 queda libre, así que la carga inicial puede hacerse sin esperar la definición del sector. Q2 sigue importando para la **remediación** de D-10 — que es corregir lo ya cargado — pero ya no frena la implementación.

### Lo que sigue abierto

| # | Pregunta | Bloquea | Para quién |
|---|---|---|---|
| **Q2** | Los 13 conflictos: ¿cuál es el valor correcto de naturaleza para `S83.x`, `S63.x`, `S42.x`, `S22.4`, `S53.4`, `S62.3`, `S82.1`? Son 262 denuncias ya presentadas. **Ya no bloquea la implementación** (D-11 dejó la naturaleza libre y propuso la zona), pero sigue siendo necesaria para la **remediación** de D-10. | remediación | Registros + Auditoría Médica |
| **Q5** | ¿Quién mantiene la tabla? `especialidades_cie10_defaults` se cargó por SQL en abril de 2026 y nadie la volvió a tocar. Si esta nace con 31 filas y sin pantalla de administración, en seis meses está igual de desactualizada — y peor, autocompletando datos que viajan a la SRT. | operación | equipo + Registros |

Ninguna de las dos bloquea D-7 (el chequeo de coherencia), que sigue siendo desplegable primero.

---

## 3.ter Decisiones tomadas al implementar — 28/08–31/08/2026

Lo que sigue no corrige a D-1…D-11: esas decisiones explican **por qué** el sistema se comporta como se comporta, y siguen vigentes. D-12 en adelante son las decisiones que aparecieron al construir, y que la versión anterior de este documento no reflejaba.

### D-12 · El alcance son cuatro superficies, no una pantalla

**Contexto.** El documento acotaba el autocompletado al **1er diagnóstico de la pestaña General de CEM**. Al relevar el código aparecieron otras superficies donde la terna se carga completa, con los tres campos presentes.

**Decisión.** El autocompletado cubre estas cuatro:

| Superficie | Diagnósticos | Dónde vive |
|---|---|---|
| **CEM · pestaña General** | 1er diagnóstico | `completar.js` |
| **CEM · pestaña General** | 2º y 3er diagnóstico | `multiple10.js` — `Multiple10Row` monta una instancia por diagnóstico |
| **Auditoría Médica** | 2º y 3er diagnóstico | `ComboMultipleCie10.tsx`, gated por módulo `@grv/auditoria-medica` o área «AUDITORIA MEDICA» |
| **Mesa de carga** | los tres bloques | Siniestralidad › Editar siniestro › `DiagnosticoLesiones.tsx` |

Quedan **fuera a propósito**:

- **`contrataciones`** — decisión del equipo.
- **`PantallaLesionLeve` y `PantallaRiesgoMuerte`** de CEM — verificado: sólo arrastran `diagnosticoCie10Codigo` para armar el request, no tienen selector de CIE-10. No hay dónde enganchar el autocompletado.

**Fundamento.** La regla de D-6 no cambia: el alcance lo definen **los campos que cada pantalla ya tiene**, no el número de diagnóstico. Lo que cambió es el relevamiento, no el criterio. Y el argumento de volumen que justificaba acotar al primer diagnóstico (95% de los casos) era un ahorro de alcance, no de código — una vez resuelto el mecanismo, extenderlo a las otras superficies es enganchar el mismo hook.

### D-13 · Al guardar se confirma lo que completó el sistema

**Contexto.** El autocompletado no se dispara sólo cuando alguien elige un diagnóstico. Al **abrir una denuncia que ya tenía el CIE-10 cargado** el efecto corre igual y completa naturaleza y/o zona sin que nadie haya pedido nada. Esos datos viajan a la SRT sin que nadie los haya mirado.

**Decisión.** En **CEM · General · 1er diagnóstico**, cuando el sistema completó naturaleza y/o zona, al guardar aparece un **modal que los lista y pide confirmar**. Reusa `ModalCamposFaltantes` con un tipo nuevo.

Detalle de implementación, porque condiciona el comportamiento:

- Se guarda **el texto que escribió el autocompletado** y se compara contra el valor actual del campo. Si la persona lo editó, ese eje **deja de reportarse** — sin interceptar la edición ni instrumentar el campo.
- El flag viaja en `datosCompletarGeneral.autocompletadoCie10` y **no llega al backend**, porque `UpdateRequestBuilder` arma el request campo por campo.

**Fundamento.** Es el punto más barato donde poner un ojo humano: no bloquea la carga —D-8 sigue valiendo, el valor es editable— ni interrumpe mientras se trabaja, y sólo aparece cuando efectivamente hay algo que el sistema escribió y nadie tocó. La alternativa, no confirmar nada, deja el dato autocompletado indistinguible del cargado a mano justo en el registro que se presenta a la SRT.

### D-14 · El recálculo al cambiar el diagnóstico vive en el servicio, no en las pantallas

**Contexto.** Al cambiar el CIE-10 de una denuncia ya cargada, la naturaleza y la zona quedaban describiendo el código **anterior**. Caso real: una denuncia pasaba de contusión de tórax a contusión de rodilla y la zona seguía diciendo Tórax.

**Decisión.** `modifyDiagnosticoCie10byIdDenuncia`, en `wscie10`, **recalcula la terna**. Las trazadoras y el kill switch se resuelven como «sin relación» y no tocan nada, igual que en la consulta (D-2; tareas 2.3 y 2.4).

**Fundamento.** Resolverlo en cada pantalla obligaría a repetir la misma lógica y a mantenerla sincronizada. Además sigue el patrón que el método **ya usaba** con `recalcularFechaProbableFinIlt` — no introduce una forma nueva de hacer las cosas.

> ⚠️ **Corregido el 02/09/2026.** La versión original de esta decisión afirmaba que `modifyDiagnosticoCie10byIdDenuncia` era «el único punto por el que pasan las tres pantallas». **Es falso.** La **pestaña de Auditoría Médica** guarda con `saveDenunciaAuditoria` contra **`wsauditoria`**, una cuarta vía que no pasa por `wscie10`: por ahí el recálculo **nunca se ejecuta**. Se descubrió probando en TEST — se cambió el diagnóstico, dejó guardar, y la terna quedó describiendo el código anterior sin ninguna advertencia. La cobertura de esa pantalla se resuelve en el front (D-20), no acá.


### D-15 · El recálculo sólo pisa el eje que el catálogo determina

**Decisión.** Al recalcular se actualiza **únicamente el eje que la relación determina**. El eje que el catálogo no determina **conserva el valor que tenía**; no se vacía.

**Fundamento.** Vaciarlo dejaría incompleto un dato que la SRT exige, y lo dejaría incompleto de forma silenciosa: nadie pidió borrarlo. Es la misma asimetría de D-2 aplicada al recálculo — el costo de conservar un valor posiblemente desactualizado es que alguien lo revise; el de vaciarlo es un campo obligatorio en blanco que se descubre al presentar.

### D-16 · La pantalla puede elegir si recalcular — `recalcularTerna`

**Decisión.** El request de modificación del diagnóstico lleva `recalcularTerna`:

| Valor | Comportamiento |
|---|---|
| `true` | se actualizan los ejes que la relación determina |
| `false` | se conserva la terna cargada |
| **ausente** | **equivale a `false`** — no se toca nada |

**Fundamento del default.** *(Revisado el 02/09/2026; ver la nota abajo.)* La naturaleza y la zona ya cargadas **pueden ser correctas** — alguien pudo cargarlas mirando el parte médico. Corregirlas es una decisión del **auditor**, no del sistema: las pantallas avisan de la divergencia y ofrecen aplicarla, y el backend no la resuelve por su cuenta.

> ⚠️ **Cambiado el 02/09/2026.** El default original era `true`, con el argumento de que «quien no manda el flag no tuvo dónde elegir». Se invirtió por decisión del equipo: **el recálculo no debe hacerse sin consentimiento del auditor**. En la práctica no cambió ningún comportamiento — el único consumidor del endpoint es el popover, que siempre manda el flag explícito — pero cierra el caso futuro de una vía nueva que pise la terna en silencio.

**Dónde se ofrece la elección.** El **popover de Auditoría Médica** muestra qué corresponde según el código nuevo, con un **checkbox tildado por defecto**. El bloque **sólo aparece si el catálogo determina algo**: si no hay nada que recalcular, no hay decisión que pedir.

### D-20 · La pestaña de Auditoría Médica avisa, no recalcula

**Contexto.** Esa pantalla **no muestra** naturaleza ni zona para el primer diagnóstico, y guarda contra `wsauditoria`, así que el recálculo de D-14 no la alcanza. Al cambiar el diagnóstico, la terna quedaba describiendo el código anterior y **nadie podía notarlo**: ni se veían los campos, ni había advertencia.

**Decisión.** Al elegir el diagnóstico, la pantalla consulta el catálogo y —si determina una naturaleza o una zona **distinta de la guardada**— muestra un aviso con el valor que correspondería, el que había como referencia, y un botón para aplicarlo. **No recalcula sola.**

```
Según este diagnóstico corresponde:
  Zona afectada: Tobillo (Antes: Cuello)          APLICAR
```

**Fundamento.** Es el mismo criterio de D-16 aplicado al front: el sistema **dice lo que sabe** y la persona decide. El aviso aparece sólo cuando hay divergencia real — si el eje ya coincide no se menciona, y si el código no determina nada (sin relación, trazadora, kill switch apagado) no aparece. Aunque los campos no se muestren, los valores viven en `request.denunciaCie10[0]`, así que el botón los actualiza ahí y viajan en el guardado.

### D-17 · La respuesta obsoleta se descarta — condición de carrera corregida

**Contexto.** El efecto leía los valores de los campos **dentro del `.then()`**, sin tenerlos en las dependencias. Si alguien elegía el CIE-10 y escribía a mano mientras viajaba la consulta, la respuesta **pisaba lo escrito**.

**Decisión.** Los valores se leen **por ref** en el momento de aplicar, y las respuestas que ya no corresponden al código vigente **se descartan**.

**Fundamento.** `react-hooks/exhaustive-deps` está **apagada en el repo**, así que el lint no marcaba el efecto con dependencias incompletas. Queda registrado para que nadie dé por sentado que un efecto limpio de lint está libre de esta clase de bug en estos repos.

### D-18 · La descripción autocompletada se toma del listado local, resuelta por id

**Contexto.** Bug de persistencia en CEM: la pantalla mostraba el valor autocompletado y **al guardar volvía el viejo**.

**Causa.** El id no sale de la respuesta del servicio: `serchIdAutocompletar` lo resuelve **filtrando el listado local** con `valueCampo.includes(it.descripcion)`. Si el texto escrito no coincide carácter por carácter con la descripción del listado, la función **deja el id anterior** — y el id es lo que se persiste.

**Decisión.** El autocompletado escribe la descripción **del listado local, buscada por id**, no la que devuelve el servicio.

**Fundamento.** Es el flujo que la pantalla ya usa cuando una persona elige el valor a mano (D-8: «igual que si lo hubiera elegido una persona»). Escribir un texto que el listado no contiene rompe esa equivalencia de forma invisible: se ve bien y se guarda mal.

### D-21 · La zona anatómicamente determinable se carga aunque la estadística no la respalde

**Contexto.** El análisis de D-3 clasificaba por concentración estadística, y con ese criterio quedaban 31 códigos. Al cargar el catálogo aparecieron casos donde el **nombre del diagnóstico determina la zona** aunque los datos históricos estén dispersos: una fractura de metacarpianos es de la Mano, la dispersión de la carga histórica es ruido de captura.

**Decisión.** La zona se carga cuando es **anatómicamente determinable**, sin exigirle respaldo estadístico. Se aplicó en dos tandas:

| Tanda | Códigos | Qué son |
|---|---|---|
| **Bloque C** — 27/08/2026 | 11 | `S22.4` `S42.0` `S53.4` `S62.3` `S63.1` `S63.6` `S82.1` `S83.2` `S83.4` `S83.5` `S83.6` — fracturas y esguinces cuya zona sale del hueso o la articulación nombrada |
| **Dorsopatías** — 03/09/2026 | 4 | `M54.2` `M54.4` `M54.5` `M54.9` — cervicalgia, lumbalgia, lumbago y dorsalgia |

En los 15 la **naturaleza queda en `NULL`**: es el eje que efectivamente no se puede determinar.

**Total del catálogo: 46 relaciones** — 16 con terna completa, 30 con sólo zona.

**Fundamento.** Es D-4 llevado hasta el final. Si la moda estadística no es fuente de verdad, tampoco puede ser la que veta: descartar `S62.3` porque la carga histórica dice «Mano» sólo el 25% de las veces sería dejar que el ruido decida. El diagnóstico dice de qué zona es; los datos históricos dicen cómo se cargó, que es otra cosa.

> **Por qué las dorsopatías tardaron.** Se las había excluido con el motivo «dorsopatía/no traumático: naturaleza no derivable». Ese motivo es correcto **para la naturaleza** y no dice nada de la zona — una lumbalgia es de la región lumbosacra por definición. La incoherencia salió a la luz cuando QA detectó que la spec de `M54.4` prometía «Región lumbosacra» y el catálogo respondía «sin relación». Se resolvió a favor de la spec.

**Consecuencia para el mantenimiento.** El TSV `matriz-relaciones-candidatas.tsv` quedó alineado: los 15 pasaron a `AUTOCOMPLETA_ZONA` con el motivo del criterio anatómico. La columna `VALIDACION_REGISTROS` **sigue vacía en las 133 filas**: el catálogo lo confirmó desarrollo, no el área de Registros. D-4 pide esa validación y **está pendiente**.

### D-19 · La fase 6 —indicador de coherencia— queda diferida

**Decisión.** El indicador de coherencia previo a la presentación a la SRT **no se implementó**. La capability `validacion-coherencia-terna` describe comportamiento **pendiente**, no construido. La spec se conserva tal como está, marcada como no implementada.

**Fundamento.** D-7 sigue en pie y no cambió: el indicador es informativo, no bloqueante, y —como ya decía— **no depende del catálogo ni de las pantallas de carga**, así que puede construirse y desplegarse después sin rehacer nada. El trabajo se concentró en las cuatro superficies de D-12 y en el recálculo de D-14. Queda explícito acá para que nadie lea la spec de esa capability como descripción del sistema actual.

---

## 4. Método y límites de la evidencia

Los números salen de `datos_denuncia_srt_logs` cruzada con `errores_denuncias_srt` y `codigos_error_srt`, sobre la réplica read-only de producción. Se tomó el último snapshot por denuncia (`MAX(id_log)`) y se excluyeron las denuncias con cualquier observación de coherencia vigente, de modo que los porcentajes describen **sólo ternas que la SRT no objetó**. Corte: 5 casos mínimos por código.

Dos límites explícitos:

1. **«No objetado» no es «correcto».** La SRT no valida todas las combinaciones posibles, así que la ausencia de error es evidencia débil, no prueba.
2. **El eje naturaleza está contaminado** por el default «Contusiones» en todo el dataset. Por eso ningún veredicto sale de la estadística sola (ver D-4).
