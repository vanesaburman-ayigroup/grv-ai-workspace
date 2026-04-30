package com.grv.wsservicio.test;

import java.time.LocalDate;

/**
 * Object Mother / Builder pattern para datos de test.
 * Uso: SiniestroMother.unSiniestroValido().conEstado("CERRADO").build()
 *
 * Este template es para copiar y adaptar en cada módulo.
 * Ver: skills/engineering/unit-test-author/SKILL.md
 */
public class SiniestroMother {

    // --- Factories estáticas con nombres descriptivos ---

    public static Builder unSiniestroValido() {
        return new Builder()
            .id(1L)
            .nroSiniestro("2024/00001")
            .estado("ACTIVO")
            .fechaAccidente(LocalDate.of(2024, 1, 15))
            .tipoSiniestro("AT")
            .afiliadoId(100L);
    }

    public static Builder unSiniestroEnILT() {
        return unSiniestroValido()
            .estado("ILT")
            .fechaAlta(null);
    }

    public static Builder unSiniestroConAltaMedica() {
        return unSiniestroValido()
            .estado("CERRADO")
            .fechaAlta(LocalDate.of(2024, 2, 10));
    }

    public static Builder unSiniestroSinAfiliadoAsignado() {
        return unSiniestroValido()
            .afiliadoId(null);
    }

    // --- Builder ---

    public static class Builder {
        private Long id = 1L;
        private String nroSiniestro = "2024/00001";
        private String estado = "ACTIVO";
        private LocalDate fechaAccidente = LocalDate.now().minusDays(10);
        private LocalDate fechaAlta = null;
        private String tipoSiniestro = "AT";
        private Long afiliadoId = 100L;

        public Builder id(Long id) {
            this.id = id;
            return this;
        }

        public Builder nroSiniestro(String nroSiniestro) {
            this.nroSiniestro = nroSiniestro;
            return this;
        }

        public Builder estado(String estado) {
            this.estado = estado;
            return this;
        }

        public Builder conEstado(String estado) {
            return estado(estado);
        }

        public Builder fechaAccidente(LocalDate fechaAccidente) {
            this.fechaAccidente = fechaAccidente;
            return this;
        }

        public Builder conFechaAccidente(LocalDate fechaAccidente) {
            return fechaAccidente(fechaAccidente);
        }

        public Builder fechaAlta(LocalDate fechaAlta) {
            this.fechaAlta = fechaAlta;
            return this;
        }

        public Builder tipoSiniestro(String tipoSiniestro) {
            this.tipoSiniestro = tipoSiniestro;
            return this;
        }

        public Builder afiliadoId(Long afiliadoId) {
            this.afiliadoId = afiliadoId;
            return this;
        }

        public Siniestro build() {
            var siniestro = new Siniestro();
            siniestro.setId(id);
            siniestro.setNroSiniestro(nroSiniestro);
            siniestro.setEstado(estado);
            siniestro.setFechaAccidente(fechaAccidente);
            siniestro.setFechaAlta(fechaAlta);
            siniestro.setTipoSiniestro(tipoSiniestro);
            siniestro.setAfiliadoId(afiliadoId);
            return siniestro;
        }
    }
}
