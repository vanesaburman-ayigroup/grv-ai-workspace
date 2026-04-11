---
name: grv-prestaciones
version: v1
maturity: alpha
owner: "[BACKEND_REFERENT]"
category: domain
related_skills: [grv-autorizaciones-medicas, grv-facturacion, grv-siniestros]
related_agents: [grv-domain-expert]
triggers:
  - "usuario menciona prestaciones, tipos de prestación"
  - "usuario pregunta qué cubre la ART"
  - "usuario diseña feature sobre prestaciones"
---

# Skill: grv-prestaciones

## Propósito

Conocer el catálogo de prestaciones que la ART brinda al trabajador siniestrado
y cómo se modelan en la plataforma. Una prestación es cualquier servicio o
bien que la ART provee como parte de la cobertura del siniestro.

## Tipos de prestaciones

### Médico-asistenciales (especie)

- **Atención médica**: consultas con médicos especialistas
- **Diagnóstico**: laboratorio, imágenes, estudios funcionales
- **Tratamiento**: cirugías, medicamentos, kinesiología
- **Rehabilitación**: física, psicológica, ocupacional
- **Prótesis y ortesis**
- **Traslados** (a/desde prestadores) — ver `grv-turnos-logistica`

### Dinerarias

- **ILT** (Incapacidad Laboral Transitoria) — pago mientras no puede trabajar
- **ILPP** (Incapacidad Laboral Permanente Parcial)
- **ILPT** (Incapacidad Laboral Permanente Total)
- **Gran invalidez**
- **Fallecimiento** (indemnización a derechohabientes)

### Preventivas

- **Exámenes médicos periódicos** (no tan frecuentes en el flujo normal)

## Relación con otros ejes

- **Autorización**: la mayoría de las prestaciones requieren autorización
  previa de la ART. Ver `grv-autorizaciones-medicas`.
- **Facturación**: toda prestación brindada se factura. Ver `grv-facturacion`.
- **ILT**: si la prestación implica que el trabajador no puede trabajar,
  genera días de ILT. Ver `grv-regulaciones-srt` → Res. 237/96.
- **Trazadoras**: ciertas prestaciones disparan trazadoras de control
  de calidad en el flujo SRT. El mecanismo exacto y las reglas específicas
  de GRV están pendientes de documentar.

## Servicios involucrados

- `wsprestaciones` (pendiente de documentar en `microservices.yaml`)
- `wsautorizaciones`
- `wsauditoriafacturacion` — valida facturación de prestaciones brindadas

## Cuándo usarme

- Diseño de features que tocan el catálogo de prestaciones.
- Preguntas sobre qué tipos de prestación existen.
- Decisiones sobre qué prestaciones están cubiertas y cuáles no.
- Análisis de impacto de un cambio regulatorio sobre prestaciones.

## Cuándo NO usarme

- Para el flujo de autorización de una prestación específica → `grv-autorizaciones-medicas`.
- Para temas de facturación → `grv-facturacion`.
- Para traslados específicamente → `grv-turnos-logistica`.

## Flujo

1. Identificar qué tipo de prestación está en juego.
2. Mapear a servicios involucrados.
3. Referenciar regulación si aplica.
4. Alertar sobre interacciones cruzadas (autorización, facturación, ILT).

## Ejemplo

**Usuario**: ¿Qué sucede cuando se brinda una sesión de kinesiología a un
paciente siniestrado?

**Respuesta**:
```
Flujo de kinesiología como prestación:

1. Solicitud: el prestador (o el trabajador) solicita la prestación.
   Tipo: prestación médico-asistencial, sub-tipo kinesiología.
   Requiere autorización previa (cantidad de sesiones, profesional).

2. Autorización: wsautorizaciones evalúa. Puede AUTORIZAR, RECHAZAR o
   OBSERVAR. Ver grv-autorizaciones-medicas para el flujo completo.

3. Ejecución: una vez autorizada, el prestador brinda la sesión. Registra
   asistencia/ausencia.

4. Traslado (si aplica): si el paciente no puede trasladarse solo, se
   programa traslado. Ver grv-turnos-logistica.

5. Facturación: la prestación brindada se incluye en la facturación del
   prestador al cierre del período. wsauditoriafacturacion valida que
   coincida con las sesiones autorizadas y realmente brindadas.

6. ILT: durante el tratamiento con kinesiología, el trabajador puede estar
   en ILT total o parcial. El cálculo sigue Res. SRT 237/96.

7. Trazadoras: dependiendo del diagnóstico inicial, puede haber trazadoras
   que se disparen al cumplirse X sesiones sin alta médica. Las reglas
   específicas de GRV sobre este punto están pendientes de documentar —
   si necesitás este detalle, validalo con el referente.
```

## Límites conocidos

- **Alpha**: el catálogo exacto de prestaciones cubiertas y sus códigos
  específicos necesitan ser documentados con el cliente.
- Los códigos nomencladores (Nomenclador Nacional, etc.) no están en este skill.
- La tabla de tarifas y sus actualizaciones no son parte de este skill —
  eso vive en `grv-facturacion`.

## TODO para promover a beta

- [ ] Documentar `wsprestaciones` en `microservices.yaml`.
- [ ] Agregar catálogo de tipos y sub-tipos con códigos.
- [ ] Documentar al menos 2 casos reales.
- [ ] Cross-link con facturación y auditoría.
