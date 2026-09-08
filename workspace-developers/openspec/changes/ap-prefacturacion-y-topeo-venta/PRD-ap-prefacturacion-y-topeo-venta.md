# PRD — Prefacturación al cliente y topeo sobre valor de venta (AP)

> Documento de producto. El diseño técnico está en [`design.md`](design.md), los requisitos con
> sus escenarios en [`specs/`](specs/), y el mapa de circuitos en
> [`../../../docs/ap-costos/AP-Circuitos-e-Integracion.md`](../../../docs/ap-costos/AP-Circuitos-e-Integracion.md).

---

## 1. Objetivo

Que Colonia Suiza pueda **facturarle a sus clientes lo que consumió cada siniestro de Accidentes
Personales**, desde el sistema y no desde un Excel, y que el **semáforo de topes mida lo que se le
cobra al cliente** en lugar de lo que le cuesta al negocio.

Son dos cosas que hoy no existen: el sistema modela la factura que **entra** del prestador, no la
que **sale** al cliente.

---

## 2. Contexto y problema

### 2.1 Hoy son cinco pasos y facturación controla dos

```
[1] Facturación le pide el exportado a Planeamiento
        ↓  un archivo por cliente, 5 solapas cada uno
[2] Alguien corre un exportador que NO está en ningún repo del SAS
        ↓  y para 2 clientes ni siquiera existe: se arman a mano
[3] Facturación depura a ojo (saca los no realizados, colapsa sesiones)
        ↓
[4] Arma su detalle: retipea fechas y números, parte columnas concatenadas,
    y TIPEA A MANO el valor de venta de cada línea
        ↓
[5] Prefactura sobre ese detalle
```

Los pasos 1 y 2 son de otro equipo. El paso 4 es **trabajo de reconstrucción que existe sólo
porque el insumo llega mal formateado**.

### 2.2 Lo que cuesta, medido

| Hecho | Medición |
|---|---|
| El exportador no está en ningún repo | `grep -r` sobre los 60 repos del SAS: **0 coincidencias** |
| Hay clientes sin exportado | IAPSER tiene **$ 102,8 M** de erogaciones en un mes y **ningún Excel** |
| Se pierde consumo real | El Excel de julio dejó afuera **$ 309.911,65** de ortopedia y **23 turnos realizados**: no se facturaron y nadie se enteró |
| El insumo trae basura | **63 de 392 filas** (16 %) son no realizados que hay que depurar a ojo |
| Los códigos se corrompen | **16 de 38** códigos de prestación llegan corruptos por el formato del Excel |
| El archivo no compara contra el tope | La única cifra con IVA aparece una vez por siniestro y **no está acumulada** |
| Los números se mueven solos | La misma consulta dio **$ 22.621.920,43** el 21/08 y **$ 22.621.928,68** el 25/08 |

### 2.3 Y el semáforo mide lo que no es

El motor de consumo topea sobre el **costo del prestador**. Negocio definió que se topea sobre el
**valor de venta + 21 %**, que es lo que se le cobra al cliente y contra lo que el cliente compara
la suma asegurada. Textual: *"el tope asegurado es cinco millones… con el IVA"*, *"para hacer el
topeo tenés que sumarle a todas las prestaciones el 21"*.

Es **el numerador del semáforo de todos los siniestros AP**.

---

## 3. Usuarios

| Perfil | Quién | Qué hace en este módulo |
|---|---|---|
| **Facturación de prestaciones** | Jefatura de Facturación | Prefactura el mes por cliente, revisa lo que cambió, cierra y emite la factura |
| **Comercial** | Gerencia Comercial y su analista | Carga y mantiene la **grilla de valores de venta** por cliente y zona, arma presupuestos, mira el margen |
| **Tramitador analista AP** | Tramitadores | Ve el siniestro completo y su consumo contra la suma asegurada |

**La separación que importa:** el **valor de venta lo carga comercial**, no facturación. Hoy
facturación lo teclea a mano —*"nosotros le ponemos el valor de venta… es un trabajo manual,
básicamente"*— y ese paso desaparece: no es una función que haya que conservar.

---

## 4. Alcance

### 4.1 Entra

- **Prefactura por cliente y período**, que se arma tildando lo realizado.
- **Estado por ítem**: pendiente de prefacturar → prefacturado → prefacturado observado, reversible
  hasta facturar.
- **Una sola tabla con columna Origen** para las cinco fuentes (erogaciones, turnos, ortopedia,
  material quirúrgico, reintegros; traslados cuando corresponda).
- **Valor de venta** por cliente × prestación × zona × vigencia, con aumento masivo, exclusiones,
  duplicación entre clientes, histórico y exportación.
- **Topeo sobre valor de venta + IVA**, con las cinco bandas del semáforo y el aviso al 90 %.
- **Congelado de importes** al cerrar la prefactura.
- **Detección de erogaciones tardías** y del doble conteo ortopedia → erogación.
- **Exportables** en Excel y PDF con el detalle de la prefactura.

### 4.2 No entra en esta etapa

| Qué | Por qué |
|---|---|
| **Medicación** | `consumo_medicamentos` tiene **0 filas** AP, no hay integración con Kairos y no lleva autorización. Entra como ítem manual; la pantalla queda **en construcción** |
| **Número de autorización en la carga masiva** | Es de otro equipo. Hoy está vacío en el **99,06 %** de las filas |
| **Vínculo erogación → turno** | No existe en el modelo y construirlo es desarrollo nuevo |
| **Facturación electrónica / AFIP** | Fuera de alcance: acá se registra la factura emitida, no se emite |

---

## 5. Qué gana facturación

### 5.1 Pasos que desaparecen

- Pedir el Excel y esperar.
- Depurar los no realizados a ojo (63 de 392 filas).
- Retipear 17 columnas y partir las concatenadas.
- **Buscar el valor unitario en una lista externa** (38 de 38 filas).
- Escribir 62 fórmulas.
- Acordarse de qué facturó el mes pasado.

### 5.2 Control que gana, y hoy no tiene a ningún precio

1. **Ve el consumo completo**, incluido lo que el Excel deja afuera.
2. **Sabe qué le falta antes de empezar**: los códigos sin precio son una lista concreta para
   reclamarle a comercial, no un campo en blanco que sólo ella sabe que existe.
3. **Ve el tope**: hoy su archivo no compara nada contra la suma asegurada.
4. **Puede explicar un importe dos años después**: cada ítem guarda el valor aplicado, su vigencia
   y de dónde salió.
5. **Deja de depender de una persona y de un script que nadie del equipo puede abrir.**
6. **Los importes quedan congelados al cerrar.**

### 5.3 Qué pierde, dicho de frente

Pierde el Excel: una hoja en blanco donde puede hacer cualquier cosa sin pedir permiso. Lo que
**no** va a poder es cambiar un número sin dejar rastro — y eso es el punto, no un efecto
colateral. A cambio, un error del insumo (los $ 309.911,65) deja de ser invisible.

---

## 6. Requisitos funcionales

Los requisitos formales, con sus escenarios en formato Given/When/Then, están en
[`specs/`](specs/) — **45 requisitos** repartidos en ocho capacidades:

| Capacidad | Qué cubre |
|---|---|
| `ap-prefacturacion-cliente` | la prefactura, los estados del ítem, totales, trazabilidad |
| `ap-valor-venta` | la grilla por cliente y zona, aumentos, vigencias |
| `ap-consumo-topeo` | las tres instancias, la base de valorización, el anti-doble-conteo |
| `ap-semaforo-gestion` | las bandas, el aviso al 90 %, el débito del excedente |
| `ap-erogaciones-tardias` | las tres vías de entrada y el marcado de tardías |
| `ap-home-prefacturacion` | los indicadores del inicio |
| `ap-perfiles-acceso` | la separación entre los dos perfiles |
| `ap-precios-medicacion` | por qué queda en construcción y cómo entra mientras tanto |

---

## 7. Cómo se sabe que funcionó

| Señal | Cómo se mide |
|---|---|
| Facturación deja de pedirle el exportado a Planeamiento | no hay más pedidos por mail |
| Los clientes sin Excel se facturan | IAPSER y WORANZ tienen prefactura del mes |
| No se pierde consumo | el total de la prefactura ≥ el del Excel del mismo período |
| No se factura dos veces | cero débitos del cliente por duplicación |
| El semáforo avisa antes | siniestros que llegan al 90 % con aviso registrado, antes de excederse |

---

## 8. Supuestos y dependencias

1. **V004-V006 desplegadas.** Hoy hay **0 tablas `ap_*` en producción**. Sin la grilla no hay valor
   de venta y nada de esto tiene numerador.
2. **La grilla cargada.** Medido: **10 filas por cliente cubren el 92 %** del volumen. Es trabajo
   de comercial.
3. **La suma asegurada en `polizas_ap`**, que negocio ya empezó a cargar.
4. **El estimado se dispara al autorizar**, y la cancelación lo resta. Sin esto el semáforo avisa
   tarde.

---

## 9. Riesgos conocidos

| Riesgo | Medición | Mitigación |
|---|---|---|
| Cambiar el numerador afecta a **todos** los siniestros AP | el semáforo pasa de costo a venta | el fix de IVA ya tiene test que rompe el build si alguien hardcodea el 1,21 |
| El corte de turnos no es reproducible | Excel 392 vs consulta 398, **intersección 288** | la tabla de prefacturas hace explícito el criterio "lo que no entró antes" |
| Doble conteo ortopedia → erogación | `relacion_erogaciones_det_ortopedia` lo permite detectar | se marca, se excluye por defecto y queda visible |
| Los códigos se duplican | `42.03.04` y `420304` conviven como códigos distintos | normalizar al resolver el valor |
| La factura del prestador llega tarde | **45,7 días** de demora promedio, hasta **401** | se prefactura sin esperar el costo |

---

## 10. Preguntas abiertas

Las ocho preguntas que no puede contestar desarrollo están en la sección 7 de
[`AP-Circuitos-e-Integracion.md`](../../../docs/ap-costos/AP-Circuitos-e-Integracion.md):
corte de erogaciones, agrupamiento de kinesiología, consumo retroactivo, estado facturable de
ortopedia y material quirúrgico, monto del reintegro, valorización de cirugías, unidad de
facturación y alcance de clientes.

---

## 11. Decisiones cerradas

| Decisión | Cuándo | Quién |
|---|---|---|
| El tope se mide **con IVA**; la venta se carga **sin IVA** | 20/08/2026 | Gerencia Comercial |
| El semáforo corre sobre la **proyección**; el cierre y el débito, sobre el **facturado** | 20/08/2026 | — |
| El valor de venta lo carga **comercial**, no facturación | 09/2026 | — |
| Un ítem sin precio **nunca vale $ 0** | — | criterio de diseño |
| La medicación queda **en construcción** en esta etapa | 09/2026 | — |
| El documento se llama **prefactura**, no "lote"; la unidad es **ítem**, no "línea" | 09/2026 | vocabulario del área, verificado en transcripción |
| Se **habilita** un cliente existente para AP, no se da de alta uno nuevo | 09/2026 | Gerencia Comercial |
