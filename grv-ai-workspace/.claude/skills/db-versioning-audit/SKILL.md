---
name: db-versioning-audit
version: v1
maturity: alpha
owner: "[DEVOPS_REFERENT]"
category: engineering
related_skills: [mariadb-migration-review, changelog-keeper]
related_agents: [grv-doc-keeper, grv-migration-guard]
triggers:
  - "usuario pregunta si el schema en prod está al día"
  - "usuario sospecha drift entre migraciones del repo y schema real"
  - "preparación de release: validar estado de migraciones"
---

# Skill: db-versioning-audit

## Propósito

Auditar el versionado de base de datos de un servicio: qué migraciones
SQL están en el repo, qué se aplicó en dev, qué se aplicó en prod, y
detectar drift.

**Nota importante**: no usamos Flyway. El proceso de tracking de migraciones varía por servicio. Este skill pregunta cómo trackea cada servicio antes de auditar (ver sección "Información que pido"). Cuando el equipo confirme la herramienta estándar, este skill se actualizará para integrarla automáticamente (ver TODO).

## Cuándo usarme

- Antes de release: "¿qué migraciones faltan aplicar en prod?"
- Sospecha de drift: alguien tocó prod a mano y no lo documentó.
- Onboarding: ver el histórico de schema de un servicio.
- Preparación de backup/restore.

## Cuándo NO usarme

- Para aplicar migraciones — eso es dominio del proceso de deploy del equipo.
- Para revisar una migración específica — usar `mariadb-migration-review`.

## Información que pido

1. **Servicio** a auditar.
2. **Ambiente(s)** a comparar (repo vs dev, repo vs prod, dev vs prod).
3. **Cómo trackeamos migraciones aplicadas en este servicio**. Por ejemplo:
   - ¿Hay tabla `schema_version` o `migrations` en la BD del servicio?
   - ¿Hay archivo de referencia en la infra?
   - ¿Es manual y se lleva en algún doc?
   Esta pregunta es clave porque no usamos Flyway y la respuesta varía.

## Flujo

1. Listar las migraciones en el repo del servicio (carpeta de migraciones SQL, ordenadas).
2. Consultar el mecanismo de tracking del servicio (según la respuesta del usuario).
3. Consultar la BD del ambiente via MCP MariaDB (dev por default, prod con confirmación explícita).
4. Comparar:
   - Migraciones en repo que no se aplicaron al ambiente.
   - Migraciones aplicadas al ambiente que no están en el repo (drift).
   - Diferencias de orden o contenido.
5. Generar reporte.

## Output

```
===========================================================
DB VERSIONING AUDIT — <servicio>
Ambientes comparados: repo vs <dev|prod>
===========================================================

MIGRACIONES EN REPO
  total: <n>

MIGRACIONES APLICADAS EN <ambiente>
  total: <n>

DIFERENCIAS
  🔴 En repo pero no aplicadas en <ambiente>:
    - <lista>

  🟡 Aplicadas en <ambiente> pero no en repo (drift):
    - <lista>

  🟢 Coincidentes: <n>

OBSERVACIONES
  [cualquier cosa rara: cambios de orden, nombres casi iguales, etc]

ACCIONES SUGERIDAS
  [lo que el usuario debería hacer con esta info]
```

## Ejemplo de pregunta previa

**Usuario**: Auditá wssiniestralidad contra prod.

**Respuesta**:
```
Antes de tocar prod, necesito dos cosas:

1. ¿Cómo trackeamos en wssiniestralidad qué migraciones se aplicaron?
   ¿Hay una tabla (ej: schema_version) o es manual? Esto es clave porque
   no usamos Flyway y el mecanismo puede variar por servicio.

2. Confirmación de cambio a prod. Por defecto estoy en dev. Si querés
   que audite contra prod, decímelo explícitamente y ejecuto queries
   read-only con LIMIT y max_execution_time corto.

Mientras tanto, puedo ya listarte las migraciones en el repo del servicio.
¿Querés empezar por ahí?
```

## Límites

- **Alpha**: depende del mecanismo de tracking real, que no está
  estandarizado todavía.
- No aplica migraciones — solo audita.
- No puede detectar drift de objetos que no sean tablas (triggers, views,
  procedures) sin ajustes específicos.

## TODO para promover a beta

- [ ] Documentar el mecanismo de tracking por servicio.
- [ ] Soporte para comparación dev vs prod directamente.
- [ ] Detectar drift en triggers, views, stored procedures.
