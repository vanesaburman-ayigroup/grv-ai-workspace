# Prompt: Onboarding técnico profundo a un servicio GRV

Usá este prompt para onboardear a un dev nuevo (o a alguien que viene de otro equipo) a un servicio específico. Cubre lo que no está en el README.

---

## Servicio a documentar

**Nombre**: ___  
**Repositorio**: ___  
**Preparado por**: ___  
**Fecha**: ___

---

## 1. Propósito del servicio

**¿Qué problema de negocio resuelve?**
<!-- Contexto de dominio: qué hace desde la perspectiva del negocio, no del código. Ver skills/domain/ relevantes. -->

**¿Qué unidades de negocio GRV usa este servicio?**
- [ ] Siniestros laborales (ART)
- [ ] Accidentes personales
- [ ] Autoasegurados
- [ ] Otro: ___

---

## 2. Arquitectura del servicio

**Stack**:
- Runtime: Java ___ + Spring Boot ___
- BD: MariaDB (base: ___)
- Mensajería: SQS (colas: ___) / No usa mensajería
- Frontend propio: Sí (MFE: ___) / No

**Entidades principales de BD** (las 3-5 tablas más importantes):

| Tabla | Descripción |
|---|---|
| | |

**¿Hay tablas heavy?** (ver `context/heavy-tables.yaml`)
- [ ] Sí: ___ → Cualquier cambio requiere `database-design-heavy-table`
- [ ] No

---

## 3. APIs expuestas

**URL base**: `/v1/___`

| Endpoint | Método | Qué hace | Quién lo consume |
|---|---|---|---|
| | | | |

> Para el detalle completo, ver el `openapi.yaml` del servicio (si existe) o correr `openapi-from-scratch`.

---

## 4. Dependencias del servicio

**Servicios que llama este servicio** (dependencies upstream):

| Servicio | Para qué | Cómo (REST/SQS/BD) |
|---|---|---|
| | | |

**Servicios que llaman a este servicio** (dependencies downstream):

| Servicio | Para qué |
|---|---|
| | |

> Verificar con `context/microservices.yaml` que esta información esté actualizada.

---

## 5. Patrones usados en el servicio

- [ ] Outbox pattern → tabla: ___
- [ ] Circuit breaker → en llamadas a: ___
- [ ] Spring Retry → en: ___
- [ ] Feature flags → para: ___
- [ ] CQRS / separación read/write → en: ___
- [ ] Otros: ___

---

## 6. Trampas conocidas y lecciones aprendidas

<!-- Esto es lo más valioso de este documento: lo que no está en el código.
 Bugs conocidos, edge cases que sorprendieron, decisiones que parecen raras pero tienen historia. -->

| Trampa | Descripción | Cómo evitarla |
|---|---|---|
| | | |

> Ver `context/known-bugs.yaml` para bugs abiertos relacionados.

---

## 7. Cómo ejecutar el servicio localmente

```bash
# 1. Prerequisitos
# TODO: listar dependencias (Docker, BD local, variables de entorno)

# 2. Variables de entorno mínimas
# Ver .env.example en el workspace

# 3. Levantar el servicio
# TODO: comando exacto

# 4. Verificar que está andando
curl http://localhost:8080/actuator/health
```

**Datos de prueba**: <!-- dónde conseguirlos / cómo crearlos -->

---

## 8. Flujo de deploy

```
1. Push a branch → CI en Jenkins corre los tests
2. MR → review con grv-reviewer antes de mergear
3. Merge a main → deploy automático a dev
4. Deploy a producción: <!-- proceso manual/automatizado, quién lo hace -->
```

**Tiempo típico de deploy**: ___

---

## 9. Acceso y permisos necesarios

| Sistema | Tipo de acceso | Quién provee |
|---|---|---|
| GitLab | Dev / Read | ___ |
| BD MariaDB dev | Readonly / Write | MCP `mariadb-dev` |
| Jenkins | Ver builds / Deployar | ___ |
| Sentry | Ver errores | ___ |

---

## 10. Primer ticket sugerido

Para que el dev nuevo tenga un aterrizaje suave, el primer ticket debería:
- Ser de complejidad S (1-2 días)
- Tocar el flujo más importante del servicio (no un caso borde)
- No incluir migration SQL ni breaking changes en API

**Sugerencia**: ___

---

## Notas del onboarder

<!-- Cualquier información adicional que el onboarder quiera dejar al dev nuevo -->
