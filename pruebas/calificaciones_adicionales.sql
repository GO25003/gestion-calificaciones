BEGIN;

SET LOCAL search_path TO academico_mvp, public;

WITH notas(carnet, parcial, final) AS (
    VALUES
    ('AL202603', 9.0, 8.0),
    ('CM202604', 6.0, 7.0),
    ('DV202607', 5.0, 4.0),
    ('ER202611', 8.0, 9.0),
    ('FH202613', 7.0, 7.0),
    ('JM202606', 4.0, 5.0),
    ('KF202610', 9.0, 9.0),
    ('LG202608', 6.0, 5.0),
    ('MR202609', 8.0, 7.0),
    ('NP202612', 10.0, 9.0)
),
calificaciones_nuevas AS (
    SELECT
        m.matricula_id,
        1::bigint AS evaluacion_id,
        n.parcial AS nota
    FROM notas n
    JOIN estudiantes e ON e.carnet = n.carnet
    JOIN matriculas m ON m.estudiante_id = e.estudiante_id

    UNION ALL

    SELECT
        m.matricula_id,
        2::bigint AS evaluacion_id,
        n.final AS nota
    FROM notas n
    JOIN estudiantes e ON e.carnet = n.carnet
    JOIN matriculas m ON m.estudiante_id = e.estudiante_id
),
pendientes AS (
    SELECT
        cn.*,
        ROW_NUMBER() OVER (
            ORDER BY cn.matricula_id, cn.evaluacion_id
        ) AS numero
    FROM calificaciones_nuevas cn
    WHERE NOT EXISTS (
        SELECT 1
        FROM calificaciones c
        WHERE c.matricula_id = cn.matricula_id
        AND c.evaluacion_id = cn.evaluacion_id
    )
)
INSERT INTO calificaciones
(evaluacion_id, matricula_id, puntaje_obtenido)
SELECT
    evaluacion_id,
    matricula_id,
    nota
FROM pendientes;

COMMIT;
