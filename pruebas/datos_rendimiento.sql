BEGIN;

SET LOCAL search_path TO academico_mvp, public;

INSERT INTO carreras (codigo, nombre, duracion_ciclos)
VALUES ('IDS', 'Ingenieria en Desarrollo de Software', 10);

INSERT INTO estudiantes (carrera_id, carnet, nombres, apellidos)
SELECT carrera_id, 'JP202601', 'Juan Carlos', 'Perez Lopez'
FROM carreras
WHERE codigo = 'IDS';

INSERT INTO docentes (codigo, nombres, apellidos)
VALUES ('DOC001', 'Carlos Alberto', 'Martinez');

INSERT INTO asignaturas (codigo, nombre, unidades_valorativas)
VALUES ('MAT102', 'Matematica II', 4);

INSERT INTO ciclos_academicos
(codigo, anio, numero_ciclo, nombre, fecha_inicio, fecha_fin, estado)
VALUES
('2026-01', 2026, 1, 'Ciclo I 2026',
 '2026-01-15', '2026-06-30', 'ABIERTO');

INSERT INTO periodos_calificacion
(ciclo_academico_id, codigo, nombre, orden, fecha_inicio, fecha_fin, estado)
SELECT ciclo_academico_id, 'P1', 'Primer periodo',
       1, '2026-01-15', '2026-06-30', 'ABIERTO'
FROM ciclos_academicos
WHERE codigo = '2026-01';

INSERT INTO grupos
(ciclo_academico_id, asignatura_id, docente_id, codigo, cupo, estado)
SELECT c.ciclo_academico_id, a.asignatura_id,
       d.docente_id, 'GT01', 30, 'ABIERTO'
FROM ciclos_academicos c
JOIN asignaturas a ON a.codigo = 'MAT102'
JOIN docentes d ON d.codigo = 'DOC001'
WHERE c.codigo = '2026-01';

INSERT INTO matriculas (estudiante_id, grupo_id)
SELECT e.estudiante_id, g.grupo_id
FROM estudiantes e
JOIN grupos g ON g.codigo = 'GT01'
WHERE e.carnet = 'JP202601';

INSERT INTO evaluaciones
(grupo_id, periodo_calificacion_id, tipo, nombre,
 fecha_evaluacion, ponderacion, puntaje_maximo, orden)
SELECT g.grupo_id, p.periodo_calificacion_id,
       'PARCIAL', 'Primer parcial',
       '2026-03-10', 40, 10, 1
FROM grupos g
JOIN periodos_calificacion p
ON p.ciclo_academico_id = g.ciclo_academico_id
WHERE g.codigo = 'GT01';

INSERT INTO evaluaciones
(grupo_id, periodo_calificacion_id, tipo, nombre,
 fecha_evaluacion, ponderacion, puntaje_maximo, orden)
SELECT g.grupo_id, p.periodo_calificacion_id,
       'FINAL', 'Examen final',
       '2026-05-20', 60, 10, 2
FROM grupos g
JOIN periodos_calificacion p
ON p.ciclo_academico_id = g.ciclo_academico_id
WHERE g.codigo = 'GT01';

INSERT INTO calificaciones
(evaluacion_id, matricula_id, puntaje_obtenido)
SELECT ev.evaluacion_id, m.matricula_id,
       CASE
           WHEN ev.orden = 1 THEN 8
           ELSE 7
       END
FROM evaluaciones ev
JOIN matriculas m ON m.grupo_id = ev.grupo_id
JOIN estudiantes e ON e.estudiante_id = m.estudiante_id
WHERE e.carnet = 'JP202601';


INSERT INTO academico_mvp.estudiantes
(carrera_id, carnet, nombres, apellidos)
SELECT carrera_id, 'ML202602', 'Maria Fernanda', 'Lopez Garcia'
FROM academico_mvp.carreras
WHERE codigo = 'IDS';

INSERT INTO academico_mvp.matriculas (estudiante_id, grupo_id)
SELECT e.estudiante_id, g.grupo_id
FROM academico_mvp.estudiantes e
JOIN academico_mvp.grupos g ON g.codigo = 'GT01'
WHERE e.carnet = 'ML202602';

INSERT INTO academico_mvp.calificaciones
(evaluacion_id, matricula_id, puntaje_obtenido)
SELECT ev.evaluacion_id, m.matricula_id,
       CASE
           WHEN ev.orden = 1 THEN 4
           ELSE 5
       END
FROM academico_mvp.evaluaciones ev
JOIN academico_mvp.matriculas m
    ON m.grupo_id = ev.grupo_id
JOIN academico_mvp.estudiantes e
    ON e.estudiante_id = m.estudiante_id
WHERE e.carnet = 'ML202602';

COMMIT;
