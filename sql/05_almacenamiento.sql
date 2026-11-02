SELECT
    current_database() AS base_datos,
    pg_size_pretty(pg_database_size(current_database())) AS tamano;

SELECT
    relname AS tabla,
    pg_size_pretty(pg_total_relation_size(relid)) AS tamano_total,
    pg_size_pretty(pg_relation_size(relid)) AS tamano_datos,
    pg_size_pretty(pg_indexes_size(relid)) AS tamano_indices
FROM pg_stat_user_tables
WHERE schemaname = 'academico_mvp'
ORDER BY pg_total_relation_size(relid) DESC;

SELECT
    relname AS tabla,
    n_live_tup AS registros_aproximados,
    n_dead_tup AS registros_eliminados
FROM pg_stat_user_tables
WHERE schemaname = 'academico_mvp'
ORDER BY relname;

VACUUM (ANALYZE) academico_mvp.estudiantes;
VACUUM (ANALYZE) academico_mvp.calificaciones;
VACUUM (ANALYZE) academico_mvp.matriculas;

SELECT
    ciclo,
    ciclo * 500 AS estudiantes,
    ciclo * 2500 AS matriculas,
    ciclo * 10000 AS calificaciones
FROM generate_series(1, 5) AS ciclo;
