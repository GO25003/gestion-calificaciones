SELECT
    e.carnet,
    e.nombres,
    e.apellidos,
    a.nombre AS materia,
    ev.nombre AS evaluacion,
    c.puntaje_obtenido AS nota
FROM academico_mvp.calificaciones c
JOIN academico_mvp.matriculas m
    ON c.matricula_id = m.matricula_id
JOIN academico_mvp.estudiantes e
    ON m.estudiante_id = e.estudiante_id
JOIN academico_mvp.evaluaciones ev
    ON c.evaluacion_id = ev.evaluacion_id
JOIN academico_mvp.grupos g
    ON m.grupo_id = g.grupo_id
JOIN academico_mvp.asignaturas a
    ON g.asignatura_id = a.asignatura_id
WHERE e.carnet = 'JP202601'
ORDER BY ev.orden;

SELECT
    carnet,
    nombres,
    apellidos,
    asignatura,
    nota_final,
    resultado
FROM academico_mvp.vw_promedios_asignatura
WHERE carnet = 'JP202601';

SELECT
    ciclo,
    asignatura,
    ROUND(AVG(nota_final), 2) AS promedio
FROM academico_mvp.vw_promedios_asignatura
WHERE nota_final IS NOT NULL
GROUP BY ciclo, asignatura
ORDER BY ciclo, asignatura;

SELECT
    carnet,
    nombres,
    apellidos,
    asignatura,
    nota_final
FROM academico_mvp.vw_promedios_asignatura
WHERE resultado = 'REPROBADA'
ORDER BY nota_final;

SELECT
    carnet,
    nombres,
    apellidos,
    ciclo,
    asignatura,
    nota_final,
    resultado
FROM academico_mvp.vw_historial_academico
WHERE carnet = 'JP202601'
ORDER BY ciclo, asignatura;
