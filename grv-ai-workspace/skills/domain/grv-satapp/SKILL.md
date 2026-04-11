---
name: grv-satapp
version: v1
maturity: alpha
owner: "[INTEGRATIONS_REFERENT]"
category: domain
related_skills: [grv-siniestros, grv-regulaciones-srt]
related_agents: [grv-domain-expert]
triggers:
  - "usuario menciona Satapp"
  - "usuario pregunta por MuleSoft en el contexto de GRV"
  - "usuario debe integrar, debugear o modificar el flujo de archivos con Satapp"
---

# Skill: grv-satapp

## Propósito

Conocer la integración con Satapp, una plataforma externa de intercambio
de archivos AT/EP. Este skill es el placeholder con el conocimiento actual;
pendiente de expandir.

## Fuente de verdad

`context/integrations.yaml` → entry `Satapp`.

## Qué sabemos hoy

- Satapp es una plataforma externa.
- La integración es bidireccional.
- Intercambio basado en archivos (formatos AT/EP).
- Existe un orquestador **MuleSoft** intermediando el flujo.
- Consumer conocido del lado de la plataforma GRV: `wssiniestralidad`.

## Qué NO sabemos todavía

- Responsabilidad exacta de MuleSoft (formatos, transformaciones, retries).
- Frecuencia del intercambio.
- Manejo de errores (¿rebote de archivos? ¿reintentos?).
- Referente del lado del equipo.
- Historial de incidentes.

## Cuándo usarme

- Alguien pregunta "¿qué es Satapp?" o "¿cómo funciona el flujo con MuleSoft?".
- Alguien reporta un problema con archivos que van/vienen de Satapp.
- Diseño de cambios que involucran esa integración.

## Flujo

1. Reconocer el alcance de la pregunta.
2. Responder con el conocimiento documentado.
3. **Si el usuario necesita más detalle**: decir que el skill está en alpha
   y pedir la info que falte. No inventar nombres de pipes, formatos exactos
   o endpoints.
4. Delegar a `grv-regulaciones-srt` para las reglas de formato AT/EP.

## Ofrecer captura como contribución

Cuando el usuario aporta detalles sobre Satapp o sobre el rol de MuleSoft
que no tenemos documentados, al cierre del flujo ofrecer invocar
`workspace-contribution` con `type: integrations`. Ver
`skills/engineering/workspace-contribution/helper.md`.

## Límites

Este skill sabe que sabe poco. Prefiere admitirlo a inventar.

## Promoción a beta — TODO

- [ ] Documentar el rol exacto de MuleSoft
- [ ] Documentar el formato de archivos intercambiados
- [ ] Documentar manejo de errores y retries
- [ ] Listar al menos 2 casos reales
