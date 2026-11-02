SELECT
    e.carnet,
    e.nombres,
    e.apellidos,
    g.codigo AS grupo,
    ROUND(
        SUM(c.puntaje_obtenido * ev.ponderacion / 100),
        2
    ) AS nota_final,
    CASE
        WHEN COUNT(c.calificacion_id) = 0 THEN 'PENDIENTE'
        WHEN COUNT(c.calificacion_id) < COUNT(ev.evaluacion_id)
            THEN 'INCOMPLETO'
        WHEN SUM(c.puntaje_obtenido * ev.ponderacion / 100) >= 6
            THEN 'APROBADO'
        ELSE 'REPROBADO'
    END AS estado
FROM academico_mvp.estudiantes e
JOIN academico_mvp.matriculas m
    ON m.estudiante_id = e.estudiante_id
JOIN academico_mvp.grupos g
    ON g.grupo_id = m.grupo_id
JOIN academico_mvp.evaluaciones ev
    ON ev.grupo_id = g.grupo_id
LEFT JOIN academico_mvp.calificaciones c
    ON c.matricula_id = m.matricula_id
    AND c.evaluacion_id = ev.evaluacion_id
GROUP BY
    e.estudiante_id,
    e.carnet,
    e.nombres,
    e.apellidos,
    g.codigo
ORDER BY e.carnet;
