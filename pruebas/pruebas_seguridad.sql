-- === ROLES Y RLS ===
SET ROLE doc_martinez;                                   -- docente 1

SELECT count(*) FROM academico_mvp.calificaciones;       -- 24
SELECT count(*) FROM academico_mvp.estudiantes;          -- 15

SELECT documento_identidad_enc FROM academico_mvp.estudiantes;  -- ERROR: permission denied

RESET ROLE;

SET ROLE doc_ramirez;                                    -- docente 2

SELECT count(*) FROM academico_mvp.calificaciones;       -- 0
SELECT count(*) FROM academico_mvp.estudiantes;          -- 1

UPDATE academico_mvp.calificaciones SET puntaje_obtenido = 10;  -- UPDATE 0 (RLS lo impide)

RESET ROLE;

SET ROLE est_jp202601;                                   -- estudiante
SELECT count(*) FROM academico_mvp.calificaciones;       -- 2
SELECT * FROM academico_mvp.calificaciones;

SELECT carnet, asignatura, nota_final, resultado
FROM academico_mvp.vw_historial_academico;               -- MAT102 7.40 APROBADA

UPDATE academico_mvp.calificaciones SET puntaje_obtenido = 10;  -- ERROR: permission denied

RESET ROLE;

-- === CIFRADO ===
-- === Esta consulta recupera y desencripta los documentos de identidad de los primeros 3 estudiantes ===
SET app.clave_cifrado = 'clave-cambiar-cifrado';

SELECT carnet, pgp_sym_decrypt(documento_identidad_enc, current_setting('app.clave_cifrado')) AS documento
FROM academico_mvp.estudiantes ORDER BY carnet LIMIT 3;

-- === PERIODO CERRADO: el docente no puede cambiar notas ===
UPDATE academico_mvp.periodos_calificacion SET estado = 'CERRADO' WHERE codigo = 'P1';

SET ROLE doc_martinez;

UPDATE academico_mvp.calificaciones SET puntaje_obtenido = 9
WHERE calificacion_id = (SELECT min(calificacion_id) FROM academico_mvp.calificaciones);  -- UPDATE 0

RESET ROLE;

UPDATE academico_mvp.periodos_calificacion SET estado = 'ABIERTO' WHERE codigo = 'P1';

-- === AUDITORIA ===
SET ROLE doc_martinez;

UPDATE academico_mvp.calificaciones SET puntaje_obtenido = 9
WHERE calificacion_id = (SELECT min(calificacion_id) FROM academico_mvp.calificaciones);

RESET ROLE;

SET ROLE auditor01;

SELECT usuario_bd, operacion, puntaje_anterior, puntaje_nuevo, fecha_hora
FROM seguridad.bitacora_calificaciones ORDER BY fecha_hora DESC LIMIT 5;

RESET ROLE;

DELETE FROM seguridad.bitacora_calificaciones;           -- ERROR: solo insercion

-- === MONITOREO Y ALERTAS ===
SELECT seguridad.fn_recolectar_metricas();               -- mide y genera alertas
SELECT metrica, valor, operador, umbral, estado FROM seguridad.vw_estado_monitoreo;

-- Forzar una alerta de tamanio bajando el umbral
UPDATE seguridad.umbrales SET valor = 1 WHERE metrica = 'tamanio_bd_mb';
SELECT seguridad.fn_recolectar_metricas();
SELECT * FROM seguridad.vw_alertas_pendientes;

-- Alerta de seguridad: un docente cambia 24 notas de golpe
SET ROLE doc_martinez;
UPDATE academico_mvp.calificaciones SET puntaje_obtenido = puntaje_obtenido;
RESET ROLE;
SELECT seguridad.fn_recolectar_metricas();
SELECT * FROM seguridad.vw_alertas_pendientes;

-- El auditor atiende una alerta
SET ROLE auditor01;
SELECT * from seguridad.vw_alertas_pendientes;
SELECT * from seguridad.vw_estado_monitoreo;
SELECT * from seguridad.vw_tamanio_tablas;

SELECT seguridad.fn_atender_alerta(1);

SELECT alerta_id, atendida, atendida_por, atendida_en 
FROM seguridad.alertas 
WHERE alerta_id = 1;

RESET ROLE;

-- Restaurar el umbral
UPDATE seguridad.umbrales SET valor = 1024 WHERE metrica = 'tamanio_bd_mb';