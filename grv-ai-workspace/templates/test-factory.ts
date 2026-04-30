/**
 * Factory de datos de test con @faker-js/faker para el workspace GRV.
 * Uso: createSiniestro({ estado: 'CERRADO' })
 *
 * Instalar: npm install --save-dev @faker-js/faker
 * Ver: skills/engineering/unit-test-author/SKILL.md
 */

import { faker } from '@faker-js/faker/locale/es';

// Para tests reproducibles, fijar la semilla en el archivo de test:
// faker.seed(12345);

// =========================================================
// TIPOS — reemplazar con los tipos reales del proyecto
// =========================================================

interface Siniestro {
  id: number;
  nroSiniestro: string;
  estado: 'ACTIVO' | 'CERRADO' | 'PENDIENTE' | 'ILT';
  fechaAccidente: string;      // ISO date: "2024-01-15"
  fechaAlta: string | null;
  tipoSiniestro: 'AT' | 'EP' | 'IN_ITINERE';
  afiliadoId: number;
}

interface Prestacion {
  id: number;
  siniestroId: number;
  tipo: string;
  estado: 'PENDIENTE' | 'APROBADA' | 'RECHAZADA';
  monto: number;
}

// =========================================================
// FACTORIES
// =========================================================

export function createSiniestro(overrides: Partial<Siniestro> = {}): Siniestro {
  const fechaAccidente = faker.date.past({ years: 2 });
  const estado = overrides.estado ?? faker.helpers.arrayElement<Siniestro['estado']>(['ACTIVO', 'CERRADO', 'PENDIENTE', 'ILT']);

  return {
    id: faker.number.int({ min: 1, max: 999999 }),
    nroSiniestro: `${faker.date.past().getFullYear()}/${faker.string.numeric(5)}`,
    estado,
    fechaAccidente: fechaAccidente.toISOString().split('T')[0],
    fechaAlta: estado === 'CERRADO' ? faker.date.future({ refDate: fechaAccidente }).toISOString().split('T')[0] : null,
    tipoSiniestro: faker.helpers.arrayElement<Siniestro['tipoSiniestro']>(['AT', 'EP', 'IN_ITINERE']),
    afiliadoId: faker.number.int({ min: 1, max: 99999 }),
    ...overrides,
  };
}

export function createSiniestroList(count: number, overrides: Partial<Siniestro> = {}): Siniestro[] {
  return Array.from({ length: count }, () => createSiniestro(overrides));
}

export function createPrestacion(overrides: Partial<Prestacion> = {}): Prestacion {
  return {
    id: faker.number.int({ min: 1, max: 999999 }),
    siniestroId: faker.number.int({ min: 1, max: 999999 }),
    tipo: faker.helpers.arrayElement(['MEDICA', 'QUIRURGICA', 'FARMACIA', 'KINESIO']),
    estado: faker.helpers.arrayElement<Prestacion['estado']>(['PENDIENTE', 'APROBADA', 'RECHAZADA']),
    monto: faker.number.float({ min: 100, max: 50000, fractionDigits: 2 }),
    ...overrides,
  };
}

export function createPrestacionList(count: number, overrides: Partial<Prestacion> = {}): Prestacion[] {
  return Array.from({ length: count }, () => createPrestacion(overrides));
}

// =========================================================
// VARIANTES NOMBRADAS (equivalente a Object Mother)
// =========================================================

export const SiniestroFixtures = {
  activo: (): Siniestro => createSiniestro({ estado: 'ACTIVO', fechaAlta: null }),
  cerrado: (): Siniestro => createSiniestro({ estado: 'CERRADO', fechaAlta: new Date().toISOString().split('T')[0] }),
  enILT: (): Siniestro => createSiniestro({ estado: 'ILT', fechaAlta: null }),
  sinAfiliado: (): Siniestro => createSiniestro({ afiliadoId: undefined as unknown as number }),
} as const;
