# Verificación de base de datos — traslados duplicados (INI-2)

| | |
|---|---|
| **Change** | `traslados-duplicados-autorizacion` |
| **Ticket** | INI-2 |
| **Fecha** | 18/08/2026 |
| **Vía** | MCP de MariaDB, sólo `SELECT` / `SHOW` / `information_schema` |
| **Objetivo** | Confirmar de forma independiente las tareas 1.6 y 2.4 de `tasks.md` («aplicar en TEST y verificar») |

---

## 0. Resumen ejecutivo

**El objetivo no se pudo cumplir, y el motivo es en sí mismo el hallazgo principal: el MCP de
MariaDB está conectado a la base de PRODUCCIÓN, no a TEST.** Desde ese servidor no se alcanza
ningún otro ambiente, así que las tareas 1.6 y 2.4 **quedan sin verificación independiente**.

Lo que sí produjo la sesión, aprovechando que el acceso resultó ser a producción:

| # | Hallazgo | Severidad |
|---|---|---|
| **VBD-01** | El MCP de MariaDB apunta a **producción**, sobre un **primario escribible** | **ALTA** (seguridad / método) |
| **VBD-02** | El script de alta del permiso **colisiona en producción**: `id_permiso = 101` ya está ocupado | **BLOQUEANTE** (despliegue) |
| **VBD-03** | Confirmado que **nada del change está aplicado en producción** — línea de base limpia | Informativo |
| **VBD-04** | La medición de negocio del PRD **se valida** contra producción | Informativo (refuerza el caso) |
| **VBD-05** | Tareas 1.6 y 2.4 **no verificadas** — sin acceso a TEST | **ALTA** (cobertura) |

---

## 1. VBD-01 — El MCP apunta a producción

### Identificación del servidor

```sql
SELECT @@hostname, @@server_id, @@version, @@read_only, DATABASE(), USER(), @@log_bin;
```

| Campo | Valor |
|---|---|
| `@@hostname` | `ip-172-19-1-25` |
| `@@version` | `10.5.29-MariaDB-log` |
| `@@read_only` | **`0`** — escribible |
| `@@log_bin` | **`1`** — es un **primario**, no una réplica |
| `USER()` | `cs@10.1.100.254` |

`list_databases` expone únicamente `cs` e `information_schema`: **desde este MCP no se puede
alcanzar TEST ni DEV.**

### La prueba de que es producción

Es concluyente por convergencia de cuatro señales independientes.

**(a) El volumen de negocio coincide con la medición del PRD sobre producción.**

```sql
SELECT m.id_motivo_traslado_mismo_dia, m.descripcion, COUNT(a.id_autorizacion)
FROM motivos_traslado_mismo_dia m
LEFT JOIN autorizaciones a
       ON a.id_motivo_traslado_mismo_dia = m.id_motivo_traslado_mismo_dia
GROUP BY 1, 2;
```

| Motivo | Medido acá | PRD (2026) | PRD + 2025 |
|---|---|---|---|
| Autorizado por Supervisión | **1.356** | 1.216 | — |
| Autorizado por Auditoria Medica | **1.025** | 940 | — |
| **Total** | **2.381** | **2.156** | **2.340** |

El PRD declara 2.156 en 2026 más 184 en 2025 = 2.340. Acá hay 2.381, con la misma proporción
entre ambos motivos. Es el mismo universo, con la diferencia esperable por los días
transcurridos desde la medición.

**(b) La denuncia del pool de TEST no existe.** `id_denuncia = 999031` → 0 filas. El
`analisis/pool-datos-test.md` afirma haberla cargado y verificado en TEST el 18/08.

**(c) Los usuarios de prueba de TEST no existen.** `id_persona` 1000007 (solicitante) y
1000008 (autorizante) → ausentes.

**(d) Escala de producción.** 516.602 denuncias, 5.118.327 turnos, 1.622.171 traslados.

### Por qué importa

Cualquier verificación de «¿está aplicada la migración en TEST?» hecha con este MCP **responde
en realidad por producción y da un falso negativo**. Es exactamente el error de método que el
propio SDD se señaló en su nota de revisión del 18/08 al eliminar la discrepancia D-16:
*«¿esto lo verifiqué contra el código o lo estoy recordando?»* — acá la variante es *contra
qué base lo verifiqué*.

Y hay un riesgo operativo: la credencial está contra el **primario escribible de producción**.
La herramienta del MCP se declara read-only, pero esa garantía es de la capa de herramienta,
no de la base. **Toda query por esta vía debe tratarse como si corriera contra producción.**

---

## 2. VBD-02 — El script del permiso colisiona en producción · **BLOQUEANTE**

### El hallazgo

```sql
SELECT MAX(id_permiso), COUNT(*) FROM permisos_sas;
-- max_permiso = 101, total = 77

SELECT id_permiso, permiso FROM permisos_sas ORDER BY id_permiso DESC LIMIT 3;
```

| `id_permiso` | `permiso` |
|---|---|
| **101** | **`editar_cie10_bloqueado`** |
| 100 | `ver_auditoria_automatica_facturas` |
| 99 | `desimputar_traslados` |

El script `alter_autorizaciones_traslado_duplicado_mismo_dia.sql` inserta el permiso
`autorizar_traslado_mismo_dia` con **`id_permiso = 101`**, con el comentario *«el último
ocupado es el 100»*.

**Ese comentario era cierto cuando se escribió y dejó de serlo.** El 101 lo tomó
`editar_cie10_bloqueado`, del change **GRV-2239 «CIE-10 · Trazadoras»** — que es, con ironía,
el mismo ticket con el que INI-2 se venía confundiendo y del que el PRD tuvo que desprenderse
explícitamente (decisión del 18/08).

### Consecuencia

Al aplicar el script en producción, según cómo esté escrito el `INSERT`:

- si es un `INSERT` plano → **falla por clave duplicada** y aborta la migración;
- si trae `ON DUPLICATE KEY UPDATE` o es un `REPLACE` → **pisa el permiso de CIE-10** y rompe
  una funcionalidad ajena, en silencio.

El segundo escenario es el peligroso: no da error y deja a los usuarios de CIE-10 sin su
permiso.

### Por qué el SDD no lo detectó

Su discrepancia **D-10** quedó marcada como *«no verificable — requiere acceso a la base»*, y
después se **bajó de severidad** a «nota de prolijidad, funcionalmente irrelevante», con este
argumento: el permiso se resuelve **por nombre** en backend (`AND perm.permiso = :permiso`) y
en frontend (`hasPermission` sobre el string), así que el id da igual.

**El argumento es correcto para el runtime y no aplica a la migración.** La colisión no está
en cómo se resuelve el permiso, sino en cómo se lo da de alta. La bajada de severidad dejó
pasar un bloqueante de despliegue.

### Corrección propuesta

Que el script **no fije el id**: que lo deje al `AUTO_INCREMENT` y resuelva la FK de
`perfiles_permisos_sas` por nombre — exactamente el criterio que la decisión **D7** del
`design.md` ya adoptó para la asignación por perfil (`CROSS JOIN` por nombre). El script sería
así internamente coherente con su propia decisión de diseño.

> Verificar además el mismo choque en **STAGE** antes de promover (tarea 1.7), donde el estado
> de `permisos_sas` no fue relevado por nadie.

---

## 3. VBD-03 — Nada del change está aplicado en producción

Línea de base limpia, como corresponde a las tareas 1.8 y 2.5 sin marcar.

| Artefacto esperado | Query | Resultado |
|---|---|---|
| Tabla `autorizaciones_traslado_duplicado` | `information_schema.TABLES ... LIKE '%duplicad%'` | **0 filas** |
| `traslados.es_duplicado_autorizado` | `information_schema.COLUMNS ... LIKE '%duplicado%'` | **0 filas** |
| `autorizaciones_traslado_duplicado.fecha_visto_solicitante` | `... LIKE '%visto_solicitante%'` | **0 filas** |
| Permiso `autorizar_traslado_mismo_dia` | `permisos_sas WHERE permiso LIKE '%mismo_dia%'` | **0 filas** |
| SPs que referencien el circuito | `ROUTINE_DEFINITION LIKE '%duplicado%'` | sin coincidencias del circuito |

Lo que **sí** existe y es **preexistente** al change: la tabla catálogo
`motivos_traslado_mismo_dia` (2 filas) y la columna `autorizaciones.id_motivo_traslado_mismo_dia`.
Es el gate autodeclarativo que el PRD describe como ya vigente — el que «se llena y nadie
aprueba».

---

## 4. VBD-04 — La medición de negocio del PRD se valida

El caso de negocio del change se sostiene: **2.381 autorizaciones declaradas contra un circuito
que no existe**, con `autorizaciones_traslado_duplicado` inexistente en producción. El número
del PRD no estaba inflado; si acaso creció desde que se midió.

Esto es relevante para la priorización: el desarrollo ataca un problema real y medible, y el
volumen sigue subiendo mientras el circuito no se despliega.

---

## 5. VBD-05 — Lo que quedó sin verificar

| Tarea de `tasks.md` | Estado declarado | Verificación independiente |
|---|---|---|
| 1.6 Aplicar en **TEST** y verificar | `[x]` | **NO VERIFICADA** — sin acceso |
| 2.4 Aplicar SPs en **TEST** | `[x]` | **NO VERIFICADA** — sin acceso |
| 1.5 Aplicar en **DEV** y verificar | `[x]` | **NO VERIFICADA** — sin acceso |
| 1.7 Aplicar en **STAGE** | `[ ]` | Pendiente; **revisar VBD-02 antes** |
| 1.8 Aplicar en **PROD** | `[ ]` | Confirmado no aplicado (VBD-03) |

### Cómo cerrarlo

1. **Reapuntar o agregar un MCP contra TEST**, con credencial de sólo lectura, y repetir las
   cinco comprobaciones de la sección 3 más el conteo del pool (`observaciones LIKE 'INI-2 POOL
   TEST%'`, esperado: 5 turnos y 3 pedidos en estados 1/2/3).
2. Mientras tanto, la verificación de TEST **sólo puede hacerse por la aplicación**, no por
   base — con la limitación de que un 404 de endpoint no distingue «base sin aplicar» de
   «código sin desplegar».
3. **Antes de STAGE y PROD**, relevar `SELECT MAX(id_permiso) FROM permisos_sas` en cada
   ambiente y corregir el script según VBD-02.

---

## 6. Alcance de lo ejecutado

Sólo lectura: `SELECT`, `SHOW`, `DESCRIBE` e `information_schema`. **No se ejecutó ningún DDL
ni DML.** No se modificó ninguna fila en ningún ambiente.

---

Generado por Vanesa Yanina Burman — Líder Técnica · 18/08/2026
