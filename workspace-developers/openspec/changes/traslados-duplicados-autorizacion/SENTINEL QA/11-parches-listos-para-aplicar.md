# Parches listos para aplicar — lote de hoy (A2, A3, A5 + grupo C)

| | |
|---|---|
| **Change** | `traslados-duplicados-autorizacion` (INI-2) |
| **Fecha** | 19/08/2026 |
| **Base** | `origin/develop` de cada repo, con `fetch` del 19/08 |
| **Rama sugerida** | `fix/INI-2-hallazgos-qa` |
| **Autor** | Vanesa Yanina Burman — Líder Técnica |

Cada parche trae el **antes**, el **después** y **por qué no rompe nada**, que es la
condición que pusiste. Están ordenados por riesgo creciente.

---

## A2 · El pedido que vale es el último · `wsturnos`

**Archivo:** `src/main/java/ar/com/riovaradero/service/TrasladoDuplicadoValidator.java`
**Método:** `tienePedidoDeExcepcion(Long)`, al final del archivo.

### Antes

```java
    return pedidoDuplicadoRepository.findByAutorizacion(idAutorizacion).stream()
        .anyMatch(
            p ->
                EstadoAutorizacionDuplicadoEnum.PENDIENTE.getCodigo().equals(p.getEstado())
                    || EstadoAutorizacionDuplicadoEnum.APROBADA.getCodigo().equals(p.getEstado()));
```

### Después

```java
    return pedidoDuplicadoRepository.findByAutorizacion(idAutorizacion).stream()
        .findFirst()
        .map(
            p ->
                EstadoAutorizacionDuplicadoEnum.PENDIENTE.getCodigo().equals(p.getEstado())
                    || EstadoAutorizacionDuplicadoEnum.APROBADA.getCodigo().equals(p.getEstado()))
        .orElse(false);
```

Y en el javadoc del método, agregar este párrafo antes de los `@param`:

```java
   * <p><b>Sólo cuenta el último pedido.</b> Antes esto era un {@code anyMatch} sobre toda la
   * lista histórica, y con eso un turno con un pedido aprobado viejo y un rechazo posterior
   * pasaba el gate: el rechazo se neutralizaba con un aprobado anterior. Es el agujero que
   * RF-4.3 nombra, y el mismo criterio que ya usan la grilla —que joinea contra el {@code
   * MAX(id)}— y el repositorio, que devuelve la lista ordenada por id descendente justamente
   * para esto.
```

### Por qué no rompe nada

El repositorio **ya devuelve la lista ordenada descendente** y su propio javadoc lo dice:
*«para tomar el último: si un turno se editó varias veces puede haber más de un pedido
histórico, y el que vale es el último»*. El validador simplemente no lo estaba usando.

Cambio de comportamiento, caso por caso:

| Historial de pedidos | Antes | Después |
|---|---|---|
| Ninguno | bloquea | bloquea — **igual** |
| Sólo pendiente | pasa | pasa — **igual** |
| Sólo aprobado | pasa | pasa — **igual** |
| Sólo rechazado | bloquea | bloquea — **igual** |
| Rechazado, después pendiente | pasa | pasa — **igual** |
| **Aprobado, después rechazado** | **pasa** ← el bug | **bloquea** ← RF-4.3 |

**Sólo cambia la última fila**, que es exactamente el defecto. Ningún caso que hoy funciona
deja de funcionar.

> **Nota:** la fila «rechazado, después pendiente» sigue pasando, y está bien: hay un pedido
> vigente esperando resolución. No es el agujero de RF-4.3.

---

## A3 · Un pedido no se aprueba si su traslado no existe · `wsturnos`

**Archivo:** `src/main/java/ar/com/riovaradero/service/AutorizacionTrasladoDuplicadoServiceImpl.java`
**Método:** `aprobar(AutorizacionTrasladoDuplicado)`

Hoy los dos bloques usan `.ifPresent(...)` y, si la entidad no está, el método devuelve
`aprobada(...)` igual, en silencio. El pedido queda APROBADA sin estado de logística y sin
marca: un estado **indistinguible del correcto** desde cualquier pantalla.

### El cambio, mínimamente invasivo

Agregar un testigo y, si no se aplicó nada, loguear y devolver un resultado distinto.

Al principio del método:

```java
    boolean seAplico = false;
```

En el bloque de traslado, cambiar `.ifPresent(traslado -> {` por una forma que registre el
resultado. La más chica sin reescribir el lambda:

```java
    if (pedido.getIdTraslado() != null) {
      Optional<Traslados> encontrado = trasladoRepository.findById(pedido.getIdTraslado());
      if (encontrado.isPresent()) {
        Traslados traslado = encontrado.get();
        // ... el mismo cuerpo que ya está, sin cambios ...
        trasladoRepository.save(traslado);
        seAplico = true;
      } else {
        logger.warn(
            "El pedido de duplicado {} apunta al traslado {}, que no existe: no se le pudo dar"
                + " estado de logística ni la marca",
            pedido.getIdAutorizacionTrasladoDuplicado(),
            pedido.getIdTraslado());
      }
    }
```

Lo mismo en el bloque de transporte público, con su `logger.warn` propio.

Y antes del `return`:

```java
    if (!seAplico) {
      return ResultadoAutorizacionDuplicadoDTO.noEncontrado(
          Constantes.MSG_DUPLICADO_TRASLADO_NO_ENCONTRADO);
    }
```

Agregar la constante en `Constantes.java`, junto a los otros `MSG_DUPLICADO_*`:

```java
  public static final String MSG_DUPLICADO_TRASLADO_NO_ENCONTRADO =
      "El pedido se aprobó pero no se encontró el traslado asociado. Avisá a soporte.";
```

### Por qué no rompe nada

En el camino normal —el traslado existe, que es el 100 % de los casos sanos— `seAplico`
queda en `true` y el método devuelve exactamente lo mismo que hoy. **La rama nueva sólo se
alcanza en el caso que hoy falla en silencio.**

> **Ojo con un detalle de Java 11:** un `boolean` local no se puede reasignar desde dentro de
> un lambda, por eso el `ifPresent` se convierte en `if (isPresent())`. El cuerpo del lambda
> se copia tal cual, sólo cambia la envoltura.

---

## A5 · El permiso, sin id fijo · `wsturnos`

**Archivo:** `src/main/resources/sql/scripts/alter_autorizaciones_traslado_duplicado_mismo_dia.sql`

El script inserta `id_permiso = 101` con el comentario «el último ocupado es el 100». Ese
comentario **era cierto cuando se escribió y dejó de serlo**:

| Ambiente | Estado del 101 | `MAX(id_permiso)` |
|---|---|---|
| **PROD** | ocupado por `editar_cie10_bloqueado` (GRV-2239 · CIE-10) | **101** → próximo libre **102** |
| **DEV** | ocupado por `log_cirugias` | 1000 (el permiso quedó con ese id) |
| TEST | a verificar antes de aplicar | — |

Pediste generar el cambio con el id que necesita PROD. **Hoy ese id es el 102** — pero
fijarlo repetiría el mismo error dentro de tres semanas, si otro change toma el 102 antes.
Así que el script lo **resuelve solo**, y queda correcto en cualquier ambiente:

```sql
-- El id NO se fija: se toma el próximo libre del ambiente donde se aplica.
-- Fijarlo es lo que rompió este script: se escribió con 101 cuando el último ocupado era
-- el 100, y CIE-10 tomó el 101 en el medio. En PROD, al 19/08/2026, el próximo libre es 102.
INSERT INTO permisos_sas (id_permiso, permiso, descripcion)
SELECT COALESCE(MAX(id_permiso), 0) + 1,
       'autorizar_traslado_mismo_dia',
       'Permite autorizar un segundo traslado del mismo día para el mismo paciente'
  FROM permisos_sas
 WHERE NOT EXISTS (
       SELECT 1 FROM permisos_sas WHERE permiso = 'autorizar_traslado_mismo_dia');
```

La asignación por perfil **ya estaba bien** —resuelve por nombre con `CROSS JOIN`, que es la
decisión D7— así que no se toca. Los perfiles, según tu respuesta a B4, son **supervisor,
referente y jefe de siniestros**:

```sql
INSERT INTO perfiles_permisos_sas (id_perfil, id_permiso)
SELECT pf.id_perfil, pm.id_permiso
  FROM perfiles_sas pf
 CROSS JOIN permisos_sas pm
 WHERE pm.permiso = 'autorizar_traslado_mismo_dia'
   AND pf.perfil IN ('supervisor', 'referente_siniestros', 'jefe_de_siniestros')
   AND NOT EXISTS (
       SELECT 1 FROM perfiles_permisos_sas x
        WHERE x.id_perfil = pf.id_perfil AND x.id_permiso = pm.id_permiso);
```

### Verificación posterior, obligatoria

```sql
SELECT pm.id_permiso, pm.permiso, pf.id_perfil, pf.perfil
  FROM permisos_sas pm
  JOIN perfiles_permisos_sas pp ON pp.id_permiso = pm.id_permiso
  JOIN perfiles_sas pf          ON pf.id_perfil  = pp.id_perfil
 WHERE pm.permiso = 'autorizar_traslado_mismo_dia'
 ORDER BY pf.id_perfil;
```

### Por qué no rompe nada

Es **idempotente** en las dos sentencias (`NOT EXISTS`), así que se puede correr dos veces
sin duplicar. Y como ninguna punta resuelve el permiso por id —backend y frontend lo buscan
**por nombre**, decisión D7— el id que le toque es indiferente para el comportamiento.

> ⚠️ **Pendiente de decisión, y te lo marco porque cambia el alcance:** en tu respuesta a B4
> pusiste «supervisores, referentes, jefes» y **no** mencionaste al **gerente de siniestros
> (perfil 9)**, que hoy **sí tiene el permiso asignado en DEV**. El script de arriba **no se
> lo da**. Si el gerente tiene que entrar, agregá `'gerente_de_siniestros'` a la lista del
> `IN`. Si no tiene que entrar, hay que **quitárselo en DEV**, porque hoy lo tiene.

---

## C1 · Activar los 47 tests de `wslogistica`

**Repo:** `wslogistica` · **Archivo:** `pom.xml`, línea ~25

```xml
<!-- borrar esta línea -->
<skipTests>true</skipTests>
```

**Por qué no rompe nada, con una salvedad honesta:** los 47 tests **pasan** —se corrieron
localmente con `-DskipTests=false` y dieron `BUILD SUCCESS`—, así que activar la ejecución no
debería cambiar el resultado del build. La salvedad: si alguno resultara inestable en el
runner del pipeline, **el build empieza a fallar**. Es el punto de tener tests, pero conviene
sacar esta línea **al principio** del lote y no al final, para verlo con margen.

---

## C2 · Límite de la justificación y del dictamen

La columna es `justificacion VARCHAR(1000) NOT NULL` y `dictamen VARCHAR(1000)` (verificado
en base). Hoy 1.001 caracteres **revierten el alta completa del turno**.

**`wsturnos`**, en los tres lugares:

```java
// dto/autorizacionDuplicado/PedirAutorizacionDuplicadoDTO.java
@NotBlank
@Size(max = 1000)
private String justificacion;

// dto/autorizacionDuplicado/ResolverAutorizacionDuplicadoDTO.java
@Size(max = 1000)
private String dictamen;

// dto/GenerarTrasladoDTO.java  ← el del alta, el que hoy tira abajo el turno entero
@Size(max = 1000)
private String justificacionTrasladoDuplicado;
```

Y en la entidad `AutorizacionTrasladoDuplicado`, para que el esquema y el código digan lo
mismo:

```java
@Column(name = "justificacion", length = 1000, nullable = false)
...
@Column(name = "dictamen", length = 1000)
```

**Por qué no rompe nada:** sólo agrega una validación **por encima** del límite que la base
ya impone. Todo texto que hoy se guarda con éxito tiene 1.000 caracteres o menos, así que
sigue pasando. Lo único que cambia es que un texto demasiado largo ahora da un **400 con
mensaje claro** en lugar de un 500 crudo de JDBC que se lleva puesto el alta.

---

## C5 · El parámetro faltante da 400, no 500

**`wsturnos`** · `controller/GlobalExceptionHandler.java` — agregar el handler:

```java
  @ExceptionHandler(MissingServletRequestParameterException.class)
  public ResponseEntity<ResponseDTO> parametroFaltante(
      MissingServletRequestParameterException ex) {
    logger.warn("Falta el parámetro obligatorio '{}'", ex.getParameterName());
    return ResponseDTO.general(
        HttpStatus.BAD_REQUEST, "Falta el parámetro obligatorio: " + ex.getParameterName());
  }
```

Verificado en vivo: `GET /autorizaciones/mis-duplicados-resueltos` sin `idSolicitante`
devuelve hoy **500**.

**Por qué no rompe nada:** sólo captura una excepción que hoy cae al handler genérico. No
toca ningún camino exitoso. **Revisar antes** que el `@ControllerAdvice` no tenga ya un
handler de `Exception` que la intercepte primero: si lo tiene, este método más específico
gana por precedencia de Spring, pero conviene confirmarlo.

---

## C3 y C4 · Frontend de logística

**Repo:** `frontend/logistica` (rama limpia, `feature/marca-duplicado-autorizado`; el
`develop` local está 12 días atrás de `origin/develop`).

- **C3** — el ícono de duplicado autorizado usa `fill="#F29423"`, **el mismo naranja que la
  leyenda asigna a «Requiere revisión»**, y el glifo es un octógono de advertencia con «!».
  Debería usar el **teal `#0B8F8A`** de su propia franja y de su entrada en la leyenda, y un
  glifo que no comunique peligro —un check, o un doble check— porque lo que representa es una
  **excepción concedida**, no un problema.
- **C4** — los botones del `tbody` de la grilla no tienen `aria-label` ni `title`; **9 de 9**,
  incluida la acción de **cancelar**. Los dos íconos del change sí tienen `alt` desde i18n:
  el resto quedó con `alt="icon"`.

Estos dos los dejo descriptos y no parcheados porque son de otro repo y de otro equipo, y el
cambio de ícono conviene que lo valide quien definió la leyenda.

---

## C6 · La advertencia que falta en la guía de datos de prueba

Agregar a `analisis/pool-datos-test.md`, en su sección de armado:

> ⚠️ **No insertar `autorizaciones` por SQL.** `autorizaciones.id_autorizacion` **no es
> `AUTO_INCREMENT`**: lo asigna un `@TableGenerator` de Hibernate sobre la tabla
> `key_generator`, fila `ID_AUTORIZACION`. Insertar filas calculando `MAX(id)+1` a mano ocupa
> ids sin avanzar el secuenciador, y a partir de ahí **todo alta de turno de la base falla**
> con `ConstraintViolationException / constraint [PRIMARY]`.
>
> Si ya pasó, se resincroniza con:
> ```sql
> UPDATE key_generator
>    SET KEY_VALUE = (SELECT MAX(id_autorizacion) + 1 FROM autorizaciones)
>  WHERE KEY_NAME = 'ID_AUTORIZACION';
> ```
> Ocurrió el 19/08/2026 al armar el pool de la denuncia 999033 en TEST.

---

## Lo que queda afuera del lote, y por qué

| Ítem | Motivo |
|---|---|
| **A1** — identidad por token | **Tu decisión:** `wsturnos` no puede tener JWT todavía. Queda como **riesgo aceptado y documentado**, no como hallazgo abierto |
| **A4** — que la cancelación devuelva su resultado | **No lo respondiste.** Es de costo medio y toca `wslogistica` y `wsturnos`. Sugiero dejarlo para el paso siguiente, pero decidilo vos |
| **Grupo B** salvo B4 y B5 | B1 queda como está; B2 y B3 van a **etapa 2** |
| **Grupo E** completo | Deuda registrada, no bloquea |

### Dos consecuencias de tus respuestas que hay que propagar

- **B5 — se corrige el requisito, no el código.** Entonces **RF-5.1 hay que enmendarlo** para
  admitir el número de turno, y con eso **EXP-02 y el caso CTM-05 dejan de ser defectos**.
  Hay que tocar el PRD y la spec de `conflicto-traslado-mismo-dia`.
- **A1 aceptado** cambia el veredicto del informe ejecutivo: pasa de «bloqueante» a «riesgo
  aceptado con decisión registrada». Lo actualizo cuando me confirmes.

---

## Orden sugerido para hoy

1. **C1** primero, para ver el build con margen.
2. **A2** — es el más importante y el más chico.
3. **C2** y **C5** — validaciones, sin riesgo.
4. **A3** — el más largo de los tres, pero acotado a un método.
5. **A5** — el script, con su verificación posterior corrida en cada ambiente.
6. **C6** y el grupo **D** — documentación, en paralelo por otra persona.

Después de aplicar: `mvn test` en `wsturnos` (51 tests) y en `wslogistica` con
`-DskipTests=false` (47 tests). **Los nueve tests de `TrasladoDuplicadoValidatorTest` cubren
A2**, así que si pasan, el cambio no rompió el gate.

---

Generado por Vanesa Yanina Burman — Líder Técnica · 19/08/2026
