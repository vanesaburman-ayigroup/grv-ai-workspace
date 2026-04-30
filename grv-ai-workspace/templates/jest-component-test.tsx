/**
 * Template Jest + React Testing Library + MSW para el workspace GRV.
 * Reemplazar: NombreComponente, endpoint, tipos.
 * Ver: skills/engineering/unit-test-author/SKILL.md
 */

import { render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { http, HttpResponse } from 'msw';
import { setupServer } from 'msw/node';
import { Provider } from 'react-redux';

import { NombreComponente } from './NombreComponente';
import { store } from '../store';
import { createSiniestro, createSiniestroList } from '../test-utils/factories';

// =========================================================
// MSW SERVER — mockear llamadas a la API
// =========================================================

const server = setupServer(
  http.get('/v1/siniestros', () => {
    return HttpResponse.json({
      content: createSiniestroList(3),
      totalElements: 3,
    });
  }),
  http.get('/v1/siniestros/:id', ({ params }) => {
    return HttpResponse.json(createSiniestro({ id: Number(params.id) }));
  })
);

beforeAll(() => server.listen({ onUnhandledRequest: 'warn' }));
afterEach(() => server.resetHandlers());
afterAll(() => server.close());

// =========================================================
// HELPERS
// =========================================================

function renderWithProviders(ui: React.ReactElement) {
  return render(<Provider store={store}>{ui}</Provider>);
}

// =========================================================
// TESTS: happy path
// =========================================================

describe('NombreComponente', () => {
  describe('renderizado inicial', () => {
    it('muestra loading mientras carga', () => {
      renderWithProviders(<NombreComponente />);
      expect(screen.getByRole('progressbar')).toBeInTheDocument();
    });

    it('muestra la lista de siniestros al cargar', async () => {
      renderWithProviders(<NombreComponente />);

      await waitFor(() => {
        expect(screen.getAllByRole('listitem')).toHaveLength(3);
      });
    });

    it('muestra mensaje de lista vacía cuando no hay siniestros', async () => {
      server.use(
        http.get('/v1/siniestros', () =>
          HttpResponse.json({ content: [], totalElements: 0 })
        )
      );

      renderWithProviders(<NombreComponente />);

      await waitFor(() => {
        expect(screen.getByText(/no hay siniestros/i)).toBeInTheDocument();
      });
    });
  });

  // =========================================================
  // TESTS: interacciones de usuario
  // =========================================================

  describe('interacciones', () => {
    it('filtra siniestros al cambiar el estado', async () => {
      const user = userEvent.setup();
      renderWithProviders(<NombreComponente />);

      await waitFor(() => screen.getAllByRole('listitem'));

      server.use(
        http.get('/v1/siniestros', ({ request }) => {
          const url = new URL(request.url);
          const estado = url.searchParams.get('estado');
          if (estado === 'CERRADO') {
            return HttpResponse.json({ content: [createSiniestro({ estado: 'CERRADO' })], totalElements: 1 });
          }
          return HttpResponse.json({ content: createSiniestroList(3), totalElements: 3 });
        })
      );

      await user.selectOptions(screen.getByRole('combobox', { name: /estado/i }), 'CERRADO');

      await waitFor(() => {
        expect(screen.getAllByRole('listitem')).toHaveLength(1);
      });
    });

    it('abre el detalle al hacer clic en un siniestro', async () => {
      const user = userEvent.setup();
      const siniestro = createSiniestro({ id: 42, estado: 'ACTIVO' });

      server.use(
        http.get('/v1/siniestros', () =>
          HttpResponse.json({ content: [siniestro], totalElements: 1 })
        )
      );

      renderWithProviders(<NombreComponente />);

      await waitFor(() => screen.getByRole('listitem'));
      await user.click(screen.getByRole('button', { name: /ver detalle/i }));

      expect(screen.getByRole('dialog')).toBeInTheDocument();
    });
  });

  // =========================================================
  // TESTS: errores de API
  // =========================================================

  describe('manejo de errores', () => {
    it('muestra mensaje de error cuando la API falla', async () => {
      server.use(
        http.get('/v1/siniestros', () => HttpResponse.error())
      );

      renderWithProviders(<NombreComponente />);

      await waitFor(() => {
        expect(screen.getByRole('alert')).toBeInTheDocument();
        expect(screen.getByText(/error al cargar/i)).toBeInTheDocument();
      });
    });
  });

  // =========================================================
  // TESTS: parametrizado con describe.each
  // =========================================================

  describe.each([
    ['ACTIVO', 'verde'],
    ['CERRADO', 'gris'],
    ['PENDIENTE', 'amarillo'],
  ])('badge de estado %s', (estado, colorEsperado) => {
    it(`muestra badge ${colorEsperado} para estado ${estado}`, async () => {
      server.use(
        http.get('/v1/siniestros', () =>
          HttpResponse.json({ content: [createSiniestro({ estado })], totalElements: 1 })
        )
      );

      renderWithProviders(<NombreComponente />);

      await waitFor(() => {
        const badge = screen.getByTestId('estado-badge');
        expect(badge).toHaveClass(colorEsperado);
      });
    });
  });
});
