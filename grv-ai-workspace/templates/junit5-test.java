package com.grv.wsservicio.service;

import org.junit.jupiter.api.*;
import org.junit.jupiter.api.extension.ExtendWith;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.CsvSource;
import org.junit.jupiter.params.provider.MethodSource;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.time.LocalDate;
import java.util.List;
import java.util.Optional;
import java.util.stream.Stream;

import static org.assertj.core.api.Assertions.*;
import static org.mockito.Mockito.*;

/**
 * Template JUnit 5 + Mockito + AssertJ para el workspace GRV.
 * Reemplazar: ClaseATestear, ColaboradorRepository, método bajo test.
 * Ver: skills/engineering/unit-test-author/SKILL.md
 */
@ExtendWith(MockitoExtension.class)                          // strict stubs activados
@DisplayName("ClaseATestear")
class ClaseATestearTest {

    // --- Colaboradores mockeados ---
    @Mock
    private ColaboradorRepository colaboradorRepository;

    @Mock
    private OtroServicio otroServicio;

    // --- Unidad bajo test ---
    @InjectMocks
    private ClaseATestear service;

    // =========================================================
    // MÉTODO A: caso simple con @CsvSource
    // =========================================================

    @Nested
    @DisplayName("metodoSimple")
    class MetodoSimple {

        @ParameterizedTest(name = "input={0} → esperado={1}")
        @CsvSource({
            "2024-01-01, 0",   // caso límite: mismo día
            "2024-01-01, 1",   // caso base
            "2024-01-01, 9"    // caso normal
        })
        void calculaResultadoCorrecto(String fecha, int esperado) {
            // given
            var inputDate = LocalDate.parse(fecha);

            // when
            int resultado = service.metodoSimple(inputDate);

            // then
            assertThat(resultado).isEqualTo(esperado);
        }

        @Test
        @DisplayName("lanza excepción cuando el input es inválido")
        void lanzaExcepcion_cuando_inputInvalido() {
            assertThatThrownBy(() -> service.metodoSimple(null))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining("no puede ser nulo");
        }
    }

    // =========================================================
    // MÉTODO B: caso con colaboradores y @MethodSource
    // =========================================================

    @Nested
    @DisplayName("metodoConColaboradores")
    class MetodoConColaboradores {

        @ParameterizedTest(name = "siniestroId={0}, estado={1}")
        @MethodSource("casosDeMetodoConColaboradores")
        void procesaCorrectamente(Long siniestroId, String estado, boolean esperadoActivo) {
            // given
            var siniestro = SiniestroMother.conId(siniestroId).conEstado(estado).build();
            when(colaboradorRepository.findById(siniestroId)).thenReturn(Optional.of(siniestro));

            // when
            boolean resultado = service.metodoConColaboradores(siniestroId);

            // then
            assertThat(resultado).isEqualTo(esperadoActivo);
        }

        static Stream<Object[]> casosDeMetodoConColaboradores() {
            return Stream.of(
                new Object[]{1L, "ACTIVO", true},
                new Object[]{2L, "CERRADO", false},
                new Object[]{3L, "PENDIENTE", false}
            );
        }

        @Test
        @DisplayName("lanza excepción cuando el siniestro no existe")
        void lanzaExcepcion_cuando_siniestroNoExiste() {
            // given
            when(colaboradorRepository.findById(99L)).thenReturn(Optional.empty());

            // when / then
            assertThatThrownBy(() -> service.metodoConColaboradores(99L))
                .isInstanceOf(SiniestroNoEncontradoException.class);
        }

        @Test
        @DisplayName("propaga excepción del repositorio")
        void propagaExcepcionDelRepositorio() {
            // given
            when(colaboradorRepository.findById(any())).thenThrow(new RuntimeException("BD caída"));

            // when / then
            assertThatThrownBy(() -> service.metodoConColaboradores(1L))
                .isInstanceOf(RuntimeException.class);
        }
    }

    // =========================================================
    // OBJECT MOTHER — datos de prueba para este test
    // =========================================================

    static class SiniestroMother {

        static Builder conId(Long id) {
            return new Builder().id(id);
        }

        static Builder unSiniestroValido() {
            return new Builder()
                .id(1L)
                .conEstado("ACTIVO")
                .conFechaAccidente(LocalDate.of(2024, 1, 15));
        }

        static class Builder {
            private Long id = 1L;
            private String estado = "ACTIVO";
            private LocalDate fechaAccidente = LocalDate.now();

            Builder id(Long id)                          { this.id = id; return this; }
            Builder conEstado(String estado)             { this.estado = estado; return this; }
            Builder conFechaAccidente(LocalDate fecha)   { this.fechaAccidente = fecha; return this; }

            Siniestro build() {
                var s = new Siniestro();
                s.setId(id);
                s.setEstado(estado);
                s.setFechaAccidente(fechaAccidente);
                return s;
            }
        }
    }
}
