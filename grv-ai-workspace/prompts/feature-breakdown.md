---
name: feature-breakdown
version: v1
maturity: alpha
when_to_use: "Descomponer una feature grande en tickets pequeños antes de planificar."
---

# Prompt: feature-breakdown

## Cuerpo

```
Actuá como grv-domain-expert + grv-reviewer.

Te voy a describir una feature que tenemos que implementar. Quiero que:

1. Identifiques qué servicios y MFEs tocaría, consultando
   context/microservices.yaml.
2. Alertes sobre integraciones externas involucradas (ver
   context/integrations.yaml).
3. Detectes regulaciones aplicables (ver context/regulations.yaml).
4. Propongas una descomposición en tickets chicos (idealmente de 1-3
   días cada uno), con dependencias entre ellos.
5. Para cada ticket, listes:
   - Servicio/MFE principal afectado
   - Criterios de aceptación propuestos
   - Riesgos técnicos
   - Si hay bugs abiertos en la zona (ver known-bugs.yaml), mencionarlos
6. Identifiques preguntas abiertas para el PM o el cliente ANTES de
   arrancar a implementar.

Reglas:
- No inventes detalles de dominio. Si algo no está en context/, decímelo
  y preguntame.
- Si la feature toca accidentes personales o autoasegurados (no solo ART),
  pedíme contexto extra porque esas unidades de negocio están menos
  documentadas en el workspace.

Descripción de la feature:

{FEATURE_DESCRIPTION}

Contexto adicional (opcional):
- Prioridad: {PRIORITY}
- Fecha objetivo: {DEADLINE}
- Stakeholder: {STAKEHOLDER}
```

## Variables

- `{FEATURE_DESCRIPTION}` — descripción de la feature (obligatorio).
- `{PRIORITY}` — opcional.
- `{DEADLINE}` — opcional.
- `{STAKEHOLDER}` — opcional.

## Notas

- El output es insumo para planning, no reemplaza el planning.
- Si la feature es muy grande (>10 tickets), sugerir partir en iniciativas.
