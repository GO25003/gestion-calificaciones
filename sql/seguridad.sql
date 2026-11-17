
-- ==DATOS DE EJEMPLO ==
BEGIN;
SET LOCAL search_path TO academico_mvp, public;

INSERT INTO docentes (codigo, nombres, apellidos)
VALUES ('DOC002', 'Ana Lucia', 'Ramirez')
ON CONFLICT (codigo) DO NOTHING; -- si el registro ya existe, lo ignora

INSERT INTO asignaturas (codigo, nombre, unidades_valorativas)
VALUES ('PRG101', 'Programacion I', 4)
ON CONFLICT (codigo) DO NOTHING;

-- Grupo de Programacion I, impartido por la docente Ramirez
INSERT INTO grupos (ciclo_academico_id, asignatura_id, docente_id, codigo, cupo, estado)
SELECT c.ciclo_academico_id, a.asignatura_id, d.docente_id, 'GT01', 30, 'ABIERTO'
FROM ciclos_academicos c
JOIN asignaturas a ON a.codigo = 'PRG101'
JOIN docentes d ON d.codigo = 'DOC002'
WHERE c.codigo = '2026-01'
ON CONFLICT (ciclo_academico_id, asignatura_id, codigo) DO NOTHING;

-- Maria tambien cursa Programacion I 
INSERT INTO matriculas (estudiante_id, grupo_id)
SELECT e.estudiante_id, g.grupo_id
FROM estudiantes e
JOIN asignaturas a ON a.codigo = 'PRG101'
JOIN grupos g ON g.asignatura_id = a.asignatura_id AND g.codigo = 'GT01'
WHERE e.carnet = 'ML202602'
  AND NOT EXISTS (SELECT 1 FROM matriculas m
                  WHERE m.estudiante_id = e.estudiante_id AND m.grupo_id = g.grupo_id); -- NOT EXISTS evita matricularla dos veces

-- Una evaluacion de 100% para ese grupo
INSERT INTO evaluaciones (grupo_id, periodo_calificacion_id, tipo, nombre,
                          fecha_evaluacion, ponderacion, puntaje_maximo, orden)
SELECT g.grupo_id, p.periodo_calificacion_id, 'PARCIAL', 'Primer parcial',
       '2026-03-12', 100, 10, 1
FROM grupos g
JOIN asignaturas a ON a.asignatura_id = g.asignatura_id AND a.codigo = 'PRG101'
JOIN periodos_calificacion p ON p.ciclo_academico_id = g.ciclo_academico_id
WHERE NOT EXISTS (SELECT 1 FROM evaluaciones ev WHERE ev.grupo_id = g.grupo_id);

COMMIT;

-- ---------------------------------------------------------
-- ENDURECIMIENTO BASE 
-- Por defecto, nadie tiene ningún permiso 
-- a menos que el administrador otorgue explícitamente un permiso específico
-- ---------------------------------------------------------
-- PUBLIC = todos los usuarios. Se les quita el acceso a la base:
-- solo entra quien reciba un GRANT CONNECT explicito mas abajo
REVOKE ALL ON DATABASE ues FROM PUBLIC;

-- Nadie puede crear objetos en el schema public salvo que se le autorice
REVOKE CREATE ON SCHEMA public FROM PUBLIC;

-- Schema aparte para lo que NO es academico: bitacora, alertas, funciones de seguridad
CREATE SCHEMA IF NOT EXISTS seguridad;

-- Extension con las funciones de cifrado (pgp_sym_encrypt, hmac, etc)
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- Para escribir "estudiantes" en vez de "academico_mvp.estudiantes" (conexiones nuevas)
ALTER DATABASE ues SET search_path = academico_mvp, public;

-- ---------------------------------------------------------
-- ROLES Y USUARIOS
-- Roles de grupo (NOLOGIN) = perfiles que guardan permisos, nadie inicia sesion con ellos.
-- Usuarios (LOGIN) = personas, heredan los permisos del rol al que pertenecen.
-- ---------------------------------------------------------
DO $$
DECLARE g TEXT;
BEGIN
  FOREACH g IN ARRAY ARRAY['rol_admin_bd','rol_registro','rol_docente',
                           'rol_estudiante','rol_auditor','rol_backup'] LOOP
    -- Solo crea el rol si todavia no existe
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = g) THEN
      EXECUTE format('CREATE ROLE %I NOLOGIN', g);
    END IF;
  END LOOP;
END $$;

-- Las contraseñas se guardan con SCRAM-SHA-256
SET password_encryption = 'scram-sha-256';

DO $$
DECLARE u RECORD;
BEGIN
  FOR u IN
    SELECT * FROM (VALUES
      -- usuario,       contrasena ,  rol de grupo,    max. conexiones simultaneas
      ('admin_notas',  '#Admin2026',  'rol_admin_bd',   3),
      ('registro01',   '#Reg2026',    'rol_registro',   5),
      ('doc_martinez', '#Doc2026',    'rol_docente',    2),
      ('doc_ramirez',  '#Doc2026b',   'rol_docente',    2),
      ('auditor01',    '#Aud2026',    'rol_auditor',    2),
      ('backup_user',  '#Bkp2026',    'rol_backup',     2)
    ) AS t(nombre, clave, grupo, limite)
  LOOP
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = u.nombre) THEN
      EXECUTE format('CREATE ROLE %I LOGIN PASSWORD %L IN ROLE %I CONNECTION LIMIT %s',
                     u.nombre, u.clave, u.grupo, u.limite);
    END IF;
  END LOOP;
END $$;

-- pg_dump debe poder leer TODAS las filas. Sin BYPASSRLS, el RLS le ocultaria  (Row-Level Security)
-- filas y el respaldo saldria incompleto
ALTER ROLE backup_user BYPASSRLS;
GRANT pg_read_all_data TO rol_backup;   -- rol predefinido: lectura de todo

-- ---------------------------------------------------------
-- VINCULAR PERSONAS CON USUARIOS DE BASE DE DATOS
-- La columna usuario_bd dice "esta persona inicia sesion como este usuario"
-- El RLS la usa para saber quien es quien
-- ---------------------------------------------------------
ALTER TABLE academico_mvp.estudiantes ADD COLUMN IF NOT EXISTS usuario_bd TEXT UNIQUE;
ALTER TABLE academico_mvp.docentes    ADD COLUMN IF NOT EXISTS usuario_bd TEXT UNIQUE;

UPDATE academico_mvp.docentes SET usuario_bd = 'doc_martinez' WHERE codigo = 'DOC001';
UPDATE academico_mvp.docentes SET usuario_bd = 'doc_ramirez'  WHERE codigo = 'DOC002';

-- Crea un usuario por cada estudiante y lo enlaza.
DO $$
DECLARE r RECORD; u TEXT;
BEGIN
  FOR r IN SELECT estudiante_id, carnet FROM academico_mvp.estudiantes LOOP
    u := 'est_' || lower(r.carnet);
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = u) THEN
      EXECUTE format(
        'CREATE ROLE %I LOGIN PASSWORD %L IN ROLE rol_estudiante CONNECTION LIMIT 2',
        u, '#Est2026');
    END IF;
    UPDATE academico_mvp.estudiantes SET usuario_bd = u
     WHERE estudiante_id = r.estudiante_id;
  END LOOP;
END $$;

-- ---------------------------------------------------------
-- PROPIEDAD DE LOS OBJETOS
-- El administrador no es superusuario:
-- puede gestionar el esquema sin tener poder total sobre el servidor
-- ---------------------------------------------------------
DO $$
DECLARE r RECORD;
BEGIN
  FOR r IN SELECT tablename FROM pg_tables WHERE schemaname = 'academico_mvp' LOOP
    EXECUTE format('ALTER TABLE academico_mvp.%I OWNER TO rol_admin_bd', r.tablename);
  END LOOP;
  FOR r IN SELECT viewname FROM pg_views WHERE schemaname = 'academico_mvp' LOOP
    EXECUTE format('ALTER VIEW academico_mvp.%I OWNER TO rol_admin_bd', r.viewname);
  END LOOP;
  FOR r IN SELECT p.oid::regprocedure AS f FROM pg_proc p
           JOIN pg_namespace n ON n.oid = p.pronamespace
           WHERE n.nspname = 'academico_mvp' LOOP
    EXECUTE format('ALTER FUNCTION %s OWNER TO rol_admin_bd', r.f);
  END LOOP;
END $$;
ALTER SCHEMA academico_mvp OWNER TO rol_admin_bd;
ALTER SCHEMA seguridad     OWNER TO rol_admin_bd;

-- Los triggers de validacion hacen SELECT  FOR UPDATE sobre "grupos", y un docente
-- SET search_path fijos
ALTER FUNCTION academico_mvp.validar_matricula()    SECURITY DEFINER SET search_path = academico_mvp, pg_temp;
ALTER FUNCTION academico_mvp.validar_evaluacion()   SECURITY DEFINER SET search_path = academico_mvp, pg_temp;
ALTER FUNCTION academico_mvp.validar_calificacion() SECURITY DEFINER SET search_path = academico_mvp, pg_temp;

-- Por defecto una vista se ejecuta con permisos del dueño y salta el RLS
-- security_invoker hace que use los permisos y el RLS de quien consulta
ALTER VIEW academico_mvp.vw_control_ponderaciones SET (security_invoker = true);
ALTER VIEW academico_mvp.vw_promedios_asignatura  SET (security_invoker = true);
ALTER VIEW academico_mvp.vw_promedios_ciclo       SET (security_invoker = true);
ALTER VIEW academico_mvp.vw_historial_academico   SET (security_invoker = true);

-- ---------------------------------------------------------
-- AUDITORIA: BITACORA DE CAMBIOS EN NOTAS
-- Registra quien, cuando, desde que IP y que valor cambio
-- Se crea antes de dar privilegios para poder otorgarlos sobre ella
-- ---------------------------------------------------------
CREATE TABLE IF NOT EXISTS seguridad.bitacora_calificaciones (
  bitacora_id      BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  fecha_hora       TIMESTAMPTZ NOT NULL DEFAULT now(),
  usuario_bd       TEXT        NOT NULL,
  ip_cliente       INET        DEFAULT inet_client_addr(),   -- IP de quien se conecta
  operacion        TEXT        NOT NULL,                     -- INSERT / UPDATE / DELETE
  calificacion_id  BIGINT,
  evaluacion_id    BIGINT,
  matricula_id     BIGINT,
  puntaje_anterior NUMERIC(7,2),
  puntaje_nuevo    NUMERIC(7,2)
);
ALTER TABLE seguridad.bitacora_calificaciones OWNER TO rol_admin_bd;

CREATE OR REPLACE FUNCTION seguridad.fn_audit_calificaciones() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = seguridad, pg_temp AS $$
DECLARE
  v_usuario TEXT := COALESCE(NULLIF(current_setting('role'), 'none'), session_user::text);
BEGIN
  IF TG_OP = 'INSERT' THEN
    INSERT INTO seguridad.bitacora_calificaciones
      (usuario_bd, operacion, calificacion_id, evaluacion_id, matricula_id, puntaje_nuevo)
    VALUES (v_usuario, 'INSERT', NEW.calificacion_id, NEW.evaluacion_id,
            NEW.matricula_id, NEW.puntaje_obtenido);
  ELSIF TG_OP = 'UPDATE' THEN
    INSERT INTO seguridad.bitacora_calificaciones
      (usuario_bd, operacion, calificacion_id, evaluacion_id, matricula_id,
       puntaje_anterior, puntaje_nuevo)
    VALUES (v_usuario, 'UPDATE', NEW.calificacion_id, NEW.evaluacion_id,
            NEW.matricula_id, OLD.puntaje_obtenido, NEW.puntaje_obtenido);
  ELSE  -- DELETE
    INSERT INTO seguridad.bitacora_calificaciones
      (usuario_bd, operacion, calificacion_id, evaluacion_id, matricula_id, puntaje_anterior)
    VALUES (v_usuario, 'DELETE', OLD.calificacion_id, OLD.evaluacion_id,
            OLD.matricula_id, OLD.puntaje_obtenido);
  END IF;
  RETURN NULL;   -- en un trigger AFTER el valor de retorno se ignora
END $$;
ALTER FUNCTION seguridad.fn_audit_calificaciones() OWNER TO rol_admin_bd;

-- Se dispara despues de cada INSERT, UPDATE o DELETE sobre calificaciones
DROP TRIGGER IF EXISTS trg_audit_calificaciones ON academico_mvp.calificaciones;
CREATE TRIGGER trg_audit_calificaciones
AFTER INSERT OR UPDATE OR DELETE ON academico_mvp.calificaciones
FOR EACH ROW EXECUTE FUNCTION seguridad.fn_audit_calificaciones();

-- Bitacora inmutable: este trigger rechaza cualquier UPDATE, DELETE o TRUNCATE,
-- incluso del administrador. Solo se pueden agregar filas
CREATE OR REPLACE FUNCTION seguridad.fn_bitacora_inmutable() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN RAISE EXCEPTION 'La bitacora es de solo insercion'; END $$;
ALTER FUNCTION seguridad.fn_bitacora_inmutable() OWNER TO rol_admin_bd;

DROP TRIGGER IF EXISTS trg_bitacora_inmutable ON seguridad.bitacora_calificaciones;
CREATE TRIGGER trg_bitacora_inmutable
BEFORE UPDATE OR DELETE OR TRUNCATE ON seguridad.bitacora_calificaciones
FOR EACH STATEMENT EXECUTE FUNCTION seguridad.fn_bitacora_inmutable();

-- ---------------------------------------------------------
-- FUNCIONES AUXILIARES PARA EL RLS
-- Devuelven el id del docente o estudiante que tiene la sesion abierta
-- Son SECURITY DEFINER porque el usuario no puede leer la tabla completa
-- ---------------------------------------------------------
CREATE OR REPLACE FUNCTION seguridad.fn_docente_id() RETURNS BIGINT
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = academico_mvp, pg_temp AS
$$ 
  SELECT docente_id FROM docentes 
  WHERE usuario_bd = COALESCE(NULLIF(current_setting('role', true), 'none'), session_user::text) 
$$;

CREATE OR REPLACE FUNCTION seguridad.fn_estudiante_id() RETURNS BIGINT
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = academico_mvp, pg_temp AS
$$ 
  SELECT estudiante_id FROM estudiantes 
  WHERE usuario_bd = COALESCE(NULLIF(current_setting('role', true), 'none'), session_user::text) 
$$;

ALTER FUNCTION seguridad.fn_docente_id()    OWNER TO rol_admin_bd;
ALTER FUNCTION seguridad.fn_estudiante_id() OWNER TO rol_admin_bd;
-- Solo el rol correspondiente puede ejecutarlas
REVOKE ALL ON FUNCTION seguridad.fn_docente_id(), seguridad.fn_estudiante_id() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION seguridad.fn_docente_id()    TO rol_docente;
GRANT EXECUTE ON FUNCTION seguridad.fn_estudiante_id() TO rol_estudiante;

-- ---------------------------------------------------------
-- PRIVILEGIOS: principio de minimo privilegio
-- Cada rol recibe solo lo que necesita. El RLS filtra ademas las filas
-- ---------------------------------------------------------
GRANT CONNECT ON DATABASE ues TO rol_admin_bd, rol_registro, rol_docente,
      rol_estudiante, rol_auditor, rol_backup;
GRANT USAGE ON SCHEMA academico_mvp TO rol_admin_bd, rol_registro, rol_docente,
      rol_estudiante, rol_auditor, rol_backup;
GRANT USAGE ON SCHEMA seguridad TO rol_docente, rol_estudiante, rol_auditor;

-- REGISTRO: altas y cambios en catalogos y matriculas; solo lee notas
GRANT SELECT, INSERT, UPDATE ON
      academico_mvp.carreras, academico_mvp.estudiantes, academico_mvp.docentes,
      academico_mvp.asignaturas, academico_mvp.prerrequisitos_asignatura,
      academico_mvp.ciclos_academicos, academico_mvp.periodos_calificacion,
      academico_mvp.grupos, academico_mvp.matriculas TO rol_registro;
GRANT SELECT ON ALL TABLES IN SCHEMA academico_mvp TO rol_registro;  -- incluye las vistas

-- DOCENTE: lee catalogos; crea evaluaciones y notas. No puede borrar nada
GRANT SELECT ON academico_mvp.carreras, academico_mvp.asignaturas,
      academico_mvp.prerrequisitos_asignatura, academico_mvp.ciclos_academicos,
      academico_mvp.periodos_calificacion, academico_mvp.grupos,
      academico_mvp.matriculas TO rol_docente;
GRANT SELECT, INSERT, UPDATE ON academico_mvp.evaluaciones, academico_mvp.calificaciones TO rol_docente;
-- Permiso por COLUMNA: ve datos basicos del estudiante, nunca documento ni telefono
GRANT SELECT (estudiante_id, carnet, nombres, apellidos, carrera_id, nivel_actual,
              situacion_academica) ON academico_mvp.estudiantes TO rol_docente;
GRANT SELECT (docente_id, codigo, nombres, apellidos, especialidad)
      ON academico_mvp.docentes TO rol_docente;
GRANT SELECT ON academico_mvp.vw_promedios_asignatura, academico_mvp.vw_promedios_ciclo,
      academico_mvp.vw_historial_academico, academico_mvp.vw_control_ponderaciones TO rol_docente;

-- ESTUDIANTE: solo lectura
GRANT SELECT ON academico_mvp.carreras, academico_mvp.asignaturas,
      academico_mvp.ciclos_academicos, academico_mvp.periodos_calificacion,
      academico_mvp.grupos, academico_mvp.matriculas, academico_mvp.evaluaciones,
      academico_mvp.calificaciones TO rol_estudiante;
GRANT SELECT (estudiante_id, carnet, nombres, apellidos, carrera_id, correo,
              nivel_actual, situacion_academica) ON academico_mvp.estudiantes TO rol_estudiante;
GRANT SELECT (docente_id, nombres, apellidos) ON academico_mvp.docentes TO rol_estudiante;
GRANT SELECT ON academico_mvp.vw_promedios_asignatura, academico_mvp.vw_promedios_ciclo,
      academico_mvp.vw_historial_academico TO rol_estudiante;

-- AUDITOR: solo lectura de todo, incluida la bitacora
GRANT SELECT ON ALL TABLES IN SCHEMA academico_mvp TO rol_auditor;
GRANT SELECT ON ALL TABLES IN SCHEMA seguridad     TO rol_auditor;

-- Las tablas que se creen en el futuro tambien seran legibles por el auditor
ALTER DEFAULT PRIVILEGES FOR ROLE rol_admin_bd IN SCHEMA academico_mvp
  GRANT SELECT ON TABLES TO rol_auditor;

-- ---------------------------------------------------------
-- SEGURIDAD A NIVEL DE FILA
-- Los GRANT dicen a que TABLAS entra cada rol; las politicas dicen a que FILAS
-- ---------------------------------------------------------
ALTER TABLE academico_mvp.estudiantes    ENABLE ROW LEVEL SECURITY;
ALTER TABLE academico_mvp.matriculas     ENABLE ROW LEVEL SECURITY;
ALTER TABLE academico_mvp.evaluaciones   ENABLE ROW LEVEL SECURITY;
ALTER TABLE academico_mvp.calificaciones ENABLE ROW LEVEL SECURITY;

-- ---- ESTUDIANTES ----
-- Personal administrativo ve todo
CREATE POLICY p_est_staff_r ON academico_mvp.estudiantes FOR SELECT
  TO rol_admin_bd, rol_registro, rol_auditor USING (true);
CREATE POLICY p_est_registro_w ON academico_mvp.estudiantes FOR ALL
  TO rol_admin_bd, rol_registro USING (true) WITH CHECK (true);
-- El estudiante solo se ve a si mismo
CREATE POLICY p_est_propio ON academico_mvp.estudiantes FOR SELECT
  TO rol_estudiante USING (estudiante_id = seguridad.fn_estudiante_id());
-- El docente solo ve a los estudiantes matriculados en sus grupos
CREATE POLICY p_est_docente ON academico_mvp.estudiantes FOR SELECT
  TO rol_docente USING (estudiante_id IN (
    SELECT m.estudiante_id FROM academico_mvp.matriculas m
    JOIN academico_mvp.grupos g ON g.grupo_id = m.grupo_id
    WHERE g.docente_id = seguridad.fn_docente_id()));

-- ---- MATRICULAS ----
CREATE POLICY p_mat_staff_r ON academico_mvp.matriculas FOR SELECT
  TO rol_admin_bd, rol_registro, rol_auditor USING (true);
CREATE POLICY p_mat_registro_w ON academico_mvp.matriculas FOR ALL
  TO rol_admin_bd, rol_registro USING (true) WITH CHECK (true);
CREATE POLICY p_mat_propia ON academico_mvp.matriculas FOR SELECT
  TO rol_estudiante USING (estudiante_id = seguridad.fn_estudiante_id());
CREATE POLICY p_mat_docente ON academico_mvp.matriculas FOR SELECT
  TO rol_docente USING (grupo_id IN (
    SELECT grupo_id FROM academico_mvp.grupos WHERE docente_id = seguridad.fn_docente_id()));

-- ---- EVALUACIONES ----
CREATE POLICY p_eva_staff_r ON academico_mvp.evaluaciones FOR SELECT
  TO rol_admin_bd, rol_registro, rol_auditor USING (true);
CREATE POLICY p_eva_admin_w ON academico_mvp.evaluaciones FOR ALL
  TO rol_admin_bd USING (true) WITH CHECK (true);
-- Docente: crea y edita evaluaciones solo de sus grupos
CREATE POLICY p_eva_docente ON academico_mvp.evaluaciones FOR ALL
  TO rol_docente
  USING      (grupo_id IN (SELECT grupo_id FROM academico_mvp.grupos
                           WHERE docente_id = seguridad.fn_docente_id()))
  WITH CHECK (grupo_id IN (SELECT grupo_id FROM academico_mvp.grupos
                           WHERE docente_id = seguridad.fn_docente_id()));
-- Estudiante: solo evaluaciones de los grupos donde esta matriculado
CREATE POLICY p_eva_estudiante ON academico_mvp.evaluaciones FOR SELECT
  TO rol_estudiante USING (grupo_id IN (
    SELECT grupo_id FROM academico_mvp.matriculas
    WHERE estudiante_id = seguridad.fn_estudiante_id()));

-- ---- CALIFICACIONES ----
CREATE POLICY p_cal_staff_r ON academico_mvp.calificaciones FOR SELECT
  TO rol_admin_bd, rol_registro, rol_auditor USING (true);
CREATE POLICY p_cal_admin_w ON academico_mvp.calificaciones FOR ALL
  TO rol_admin_bd USING (true) WITH CHECK (true);

-- Docente lee las notas de sus grupos
CREATE POLICY p_cal_docente_r ON academico_mvp.calificaciones FOR SELECT
  TO rol_docente USING (evaluacion_id IN (
    SELECT e.evaluacion_id FROM academico_mvp.evaluaciones e
    JOIN academico_mvp.grupos g ON g.grupo_id = e.grupo_id
    WHERE g.docente_id = seguridad.fn_docente_id()));

-- Docente inserta notas solo en sus grupos y solo si el periodo esta abierto
CREATE POLICY p_cal_docente_i ON academico_mvp.calificaciones FOR INSERT
  TO rol_docente WITH CHECK (evaluacion_id IN (
    SELECT e.evaluacion_id FROM academico_mvp.evaluaciones e
    JOIN academico_mvp.grupos g ON g.grupo_id = e.grupo_id
    JOIN academico_mvp.periodos_calificacion p
      ON p.periodo_calificacion_id = e.periodo_calificacion_id
    WHERE g.docente_id = seguridad.fn_docente_id() AND p.estado = 'ABIERTO'));

-- Docente modifica notas con la misma regla periodo cerrado = nota bloqueada
CREATE POLICY p_cal_docente_u ON academico_mvp.calificaciones FOR UPDATE
  TO rol_docente
  USING (evaluacion_id IN (
    SELECT e.evaluacion_id FROM academico_mvp.evaluaciones e
    JOIN academico_mvp.grupos g ON g.grupo_id = e.grupo_id
    JOIN academico_mvp.periodos_calificacion p
      ON p.periodo_calificacion_id = e.periodo_calificacion_id
    WHERE g.docente_id = seguridad.fn_docente_id() AND p.estado = 'ABIERTO'))
  WITH CHECK (evaluacion_id IN (
    SELECT e.evaluacion_id FROM academico_mvp.evaluaciones e
    JOIN academico_mvp.grupos g ON g.grupo_id = e.grupo_id
    JOIN academico_mvp.periodos_calificacion p
      ON p.periodo_calificacion_id = e.periodo_calificacion_id
    WHERE g.docente_id = seguridad.fn_docente_id() AND p.estado = 'ABIERTO'));

-- Estudiante: solo sus propias notas
CREATE POLICY p_cal_estudiante ON academico_mvp.calificaciones FOR SELECT
  TO rol_estudiante USING (matricula_id IN (
    SELECT matricula_id FROM academico_mvp.matriculas
    WHERE estudiante_id = seguridad.fn_estudiante_id()));

-- ---------------------------------------------------------
-- CIFRADO DE DATOS PERSONALES
-- La clave se pasa por sesion
-- ---------------------------------------------------------
SET app.clave_cifrado = 'clave-cambiar-cifrado';  -- cambiar
-- Columnas nuevas para guardar los datos cifrados
-- documento_hash permite seguir validando que no haya documentos repetidos
-- sin guardar el documento en claro
ALTER TABLE academico_mvp.estudiantes
  ADD COLUMN IF NOT EXISTS documento_identidad_enc BYTEA,
  ADD COLUMN IF NOT EXISTS documento_hash          BYTEA UNIQUE,
  ADD COLUMN IF NOT EXISTS telefono_enc            BYTEA;
ALTER TABLE academico_mvp.docentes
  ADD COLUMN IF NOT EXISTS documento_identidad_enc BYTEA,
  ADD COLUMN IF NOT EXISTS documento_hash          BYTEA UNIQUE,
  ADD COLUMN IF NOT EXISTS telefono_enc            BYTEA;

-- Datos sensibles de prueba
UPDATE academico_mvp.estudiantes
SET documento_identidad = lpad(estudiante_id::text, 8, '0') || '-1',
    telefono            = '7' || lpad(estudiante_id::text, 3, '0') || '-1234'
WHERE documento_identidad IS NULL AND documento_identidad_enc IS NULL;

UPDATE academico_mvp.docentes
SET documento_identidad = lpad((docente_id + 1000)::text, 8, '0') || '-2',
    telefono            = '7888-' || lpad(docente_id::text, 4, '0')
WHERE documento_identidad IS NULL AND documento_identidad_enc IS NULL;

-- Cifrar: pgp_sym_encrypt = cifrado simetrico con la clave; hmac = huella irreversible
UPDATE academico_mvp.estudiantes SET
  documento_identidad_enc = pgp_sym_encrypt(documento_identidad, current_setting('app.clave_cifrado')),
  documento_hash          = hmac(documento_identidad, current_setting('app.clave_cifrado'), 'sha256'),
  telefono_enc            = pgp_sym_encrypt(telefono, current_setting('app.clave_cifrado'))
WHERE documento_identidad IS NOT NULL;

UPDATE academico_mvp.docentes SET
  documento_identidad_enc = pgp_sym_encrypt(documento_identidad, current_setting('app.clave_cifrado')),
  documento_hash          = hmac(documento_identidad, current_setting('app.clave_cifrado'), 'sha256'),
  telefono_enc            = pgp_sym_encrypt(telefono, current_setting('app.clave_cifrado'))
WHERE documento_identidad IS NOT NULL;

-- Borrar el texto plano, pero solo donde ya existe la version cifrada
UPDATE academico_mvp.estudiantes SET documento_identidad = NULL, telefono = NULL
WHERE documento_identidad_enc IS NOT NULL;
UPDATE academico_mvp.docentes SET documento_identidad = NULL, telefono = NULL
WHERE documento_identidad_enc IS NOT NULL;


/* =========================================================
   MONITOREO Y ALERTAS
   ========================================================= */

-- pg_monitor: rol predefinido que permite leer las estadisticas del servidor
-- (sesiones, consultas activas) sin ser superusuario.
GRANT pg_monitor TO rol_admin_bd;

-- ---------------------------------------------------------
-- 1. TABLAS
-- ---------------------------------------------------------
-- Umbrales: se pueden cambiar con un UPDATE, sin tocar el codigo
CREATE TABLE IF NOT EXISTS seguridad.umbrales (
  metrica      TEXT PRIMARY KEY,
  descripcion  TEXT    NOT NULL,
  operador     CHAR(1) NOT NULL CHECK (operador IN ('>', '<')),  -- alerta si valor > o < umbral
  valor        NUMERIC NOT NULL,
  severidad    TEXT    NOT NULL CHECK (severidad IN ('BAJA', 'MEDIA', 'ALTA')),
  activo       BOOLEAN NOT NULL DEFAULT TRUE
);

-- Historial: una fila por metrica en cada medicion (sirve para ver tendencias)
CREATE TABLE IF NOT EXISTS seguridad.metricas_historial (
  metrica_hist_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  fecha_hora      TIMESTAMPTZ NOT NULL DEFAULT now(),
  metrica         TEXT        NOT NULL,
  valor           NUMERIC     NOT NULL
);
CREATE INDEX IF NOT EXISTS ix_metricas_hist_metrica_fecha
  ON seguridad.metricas_historial (metrica, fecha_hora DESC);

-- Alertas generadas; "atendida" permite saber cuales siguen pendientes
CREATE TABLE IF NOT EXISTS seguridad.alertas (
  alerta_id     BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  fecha_hora    TIMESTAMPTZ NOT NULL DEFAULT now(),
  metrica       TEXT        NOT NULL,
  valor         NUMERIC     NOT NULL,
  umbral        NUMERIC     NOT NULL,
  severidad     TEXT        NOT NULL,
  mensaje       TEXT        NOT NULL,
  atendida      BOOLEAN     NOT NULL DEFAULT FALSE,
  atendida_por  TEXT,
  atendida_en   TIMESTAMPTZ
);
CREATE INDEX IF NOT EXISTS ix_alertas_pendientes
  ON seguridad.alertas (metrica, fecha_hora DESC) WHERE NOT atendida;

ALTER TABLE seguridad.umbrales           OWNER TO rol_admin_bd;
ALTER TABLE seguridad.metricas_historial OWNER TO rol_admin_bd;
ALTER TABLE seguridad.alertas            OWNER TO rol_admin_bd;

-- Umbrales iniciales
INSERT INTO seguridad.umbrales (metrica, descripcion, operador, valor, severidad) VALUES
  ('conexiones_pct',                  'Uso de conexiones (% de max_connections)',             '>', 80,   'ALTA'),
  ('tamanio_bd_mb',                   'Tamanio de la base de datos (MB)',                     '>', 1024, 'MEDIA'),
  ('cache_hit_pct',                   'Aciertos de cache (%)',                                '<', 90,   'MEDIA'),
  ('consultas_largas',                'Consultas activas por mas de 5 minutos',               '>', 0,    'ALTA'),
  ('idle_in_transaction',             'Transacciones abiertas sin actividad por 10 minutos',  '>', 0,    'MEDIA'),
  ('tuplas_muertas_pct',              'Tuplas muertas en la peor tabla (%)',                  '>', 20,   'MEDIA'),
  ('cambios_notas_10min_max_usuario', 'Cambios de notas por un mismo usuario en 10 minutos',  '>', 20,   'ALTA'),
  ('cambios_notas_fuera_horario',     'Cambios de notas entre 22:00 y 05:00 (ultimos 10 min)','>', 0,    'ALTA')
ON CONFLICT (metrica) DO NOTHING;

-- ---------------------------------------------------------
-- 2. FUNCION PRINCIPAL: mide, guarda y alerta
-- ---------------------------------------------------------
CREATE OR REPLACE FUNCTION seguridad.fn_recolectar_metricas() RETURNS INTEGER
LANGUAGE plpgsql SECURITY DEFINER SET search_path = seguridad, pg_temp AS $$
DECLARE n INTEGER;
BEGIN
  -- Retencion: el historial se conserva 30 dias para que no crezca sin control
  DELETE FROM seguridad.metricas_historial WHERE fecha_hora < now() - interval '30 days';

  -- "m" calcula todas las metricas; "h" las guarda en el historial;
  -- el INSERT final compara cada una con su umbral y crea la alerta si lo supera.
  WITH m(metrica, valor) AS (
    -- Porcentaje de conexiones usadas respecto al maximo permitido
    SELECT 'conexiones_pct'::text,
           round(100.0 * count(*) / current_setting('max_connections')::numeric, 2)
      FROM pg_stat_activity WHERE backend_type = 'client backend'
    UNION ALL
    -- Tamanio de la base en MB (control de crecimiento)
    SELECT 'tamanio_bd_mb', round(pg_database_size(current_database()) / 1048576.0, 2)
    UNION ALL
    -- Porcentaje de lecturas servidas desde memoria (bajo = rendimiento pobre)
    SELECT 'cache_hit_pct',
           COALESCE(round(100.0 * blks_hit / NULLIF(blks_hit + blks_read, 0), 2), 100)
      FROM pg_stat_database WHERE datname = current_database()
    UNION ALL
    -- Consultas activas hace mas de 5 minutos
    SELECT 'consultas_largas', count(*)
      FROM pg_stat_activity
     WHERE datname = current_database() AND state = 'active'
       AND now() - query_start > interval '5 minutes' AND pid <> pg_backend_pid()
    UNION ALL
    -- Transacciones abiertas y abandonadas (bloquean y retienen espacio)
    SELECT 'idle_in_transaction', count(*)
      FROM pg_stat_activity
     WHERE datname = current_database() AND state = 'idle in transaction'
       AND now() - state_change > interval '10 minutes'
    UNION ALL
    -- Porcentaje de filas muertas en la peor tabla
    SELECT 'tuplas_muertas_pct',
           COALESCE(max(round(100.0 * n_dead_tup / NULLIF(n_live_tup + n_dead_tup, 0), 2)), 0)
      FROM pg_stat_user_tables WHERE n_live_tup + n_dead_tup > 1000
    UNION ALL
    -- SEGURIDAD: mayor numero de cambios de notas hechos por un mismo usuario en 10 min
    SELECT 'cambios_notas_10min_max_usuario', COALESCE(max(c), 0)
      FROM (SELECT count(*) AS c FROM seguridad.bitacora_calificaciones
             WHERE fecha_hora > now() - interval '10 minutes' GROUP BY usuario_bd) x
    UNION ALL
    -- SEGURIDAD: cambios de notas de madrugada
    SELECT 'cambios_notas_fuera_horario', count(*)
      FROM seguridad.bitacora_calificaciones
     WHERE fecha_hora > now() - interval '10 minutes'
       AND (EXTRACT(hour FROM fecha_hora) >= 22 OR EXTRACT(hour FROM fecha_hora) < 5)
  ),
  h AS (
    INSERT INTO seguridad.metricas_historial (metrica, valor)
    SELECT metrica, valor FROM m
    RETURNING metrica, valor
  )
  INSERT INTO seguridad.alertas (metrica, valor, umbral, severidad, mensaje)
  SELECT h.metrica, h.valor, u.valor, u.severidad,
         u.descripcion || ': ' || h.valor || ' (umbral ' || u.operador || ' ' || u.valor || ')'
    FROM h
    JOIN seguridad.umbrales u ON u.metrica = h.metrica
   WHERE u.activo
     AND ((u.operador = '>' AND h.valor > u.valor) OR (u.operador = '<' AND h.valor < u.valor))
     -- No repite la misma alerta si ya hay una pendiente de los ultimos 15 minutos
     AND NOT EXISTS (SELECT 1 FROM seguridad.alertas a
                      WHERE a.metrica = h.metrica AND NOT a.atendida
                        AND a.fecha_hora > now() - interval '15 minutes');

  GET DIAGNOSTICS n = ROW_COUNT;
  RETURN n;   -- cantidad de alertas nuevas generadas
END $$;
ALTER FUNCTION seguridad.fn_recolectar_metricas() OWNER TO rol_admin_bd;
REVOKE ALL ON FUNCTION seguridad.fn_recolectar_metricas() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION seguridad.fn_recolectar_metricas() TO rol_admin_bd;

-- Marcar una alerta como atendida
CREATE OR REPLACE FUNCTION seguridad.fn_atender_alerta(p_alerta_id BIGINT) 
RETURNS TEXT
LANGUAGE plpgsql SECURITY DEFINER SET search_path = seguridad, pg_temp AS $$
DECLARE
    v_actualizadas INTEGER;
BEGIN
  UPDATE seguridad.alertas
     SET atendida = TRUE,
         atendida_por = COALESCE(NULLIF(current_setting('role', true), 'none'), session_user::text),
         atendida_en = now()
   WHERE alerta_id = p_alerta_id AND NOT atendida;

  GET DIAGNOSTICS v_actualizadas = ROW_COUNT;
  
  IF v_actualizadas > 0 THEN
      RETURN 'La alerta ' || p_alerta_id || ' fue marcada como atendida exitosamente.';
  ELSE
      RETURN 'La alerta ' || p_alerta_id || ' no existe o ya ha sido atendida previamente.';
  END IF;
END $$;
ALTER FUNCTION seguridad.fn_atender_alerta(BIGINT) OWNER TO rol_admin_bd;
REVOKE ALL ON FUNCTION seguridad.fn_atender_alerta(BIGINT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION seguridad.fn_atender_alerta(BIGINT) TO rol_admin_bd, rol_auditor;

-- ---------------------------------------------------------
-- VISTAS PARA CONSULTAR
-- ---------------------------------------------------------
-- Alertas sin atender, las mas graves primero
CREATE OR REPLACE VIEW seguridad.vw_alertas_pendientes AS
SELECT alerta_id, fecha_hora, severidad, metrica, valor, umbral, mensaje
  FROM seguridad.alertas
 WHERE NOT atendida
 ORDER BY CASE severidad WHEN 'ALTA' THEN 1 WHEN 'MEDIA' THEN 2 ELSE 3 END, fecha_hora DESC;

-- Ultima medicion de cada metrica frente a su umbral: OK o ALERTA
CREATE OR REPLACE VIEW seguridad.vw_estado_monitoreo AS
SELECT u.metrica, u.descripcion, ult.fecha_hora, ult.valor,
       u.operador, u.valor AS umbral, u.severidad,
       CASE WHEN ult.valor IS NULL THEN 'SIN DATOS'
            WHEN (u.operador = '>' AND ult.valor > u.valor)
              OR (u.operador = '<' AND ult.valor < u.valor) THEN 'ALERTA'
            ELSE 'OK' END AS estado
  FROM seguridad.umbrales u
  LEFT JOIN LATERAL (
        SELECT fecha_hora, valor FROM seguridad.metricas_historial h
         WHERE h.metrica = u.metrica ORDER BY fecha_hora DESC LIMIT 1) ult ON TRUE
 WHERE u.activo;

-- Tamanio de cada tabla (apoya el informe de crecimiento)
CREATE OR REPLACE VIEW seguridad.vw_tamanio_tablas AS
SELECT relname AS tabla,
       n_live_tup AS filas_aprox,
       pg_size_pretty(pg_total_relation_size(relid)) AS tamanio_total,
       n_dead_tup AS tuplas_muertas,
       last_autovacuum
  FROM pg_stat_user_tables
 WHERE schemaname IN ('academico_mvp', 'seguridad')
 ORDER BY pg_total_relation_size(relid) DESC;

ALTER VIEW seguridad.vw_alertas_pendientes OWNER TO rol_admin_bd;
ALTER VIEW seguridad.vw_estado_monitoreo   OWNER TO rol_admin_bd;
ALTER VIEW seguridad.vw_tamanio_tablas     OWNER TO rol_admin_bd;

-- El auditor solo lee
GRANT SELECT ON seguridad.umbrales, seguridad.metricas_historial, seguridad.alertas,
      seguridad.vw_alertas_pendientes, seguridad.vw_estado_monitoreo,
      seguridad.vw_tamanio_tablas TO rol_auditor;
