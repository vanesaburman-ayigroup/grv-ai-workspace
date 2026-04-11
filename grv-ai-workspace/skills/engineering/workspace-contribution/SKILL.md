---
name: workspace-contribution
version: v1
maturity: alpha
owner: "[OWNER_NAME]"
category: engineering
related_skills: [grv-glosario, grv-arquitectura-plataforma, grv-bugs-conocidos, grv-best-practices]
related_agents: [grv-domain-expert, grv-reviewer, grv-migration-guard, grv-process-analyst]
triggers:
  - "un skill detectó un hueco de información y el usuario lo llenó"
  - "usuario dice 'capturá esto como propuesta' o 'agregalo al workspace'"
  - "usuario dice 'armá las contribuciones pendientes'"
  - "usuario quiere proponer una mejora sin hacer MR manual"
---

# Skill: workspace-contribution

## Propósito

Cerrar el loop entre "Claude detecta un hueco en el workspace" y "el
workspace mejora por sí solo". Cuando un skill detecta que falta
información (un término no definido, un servicio no mapeado, un bug
nuevo, un stack no confirmado, una convención no documentada), este
skill toma la respuesta del usuario, la convierte en un cambio al
`context/` correspondiente, y lo empuja a una rama para review de
las LTs.

## Filosofía

- **Cada hueco detectado es una oportunidad de mejora.** Si el workspace
  no sabe algo que el equipo sí, esa brecha tiene que cerrarse o el
  workspace se vuelve menos útil con el tiempo.
- **La contribución es opt-in**, no automática. El usuario decide cada
  vez si quiere capturar o no. Muchos huecos son demasiado chicos para
  ameritar un MR; otros son oro.
- **Las LTs tienen la última palabra.** El skill no mergea nada. Solo
  propone via rama `contrib/*`.
- **El flujo de trabajo del usuario no se corta.** La pregunta es breve
  y si el usuario elige "esperar", la sugerencia queda en un buffer
  local para capturar más tarde.

## Scope del skill

### ✅ Puede capturar

- **Definiciones** → agrega/completa entries en `context/glossary.yaml`
- **Mapeo de servicios/MFEs** → reemplaza placeholders en `context/microservices.yaml`
- **Convenciones del equipo** → agrega a `skills/engineering/grv-best-practices/SKILL.md`
- **Referencias regulatorias** → agrega a `context/regulations.yaml`
- **Bugs nuevos** → agrega a `context/known-bugs.yaml`
- **Integraciones** → completa o agrega en `context/integrations.yaml`

### ❌ NO puede capturar (requieren MR manual)

- Cambios al texto o estructura de `SKILL.md` existentes
- Modificaciones a hooks (`.claude/hooks/*.sh`)
- Cambios a `.claude/settings.json` o `.claude/mcp.json`
- Skills nuevos completos
- Agentes nuevos
- Cambios a `CLAUDE.md` o `GOVERNANCE.md`

Si el usuario pide algo fuera de scope, el skill lo dice y sugiere
hacer un MR manual con el flujo normal.

## Cuándo me invocan otros skills

Los skills de dominio e ingeniería incluyen al final de su flujo una
invocación opcional a `workspace-contribution` cuando detectan un hueco
que el usuario acaba de llenar. Ver el helper en
`skills/engineering/workspace-contribution/helper.md` para el patrón
exacto de invocación.

## Flujo principal (single-shot)

### Paso 1 — Detectar que hay algo que capturar

Algún skill detectó un hueco (ej: `grv-glosario` no conoce ROAM) y el
usuario aportó la respuesta. El skill invocante pasa a
`workspace-contribution` los siguientes datos:

- **Tipo** de contribución: `glossary` | `microservices` | `best-practices` | `regulations` | `known-bugs` | `integrations`
- **Descripción breve**: qué se está agregando
- **Contenido propuesto**: el YAML o markdown que se va a insertar
- **Archivo destino**: path relativo al workspace
- **Contexto**: de qué conversación salió (opcional, para el mensaje de commit)

### Paso 2 — Preguntar al usuario

Ofrecer 3 opciones:

```
Gracias. Esto es valioso para el resto del equipo, ¿querés que lo
capturemos como propuesta de mejora al workspace?

  Sí          → crea rama, commit, deja todo listo para push
  Esperar     → guarda en buffer local, capturás varias juntas después
  No          → no lo captura, seguimos con lo que estábamos
```

### Paso 3 — Si dice "sí"

1. **Obtener el nombre del usuario** desde `git config user.name`.
   Si no existe o está vacío: preguntar una vez y sugerir al usuario
   que configure su git (`git config user.name "..."`). Mientras tanto,
   usar la respuesta solo para esta sesión.

2. **Construir el slug** para la rama:
   - `contrib/<nombre-normalizado>/<slug-corto>`
   - Ej: `contrib/vanesa-yanina/define-roam`
   - Si ya existe una rama con ese nombre, agregarle sufijo: `-2`, `-3`.

3. **Validaciones previas** (todas obligatorias):
   - **YAML válido**: el archivo destino sigue siendo parseable tras el cambio propuesto.
   - **Sin secretos**: escanear el contenido propuesto con los mismos patrones que `pre-commit-secrets.sh`.
   - **Sin PII**: escanear el contenido propuesto con heurística de PII (DNI, patrones de nombres completos, emails personales no corporativos, direcciones, fechas de nacimiento). Si detecta, **frenar y preguntar al usuario si quiere ofuscar**.
   - **Rama base actualizada**: `git fetch` silencioso; si `main` local está atrás del remoto, avisar y ofrecer actualizar antes.
   - **No pisa cambios**: el archivo destino no tiene modificaciones locales no committeadas que puedan perderse.

4. **Ejecutar las operaciones git**:
   ```bash
   # Desde el estado actual:
   git checkout -b contrib/<nombre>/<slug>
   # Modificar el archivo destino (insertar el contenido propuesto)
   git add <archivo>
   git commit -m "<mensaje generado>"
   # Push solo si GRV_WORKSPACE_AUTO_PUSH=true en .env
   # Si no: dejar commit local y mostrar comando
   ```

5. **Mensaje de commit**: formato convencional
   ```
   docs(<area>): <descripción breve>

   Propuesta de contribución al workspace, capturada desde una sesión
   con Claude. Revisar antes de mergear a main.

   Contexto: <contexto de la conversación si lo hay>
   Autor: <git user.name>
   ```

6. **Mostrar resultado** al usuario con el diff aplicado y el siguiente
   paso (push manual o instrucciones si el push ya fue automático).

### Paso 4 — Si dice "esperar"

1. Agregar la sugerencia a `.claude/pending-contributions.yaml` (crear
   el archivo si no existe, está en `.gitignore`).
2. Confirmar al usuario: "guardado. Tenés N sugerencias pendientes.
   Cuando quieras, decime 'armá las contribuciones pendientes' y las
   paso a una rama."
3. Seguir con la tarea original sin más interrupciones.

### Paso 5 — Si dice "no"

No captura nada, sigue con la tarea original. No insistir.

## Flujo alternativo (contribuciones pendientes desde buffer)

Se dispara cuando el usuario dice "armá las contribuciones pendientes"
o equivalente.

1. Leer `.claude/pending-contributions.yaml`.
2. Mostrar la lista numerada al usuario.
3. Preguntar: "¿las paso todas a una sola rama o una por tema?"
4. Según la respuesta:
   - **Una sola rama**: `contrib/<nombre>/pending-<fecha>` con un
     commit por sugerencia.
   - **Una por tema**: loop sobre cada sugerencia creando su propia rama.
5. Ejecutar las validaciones previas para cada una (omitir las que fallen
   y reportarlas al final).
6. Limpiar el buffer cuando termine (o mover las fallidas a un archivo
   de "rechazadas").

## Formato del archivo de buffer

```yaml
# .claude/pending-contributions.yaml
# Buffer local de contribuciones al workspace que el usuario eligió
# "esperar". No se commitea (está en .gitignore).

contributions:
  - id: 2026-04-10-001
    type: glossary
    file: context/glossary.yaml
    description: "Definir ROAM con la definición real del equipo"
    proposed_content: |
      ROAM:
        definition: >
          <definición>
        ...
    captured_at: 2026-04-10T15:32:00-03:00
    context: "Sesión de review de grv-siniestros"

  - id: 2026-04-10-002
    type: microservices
    file: context/microservices.yaml
    description: "Reemplazar [FRONTEND_NAME_MESADECARGA] por el nombre real"
    proposed_content: |
      ...
    captured_at: 2026-04-10T16:10:00-03:00
    context: "..."
```

## Validaciones detalladas

### YAML válido

Antes de commitear, el skill parsea el archivo destino modificado y se
asegura de que siga siendo YAML válido. Si falla, avisa al usuario y no
commitea.

### Sin secretos

Mismos patrones que `.claude/hooks/pre-commit-secrets.sh`:

- `password\s*=`, `passwd\s*=`
- `api[_-]?key\s*[:=]`, `secret\s*[:=]`, `token\s*[:=]`
- `AKIA[0-9A-Z]{16}` (AWS)
- `BEGIN (RSA|DSA|EC|OPENSSH) PRIVATE KEY`

Si detecta, **frena** y pide al usuario reformular sin el secreto.

### Sin PII

Heurística conservadora:

- DNI argentino: patrones `\d{1,2}[.]\d{3}[.]\d{3}` y `\d{7,8}` cuando
  aparece cerca de palabras como "DNI", "documento", "trabajador".
- Nombres completos: `[A-Z][a-z]+ [A-Z][a-z]+` cerca de palabras como
  "trabajador", "denunciante", "paciente".
- Emails personales: cualquier email con dominio que no sea corporativo
  conocido.
- Direcciones: patrones de calle + número cerca de palabras como
  "domicilio", "dirección".
- Fechas de nacimiento: fechas cerca de "nacimiento", "fecha nac", "DOB".

Cuando detecta algo sospechoso:

```
Detecté lo que parece ser datos personales en el contenido propuesto:
  - "<fragmento>"

¿Es un ejemplo real? Si sí, conviene ofuscarlo antes de commitear
(usá placeholders tipo "[NOMBRE]", "[DNI]", etc). Si es un falso
positivo, decímelo y seguimos.
```

Importante: esta heurística es **conservadora a propósito**. Es mejor
un falso positivo que un leak.

### Rama base actualizada

```bash
git fetch origin main --quiet
if [[ commits-detras > 0 ]]; then
  warning "main local está N commits atrás del remoto"
  ask "¿querés que actualice main antes de crear la rama?"
fi
```

### Sin cambios locales pisados

```bash
if [[ el archivo destino tiene cambios no committeados ]]; then
  warning "El archivo <destino> tiene cambios locales sin commitear"
  ask "¿querés stash-earlos primero, abortar, o incluirlos en la contribución?"
fi
```

## Obtención del nombre de usuario

```bash
git config user.name
```

Si el resultado está vacío:

```
No encontré tu nombre en git config. Dos opciones:

  1. Configurarlo ahora (recomendado, solo una vez):
     git config --global user.name "Tu Nombre"

  2. Decímelo ahora y lo uso solo para esta sesión.
```

Si el usuario elige opción 2, no persistir el nombre en ningún lado —
preguntar de nuevo la próxima sesión si sigue sin estar configurado.

Normalización del nombre para la rama:
- Lowercase.
- Espacios → `-`.
- Acentos fuera.
- Caracteres no alfanuméricos fuera.
- Ejemplo: `"Vanesa Yanina"` → `vanesa-yanina`.

## Auto-push

Por default: **commit local**, sin push. El usuario empuja cuando quiere.

Si `GRV_WORKSPACE_AUTO_PUSH=true` está en `.env`: el skill hace
`git push origin <rama>` después del commit y muestra el link al MR
(si la URL de GitLab está configurada en `GITLAB_URL`).

## Output

### Caso 1 — Contribución capturada exitosamente (commit local)

```
✅ Contribución capturada

  Rama creada: contrib/vanesa-yanina/define-roam
  Archivo modificado: context/glossary.yaml
  Commit: docs(glossary): add ROAM definition

  Diff aplicado:
    --- a/context/glossary.yaml
    +++ b/context/glossary.yaml
    @@ -XX,X +XX,X @@
    -  ROAM:
    -    definition: >
    -      [PENDIENTE DE VALIDAR ...]
    -    status: pending
    +  ROAM:
    +    definition: >
    +      <definición nueva>

  Próximos pasos:
    git push -u origin contrib/vanesa-yanina/define-roam

  Después, crear MR en GitLab con:
    - Título: [workspace-suggestion] define ROAM
    - Label: workspace-contribution
    - Asignar a: [OWNER_NAME] o [COMAINTAINER_NAME]
```

### Caso 2 — Contribución capturada con auto-push habilitado

```
✅ Contribución capturada y pusheada

  Rama: contrib/vanesa-yanina/define-roam
  Commit: abc1234 docs(glossary): add ROAM definition
  Push: ok

  Creá el MR en: <GITLAB_URL>/-/merge_requests/new?source_branch=contrib/vanesa-yanina/define-roam
  Label sugerido: workspace-contribution
```

### Caso 3 — Guardada en buffer

```
📥 Guardada en el buffer de contribuciones pendientes.

  Total pendientes: 3
  Ver: .claude/pending-contributions.yaml

  Cuando quieras procesarlas: "armá las contribuciones pendientes"
```

### Caso 4 — Validación falló

```
⚠️  No puedo capturar esta contribución todavía:

  Motivo: Detecté lo que parece un DNI en el contenido ("12.345.678"
  cerca de la palabra "trabajador").

  ¿Es un ejemplo real? Si sí, ofuscalo con [DNI] y probamos de nuevo.
```

## Ejemplo completo

**Contexto previo**: El usuario estuvo trabajando con `grv-domain-expert`
sobre una duda y le contó qué significa ROAM en GRV.

**Claude (grv-domain-expert)**: [usa el helper y pasa a workspace-contribution]

**Claude (workspace-contribution)**:
```
Gracias por la definición de ROAM. Es valioso para el resto del equipo.

¿Querés que lo capturemos como propuesta de mejora al workspace?

  Sí          → crea rama contrib/vanesa-yanina/define-roam con el cambio
                 listo para push
  Esperar     → lo guardo en buffer, capturás varias juntas después
  No          → seguimos sin capturarlo
```

**Usuario**: Sí

**Claude**:
```
Validando antes de commitear...
  ✅ YAML válido tras el cambio
  ✅ Sin secretos detectados
  ✅ Sin PII detectada
  ✅ main local al día con origin/main
  ✅ context/glossary.yaml sin cambios locales no committeados

Ejecutando:
  git checkout -b contrib/vanesa-yanina/define-roam
  [edito context/glossary.yaml]
  git add context/glossary.yaml
  git commit -m "docs(glossary): add ROAM definition"

✅ Contribución capturada

  Rama: contrib/vanesa-yanina/define-roam
  Commit local creado (auto-push desactivado).

  Para pushear cuando quieras:
    git push -u origin contrib/vanesa-yanina/define-roam

  Después, crear MR con:
    - Título: [workspace-suggestion] define ROAM
    - Label: workspace-contribution
    - Asignar a: [OWNER_NAME]

¿Seguimos con lo que estábamos haciendo?
```

## Límites

- **Alpha**: el skill es nuevo y depende de varias partes que pueden
  fallar (git config, estado del repo, detección heurística). Usar con
  supervisión las primeras veces.
- No valida que la contribución sea *correcta* a nivel de contenido —
  solo valida que sea segura de commitear. La validación semántica es
  del LT en el review.
- No crea el MR en GitLab automáticamente (solo la rama y el commit).
  Crear MRs requiere integración con GitLab MCP, que es TODO del workspace.
- La heurística de PII es conservadora pero no infalible. Los humanos
  siguen siendo el último filtro.

## TODO para promover a beta

- [ ] Integración con GitLab MCP para crear el MR automáticamente.
- [ ] Métricas: cuántas contribuciones se capturaron, cuántas se mergearon.
- [ ] Primer case study documentado de un ROAM real o equivalente.
- [ ] Plantillas de commit por tipo (más específicas que "docs(area)").
