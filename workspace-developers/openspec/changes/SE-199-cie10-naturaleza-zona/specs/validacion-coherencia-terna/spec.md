## ADDED Requirements

> ## ⚠️ NO IMPLEMENTADO — capability pendiente
>
> Al 31/08/2026 **nada de lo que sigue está construido**. La fase 6 del `tasks.md` —el indicador de coherencia previo a la presentación a la SRT— quedó **diferida** (`design.md` D-19), y esta spec describe **comportamiento deseado**, no el sistema actual.
>
> Se conserva porque D-7 sigue vigente y el indicador no depende del catálogo ni de las pantallas de carga: puede construirse y desplegarse después sin rehacer nada de lo ya entregado.
>
> Lo que **sí** está implementado de este change vive en las otras dos capabilities: `relacion-cie10-naturaleza-zona` y `autocompletado-terna-diagnostico`.

### Requirement: Se muestra la terna cargada antes de presentar a la SRT

Antes de generar el archivo de presentación, el sistema SHALL mostrar la **terna completa** de la denuncia — diagnóstico CIE-10, naturaleza de la lesión y zona corporal — junto a un **indicador de coherencia** entre los tres campos.

El propósito es que la persona vea los tres datos juntos y con qué grado de coherencia van a viajar. No es un dictamen sobre lo que hará la SRT.

#### Scenario: Terna coherente

- **WHEN** se revisa una denuncia cuya combinación no dispara ninguna regla de coherencia conocida
- **THEN** se muestran los tres valores y el indicador señala que la terna es coherente

#### Scenario: Terna con posible inconsistencia

- **WHEN** la combinación coincide con alguna de las reglas de coherencia conocidas
- **THEN** se muestran los tres valores, el indicador señala la inconsistencia, y se indica **cuál de los tres campos** entra en conflicto con cuál

### Requirement: El indicador NO es bloqueante

El indicador de coherencia NO SHALL impedir la presentación, ni exigir corrección, ni requerir confirmación adicional para continuar.

Una terna señalada como inconsistente SHALL poder presentarse exactamente igual que una coherente.

#### Scenario: Se presenta una denuncia con inconsistencia señalada

- **WHEN** la terna tiene una inconsistencia señalada y la persona decide presentarla igual
- **THEN** la presentación se genera con normalidad, sin pasos extra

#### Scenario: El indicador no altera el archivo

- **WHEN** se genera el archivo para la SRT
- **THEN** su contenido es el mismo con o sin señalamiento: el indicador es informativo y no modifica lo que se envía

### Requirement: Las reglas de coherencia se derivan del catálogo de errores de la SRT

El indicador SHALL evaluar la terna contra las reglas que la SRT ya publica en su catálogo de errores:

| Código SRT | Qué relaciona |
|---|---|
| `L1` | zona corporal ↔ diagnóstico de AT |
| `L2` | naturaleza de la lesión ↔ diagnóstico |
| `L3` | zona corporal ↔ naturaleza de la lesión |
| `L5` | zona corporal ↔ diagnóstico de EP |
| `GK`, `FA` | zona corporal ↔ diagnóstico |
| `JI`, `GJ`, `L4` | naturaleza de la lesión ↔ diagnóstico |

El sistema NO SHALL presentar el resultado como una predicción del veredicto de la SRT. Estas reglas son las conocidas, no necesariamente todas las que aplica el organismo.

#### Scenario: Ausencia de señalamiento no garantiza aceptación

- **WHEN** una terna no dispara ninguna regla conocida
- **THEN** el indicador la muestra como coherente, sin afirmar que la SRT la vaya a aceptar

### Requirement: Las denuncias con patología trazadora se señalan como caso estructural

Cuando la denuncia tiene una patología trazadora, el indicador SHALL distinguir el caso: la inconsistencia entre el diagnóstico y la terna clínica es **esperable y no corregible**, porque ahí el CIE-10 es una etiqueta administrativa del listado ROAM y no un diagnóstico clínico.

El sistema NO SHALL sugerir corregir naturaleza o zona en estas denuncias.

#### Scenario: Trazadora con inconsistencia inevitable

- **WHEN** la denuncia tiene patología trazadora y la terna dispara una regla de coherencia
- **THEN** el indicador lo señala como caso estructural y aclara que no requiere corrección

> Medición de referencia: de las denuncias con inconsistencia, las de trazadoras son el 5,2% en `GJ`, el 9,0% en `FA`, el 11,3% en `JI` y el 0% en `GK` — alrededor del 6% del total. El 94% restante sí es corregible.

### Requirement: El indicador es de solo lectura

El indicador NO SHALL modificar los datos de la denuncia ni corregir automáticamente la terna.

#### Scenario: Señala sin corregir

- **WHEN** se detecta una inconsistencia corregible
- **THEN** se informa para que una persona decida, y no se altera ningún campo
