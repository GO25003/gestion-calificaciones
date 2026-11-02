BEGIN;

SET LOCAL search_path TO academico_mvp, public;

INSERT INTO matriculas (estudiante_id, grupo_id)
SELECT e.estudiante_id, g.grupo_id
FROM estudiantes e
CROSS JOIN grupos g
WHERE g.codigo = 'GT01'
AND e.carnet NOT IN ('JP202601', 'ML202602')
AND NOT EXISTS (
    SELECT 1
    FROM matriculas m
    WHERE m.estudiante_id = e.estudiante_id
    AND m.grupo_id = g.grupo_id
);

COMMIT;
