CREATE INDEX IF NOT EXISTS idx_estudiantes_nombre
ON academico_mvp.estudiantes (apellidos, nombres);

CREATE INDEX IF NOT EXISTS idx_asignaturas_nombre
ON academico_mvp.asignaturas (nombre);

CREATE INDEX IF NOT EXISTS idx_calificaciones_fecha
ON academico_mvp.calificaciones (registrada_en);
