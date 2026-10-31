/*
  SISTEMA ACADEMICO - VERSION MVP
  Motor: PostgreSQL 15+
  Total: 11 tablas

  Simplificaciones frente al modelo completo:
  - Un estudiante pertenece a una sola carrera.
  - No se administran versiones de planes de estudio.
  - Un grupo tiene un solo docente titular.
  - La matricula equivale a la inscripcion del estudiante en un grupo.
  - La escala de notas se configura directamente en cada ciclo.
  - El tipo de evaluacion se controla con un CHECK, no con otra tabla.
  - No se incluye auditoria de cambios.
*/

BEGIN;

CREATE SCHEMA IF NOT EXISTS academico_mvp;
SET search_path TO academico_mvp, public;

-- =========================================================
-- 1. CARRERAS
-- =========================================================

CREATE TABLE carreras (
    carrera_id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    codigo              VARCHAR(20)  NOT NULL UNIQUE,
    nombre              VARCHAR(150) NOT NULL UNIQUE,
    duracion_ciclos     SMALLINT     NOT NULL CHECK (duracion_ciclos > 0),
    activa              BOOLEAN      NOT NULL DEFAULT TRUE
);

-- =========================================================
-- 2. ESTUDIANTES
-- =========================================================

CREATE TABLE estudiantes (
    estudiante_id       BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    carrera_id          BIGINT       NOT NULL REFERENCES carreras(carrera_id),
    carnet              VARCHAR(30)  NOT NULL UNIQUE,
    nombres             VARCHAR(100) NOT NULL,
    apellidos           VARCHAR(100) NOT NULL,
    documento_identidad VARCHAR(30) UNIQUE,
    fecha_nacimiento    DATE,
    correo              VARCHAR(150) UNIQUE,
    telefono            VARCHAR(30),
    nivel_actual        SMALLINT     NOT NULL DEFAULT 1 CHECK (nivel_actual > 0),
    situacion_academica VARCHAR(15)  NOT NULL DEFAULT 'ACTIVO'
                        CHECK (situacion_academica IN (
                            'ACTIVO', 'INACTIVO', 'EGRESADO',
                            'GRADUADO', 'RETIRADO', 'SUSPENDIDO'
                        )),
    fecha_ingreso       DATE         NOT NULL DEFAULT CURRENT_DATE,
    creado_en           TIMESTAMPTZ  NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- =========================================================
-- 3. DOCENTES
-- =========================================================

CREATE TABLE docentes (
    docente_id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    codigo              VARCHAR(30)  NOT NULL UNIQUE,
    nombres             VARCHAR(100) NOT NULL,
    apellidos           VARCHAR(100) NOT NULL,
    documento_identidad VARCHAR(30) UNIQUE,
    correo              VARCHAR(150) UNIQUE,
    telefono            VARCHAR(30),
    especialidad        VARCHAR(150),
    activo              BOOLEAN      NOT NULL DEFAULT TRUE
);

-- =========================================================
-- 4. ASIGNATURAS
-- =========================================================

CREATE TABLE asignaturas (
    asignatura_id        BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    codigo               VARCHAR(20)  NOT NULL UNIQUE,
    nombre               VARCHAR(150) NOT NULL,
    unidades_valorativas NUMERIC(4,1) NOT NULL CHECK (unidades_valorativas > 0),
    descripcion          TEXT,
    activa               BOOLEAN      NOT NULL DEFAULT TRUE
);

-- =========================================================
-- 5. PRERREQUISITOS DE ASIGNATURAS
-- =========================================================

-- Tabla puente para permitir varios prerrequisitos por asignatura.
CREATE TABLE prerrequisitos_asignatura (
    asignatura_id          BIGINT NOT NULL REFERENCES asignaturas(asignatura_id),
    prerrequisito_id       BIGINT NOT NULL REFERENCES asignaturas(asignatura_id),
    nota_minima_requerida  NUMERIC(5,2),
    PRIMARY KEY (asignatura_id, prerrequisito_id),
    CONSTRAINT ck_prerrequisito_distinto
        CHECK (asignatura_id <> prerrequisito_id),
    CONSTRAINT ck_prerrequisito_nota
        CHECK (nota_minima_requerida IS NULL OR nota_minima_requerida >= 0)
);

-- =========================================================
-- 6. CICLOS ACADEMICOS
-- =========================================================

CREATE TABLE ciclos_academicos (
    ciclo_academico_id  BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    codigo              VARCHAR(20) NOT NULL UNIQUE,
    anio                SMALLINT    NOT NULL CHECK (anio >= 2000),
    numero_ciclo        SMALLINT    NOT NULL CHECK (numero_ciclo > 0),
    nombre              VARCHAR(80) NOT NULL,
    fecha_inicio        DATE        NOT NULL,
    fecha_fin           DATE        NOT NULL,
    nota_minima         NUMERIC(5,2) NOT NULL DEFAULT 0,
    nota_maxima         NUMERIC(5,2) NOT NULL DEFAULT 10,
    nota_aprobacion     NUMERIC(5,2) NOT NULL DEFAULT 6,
    estado              VARCHAR(15) NOT NULL DEFAULT 'PLANIFICADO'
                        CHECK (estado IN ('PLANIFICADO', 'ABIERTO', 'CERRADO', 'ANULADO')),
    CONSTRAINT uq_ciclo_anio_numero UNIQUE (anio, numero_ciclo),
    CONSTRAINT ck_ciclo_fechas CHECK (fecha_fin >= fecha_inicio),
    CONSTRAINT ck_ciclo_escala CHECK (
        nota_minima < nota_maxima
        AND nota_aprobacion BETWEEN nota_minima AND nota_maxima
    )
);

-- =========================================================
-- 7. PERIODOS DE CALIFICACION
-- =========================================================

CREATE TABLE periodos_calificacion (
    periodo_calificacion_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    ciclo_academico_id      BIGINT       NOT NULL REFERENCES ciclos_academicos(ciclo_academico_id),
    codigo                  VARCHAR(20)  NOT NULL,
    nombre                  VARCHAR(100) NOT NULL,
    orden                   SMALLINT     NOT NULL CHECK (orden > 0),
    fecha_inicio            DATE         NOT NULL,
    fecha_fin               DATE         NOT NULL,
    fecha_limite_registro   TIMESTAMPTZ,
    estado                  VARCHAR(15)  NOT NULL DEFAULT 'PLANIFICADO'
                            CHECK (estado IN ('PLANIFICADO', 'ABIERTO', 'CERRADO')),
    CONSTRAINT uq_periodo_codigo UNIQUE (ciclo_academico_id, codigo),
    CONSTRAINT uq_periodo_orden UNIQUE (ciclo_academico_id, orden),
    CONSTRAINT ck_periodo_fechas CHECK (fecha_fin >= fecha_inicio)
);

-- =========================================================
-- 8. GRUPOS
-- =========================================================

CREATE TABLE grupos (
    grupo_id            BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    ciclo_academico_id  BIGINT      NOT NULL REFERENCES ciclos_academicos(ciclo_academico_id),
    asignatura_id       BIGINT      NOT NULL REFERENCES asignaturas(asignatura_id),
    docente_id          BIGINT      NOT NULL REFERENCES docentes(docente_id),
    codigo              VARCHAR(20) NOT NULL,
    cupo                SMALLINT CHECK (cupo IS NULL OR cupo > 0),
    modalidad           VARCHAR(15) NOT NULL DEFAULT 'PRESENCIAL'
                        CHECK (modalidad IN ('PRESENCIAL', 'VIRTUAL', 'HIBRIDA')),
    aula                VARCHAR(40),
    estado              VARCHAR(15) NOT NULL DEFAULT 'PLANIFICADO'
                        CHECK (estado IN ('PLANIFICADO', 'ABIERTO', 'CERRADO', 'CANCELADO')),
    CONSTRAINT uq_grupo_ciclo_asignatura_codigo
        UNIQUE (ciclo_academico_id, asignatura_id, codigo)
);

-- =========================================================
-- 9. MATRICULAS
-- =========================================================

-- En el MVP, matricula significa inscripcion del estudiante en un grupo.
CREATE TABLE matriculas (
    matricula_id        BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    estudiante_id      BIGINT      NOT NULL REFERENCES estudiantes(estudiante_id),
    grupo_id            BIGINT      NOT NULL REFERENCES grupos(grupo_id),
    fecha_matricula     DATE        NOT NULL DEFAULT CURRENT_DATE,
    estado              VARCHAR(15) NOT NULL DEFAULT 'ACTIVA'
                        CHECK (estado IN ('ACTIVA', 'FINALIZADA', 'RETIRADA', 'ANULADA')),
    CONSTRAINT uq_matricula_estudiante_grupo UNIQUE (estudiante_id, grupo_id)
);

-- Evita inscribir al estudiante en dos grupos de la misma asignatura y ciclo.
CREATE OR REPLACE FUNCTION validar_matricula()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_ciclo_id      BIGINT;
    v_asignatura_id BIGINT;
    v_cupo          SMALLINT;
    v_inscritos     INTEGER;
BEGIN
    SELECT ciclo_academico_id, asignatura_id, cupo
      INTO v_ciclo_id, v_asignatura_id, v_cupo
      FROM grupos
     WHERE grupo_id = NEW.grupo_id
     FOR UPDATE;

    IF EXISTS (
        SELECT 1
          FROM matriculas m
          JOIN grupos g ON g.grupo_id = m.grupo_id
         WHERE m.estudiante_id = NEW.estudiante_id
           AND g.ciclo_academico_id = v_ciclo_id
           AND g.asignatura_id = v_asignatura_id
           AND m.estado NOT IN ('ANULADA', 'RETIRADA')
           AND m.matricula_id <> COALESCE(NEW.matricula_id, -1)
    ) THEN
        RAISE EXCEPTION
            'El estudiante ya esta inscrito en otro grupo de esta asignatura y ciclo';
    END IF;

    IF v_cupo IS NOT NULL AND NEW.estado NOT IN ('ANULADA', 'RETIRADA') THEN
        SELECT COUNT(*)
          INTO v_inscritos
          FROM matriculas
         WHERE grupo_id = NEW.grupo_id
           AND estado NOT IN ('ANULADA', 'RETIRADA')
           AND matricula_id <> COALESCE(NEW.matricula_id, -1);

        IF v_inscritos >= v_cupo THEN
            RAISE EXCEPTION 'El grupo ya alcanzo su cupo maximo';
        END IF;
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_validar_matricula
BEFORE INSERT OR UPDATE ON matriculas
FOR EACH ROW EXECUTE FUNCTION validar_matricula();

-- =========================================================
-- 10. EVALUACIONES
-- =========================================================

CREATE TABLE evaluaciones (
    evaluacion_id           BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    grupo_id                BIGINT       NOT NULL REFERENCES grupos(grupo_id),
    periodo_calificacion_id BIGINT       NOT NULL REFERENCES periodos_calificacion(periodo_calificacion_id),
    tipo                    VARCHAR(15)  NOT NULL
                            CHECK (tipo IN (
                                'PARCIAL', 'FINAL', 'LABORATORIO',
                                'TAREA', 'PROYECTO', 'OTRO'
                            )),
    nombre                  VARCHAR(120) NOT NULL,
    fecha_evaluacion        DATE,
    ponderacion             NUMERIC(5,2) NOT NULL
                            CHECK (ponderacion > 0 AND ponderacion <= 100),
    puntaje_maximo          NUMERIC(7,2) NOT NULL DEFAULT 10
                            CHECK (puntaje_maximo > 0),
    orden                   SMALLINT     NOT NULL CHECK (orden > 0),
    CONSTRAINT uq_evaluacion_grupo_nombre UNIQUE (grupo_id, nombre),
    CONSTRAINT uq_evaluacion_grupo_orden UNIQUE (grupo_id, orden)
);

-- Valida ciclo, fechas y que las ponderaciones del grupo no excedan el 100 %.
CREATE OR REPLACE FUNCTION validar_evaluacion()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_ciclo_grupo       BIGINT;
    v_ciclo_periodo     BIGINT;
    v_inicio_periodo    DATE;
    v_fin_periodo       DATE;
    v_ponderacion_total NUMERIC(7,2);
BEGIN
    PERFORM 1 FROM grupos WHERE grupo_id = NEW.grupo_id FOR UPDATE;

    SELECT ciclo_academico_id
      INTO v_ciclo_grupo
      FROM grupos
     WHERE grupo_id = NEW.grupo_id;

    SELECT ciclo_academico_id, fecha_inicio, fecha_fin
      INTO v_ciclo_periodo, v_inicio_periodo, v_fin_periodo
      FROM periodos_calificacion
     WHERE periodo_calificacion_id = NEW.periodo_calificacion_id;

    IF v_ciclo_grupo IS DISTINCT FROM v_ciclo_periodo THEN
        RAISE EXCEPTION 'El grupo y el periodo deben pertenecer al mismo ciclo';
    END IF;

    IF NEW.fecha_evaluacion IS NOT NULL
       AND NEW.fecha_evaluacion NOT BETWEEN v_inicio_periodo AND v_fin_periodo THEN
        RAISE EXCEPTION 'La evaluacion debe realizarse dentro de las fechas del periodo';
    END IF;

    SELECT COALESCE(SUM(ponderacion), 0)
      INTO v_ponderacion_total
      FROM evaluaciones
     WHERE grupo_id = NEW.grupo_id
       AND evaluacion_id <> COALESCE(NEW.evaluacion_id, -1);

    IF v_ponderacion_total + NEW.ponderacion > 100 THEN
        RAISE EXCEPTION 'Las ponderaciones del grupo no pueden superar el 100 por ciento';
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_validar_evaluacion
BEFORE INSERT OR UPDATE ON evaluaciones
FOR EACH ROW EXECUTE FUNCTION validar_evaluacion();

-- =========================================================
-- 11. CALIFICACIONES
-- =========================================================

CREATE TABLE calificaciones (
    calificacion_id    BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    evaluacion_id      BIGINT       NOT NULL REFERENCES evaluaciones(evaluacion_id),
    matricula_id       BIGINT       NOT NULL REFERENCES matriculas(matricula_id),
    puntaje_obtenido   NUMERIC(7,2) NOT NULL CHECK (puntaje_obtenido >= 0),
    observacion        TEXT,
    registrada_en      TIMESTAMPTZ  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    actualizada_en     TIMESTAMPTZ  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_calificacion_evaluacion_matricula
        UNIQUE (evaluacion_id, matricula_id)
);

-- Verifica que la evaluacion y la matricula pertenezcan al mismo grupo.
CREATE OR REPLACE FUNCTION validar_calificacion()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_grupo_evaluacion  BIGINT;
    v_grupo_matricula   BIGINT;
    v_puntaje_maximo    NUMERIC(7,2);
BEGIN
    SELECT grupo_id, puntaje_maximo
      INTO v_grupo_evaluacion, v_puntaje_maximo
      FROM evaluaciones
     WHERE evaluacion_id = NEW.evaluacion_id;

    SELECT grupo_id
      INTO v_grupo_matricula
      FROM matriculas
     WHERE matricula_id = NEW.matricula_id;

    IF v_grupo_evaluacion IS DISTINCT FROM v_grupo_matricula THEN
        RAISE EXCEPTION 'La evaluacion y la matricula deben pertenecer al mismo grupo';
    END IF;

    IF NEW.puntaje_obtenido > v_puntaje_maximo THEN
        RAISE EXCEPTION 'El puntaje obtenido no puede superar el puntaje maximo';
    END IF;

    NEW.actualizada_en := CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_validar_calificacion
BEFORE INSERT OR UPDATE ON calificaciones
FOR EACH ROW EXECUTE FUNCTION validar_calificacion();

-- =========================================================
-- VISTAS: PROMEDIOS, REPORTES E HISTORIAL
-- =========================================================

CREATE VIEW vw_control_ponderaciones AS
SELECT
    g.grupo_id,
    ca.codigo AS ciclo,
    a.codigo AS codigo_asignatura,
    a.nombre AS asignatura,
    g.codigo AS grupo,
    COALESCE(SUM(ev.ponderacion), 0)::NUMERIC(7,2) AS ponderacion_total,
    CASE
        WHEN COALESCE(SUM(ev.ponderacion), 0) = 100 THEN 'CORRECTA'
        ELSE 'INCOMPLETA'
    END AS estado_ponderacion
FROM grupos g
JOIN ciclos_academicos ca ON ca.ciclo_academico_id = g.ciclo_academico_id
JOIN asignaturas a ON a.asignatura_id = g.asignatura_id
LEFT JOIN evaluaciones ev ON ev.grupo_id = g.grupo_id
GROUP BY g.grupo_id, ca.codigo, a.codigo, a.nombre, g.codigo;

CREATE VIEW vw_promedios_asignatura AS
WITH resumen AS (
    SELECT
        m.matricula_id,
        e.estudiante_id,
        e.carnet,
        e.nombres,
        e.apellidos,
        c.carrera_id,
        c.codigo AS codigo_carrera,
        c.nombre AS carrera,
        ca.ciclo_academico_id,
        ca.codigo AS ciclo,
        a.asignatura_id,
        a.codigo AS codigo_asignatura,
        a.nombre AS asignatura,
        a.unidades_valorativas,
        g.codigo AS grupo,
        ca.nota_maxima,
        ca.nota_aprobacion,
        COALESCE(SUM(ev.ponderacion), 0) AS ponderacion_programada,
        COALESCE(
            SUM(ev.ponderacion) FILTER (WHERE cal.calificacion_id IS NOT NULL),
            0
        ) AS ponderacion_calificada,
        COALESCE(SUM(
            (cal.puntaje_obtenido / ev.puntaje_maximo)
            * (ev.ponderacion / 100.0)
            * ca.nota_maxima
        ), 0) AS nota_acumulada_sin_redondear
    FROM matriculas m
    JOIN estudiantes e ON e.estudiante_id = m.estudiante_id
    JOIN carreras c ON c.carrera_id = e.carrera_id
    JOIN grupos g ON g.grupo_id = m.grupo_id
    JOIN ciclos_academicos ca ON ca.ciclo_academico_id = g.ciclo_academico_id
    JOIN asignaturas a ON a.asignatura_id = g.asignatura_id
    LEFT JOIN evaluaciones ev ON ev.grupo_id = g.grupo_id
    LEFT JOIN calificaciones cal
      ON cal.evaluacion_id = ev.evaluacion_id
     AND cal.matricula_id = m.matricula_id
    WHERE m.estado <> 'ANULADA'
    GROUP BY
        m.matricula_id,
        e.estudiante_id, e.carnet, e.nombres, e.apellidos,
        c.carrera_id, c.codigo, c.nombre,
        ca.ciclo_academico_id, ca.codigo,
        a.asignatura_id, a.codigo, a.nombre, a.unidades_valorativas,
        g.codigo, ca.nota_maxima, ca.nota_aprobacion
)
SELECT
    r.matricula_id,
    r.estudiante_id,
    r.carnet,
    r.nombres,
    r.apellidos,
    r.carrera_id,
    r.codigo_carrera,
    r.carrera,
    r.ciclo_academico_id,
    r.ciclo,
    r.asignatura_id,
    r.codigo_asignatura,
    r.asignatura,
    r.unidades_valorativas,
    r.grupo,
    r.ponderacion_programada,
    r.ponderacion_calificada,
    ROUND(r.nota_acumulada_sin_redondear, 2) AS nota_acumulada,
    CASE
        WHEN r.ponderacion_programada = 100
         AND r.ponderacion_calificada = 100
        THEN ROUND(r.nota_acumulada_sin_redondear, 2)
        ELSE NULL
    END AS nota_final,
    CASE
        WHEN r.ponderacion_programada <> 100
          OR r.ponderacion_calificada <> 100 THEN 'EN_PROCESO'
        WHEN ROUND(r.nota_acumulada_sin_redondear, 2) >= r.nota_aprobacion
          THEN 'APROBADA'
        ELSE 'REPROBADA'
    END AS resultado
FROM resumen r;

CREATE VIEW vw_promedios_ciclo AS
SELECT
    p.estudiante_id,
    p.carnet,
    p.nombres,
    p.apellidos,
    p.codigo_carrera,
    p.carrera,
    p.ciclo_academico_id,
    p.ciclo,
    COUNT(*) AS asignaturas_inscritas,
    COUNT(p.nota_final) AS asignaturas_finalizadas,
    ROUND(
        SUM(p.nota_final * p.unidades_valorativas)
        / NULLIF(
            SUM(p.unidades_valorativas) FILTER (WHERE p.nota_final IS NOT NULL),
            0
        ),
        2
    ) AS promedio_ciclo
FROM vw_promedios_asignatura p
GROUP BY
    p.estudiante_id, p.carnet, p.nombres, p.apellidos,
    p.codigo_carrera, p.carrera,
    p.ciclo_academico_id, p.ciclo;

CREATE VIEW vw_historial_academico AS
SELECT
    estudiante_id,
    carnet,
    nombres,
    apellidos,
    codigo_carrera,
    carrera,
    ciclo,
    codigo_asignatura,
    asignatura,
    unidades_valorativas,
    nota_final,
    resultado
FROM vw_promedios_asignatura;

-- =========================================================
-- INDICES PARA CONSULTAS FRECUENTES
-- =========================================================

CREATE INDEX ix_estudiantes_carrera
    ON estudiantes(carrera_id);
CREATE INDEX ix_grupos_ciclo_asignatura
    ON grupos(ciclo_academico_id, asignatura_id);
CREATE INDEX ix_grupos_docente
    ON grupos(docente_id);
CREATE INDEX ix_matriculas_estudiante
    ON matriculas(estudiante_id);
CREATE INDEX ix_matriculas_grupo
    ON matriculas(grupo_id);
CREATE INDEX ix_evaluaciones_grupo
    ON evaluaciones(grupo_id);
CREATE INDEX ix_calificaciones_matricula
    ON calificaciones(matricula_id);

COMMIT;

/*
  CONSULTAS DE EJEMPLO

  -- Historial de un estudiante:
  SELECT *
  FROM academico_mvp.vw_historial_academico
  WHERE carnet = '2026-0001'
  ORDER BY ciclo, codigo_asignatura;

  -- Promedios por ciclo de un estudiante:
  SELECT *
  FROM academico_mvp.vw_promedios_ciclo
  WHERE carnet = '2026-0001'
  ORDER BY ciclo;

  -- Reporte de una asignatura en un ciclo:
  SELECT *
  FROM academico_mvp.vw_promedios_asignatura
  WHERE codigo_asignatura = 'MAT101'
    AND ciclo = '2026-01'
  ORDER BY apellidos, nombres;

  -- Promedio de cada grupo:
  SELECT ciclo, codigo_asignatura, asignatura, grupo,
         ROUND(AVG(nota_final), 2) AS promedio_grupal
  FROM academico_mvp.vw_promedios_asignatura
  WHERE nota_final IS NOT NULL
  GROUP BY ciclo, codigo_asignatura, asignatura, grupo;
*/
