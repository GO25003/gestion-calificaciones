EXPLAIN (ANALYZE, BUFFERS)
SELECT estudiante_id, nombres, apellidos
FROM academico_mvp.estudiantes
WHERE apellidos = 'Perez Lopez';

EXPLAIN (ANALYZE, BUFFERS)
SELECT asignatura_id, codigo, nombre
FROM academico_mvp.asignaturas
WHERE nombre = 'Matematica II';

EXPLAIN (ANALYZE, BUFFERS)
SELECT calificacion_id, matricula_id, puntaje_obtenido
FROM academico_mvp.calificaciones
WHERE registrada_en >= '2026-01-01'
AND registrada_en < '2027-01-01';
