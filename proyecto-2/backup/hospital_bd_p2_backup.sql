--
-- PostgreSQL database dump
--

\restrict mFQzdX24KoRwudewieI70bAthbneonRuDFVHb8v8eiW0o0m50ieEsvzLvGkezq4

-- Dumped from database version 18.6
-- Dumped by pg_dump version 18.6

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: propuesta_cirugia; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA propuesta_cirugia;


--
-- Name: SCHEMA propuesta_cirugia; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON SCHEMA propuesta_cirugia IS 'Propuesta de normalizacion del Reporte_Cirugia (objetivo 19), separada del modelo hospitalario';


--
-- Name: fn_auditoria_solo_insercion(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fn_auditoria_solo_insercion() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    RAISE EXCEPTION 'auditoria_medico es de solo insercion: no se permite %', TG_OP;
END
$$;


--
-- Name: FUNCTION fn_auditoria_solo_insercion(); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.fn_auditoria_solo_insercion() IS 'Impide modificar o borrar la bitacora de auditoria';


--
-- Name: fn_medico_auditar_cambios(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fn_medico_auditar_cambios() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
BEGIN
    IF OLD.salario IS DISTINCT FROM NEW.salario THEN
        INSERT INTO auditoria_medico (id_medico, campo, valor_anterior, valor_nuevo)
        VALUES (NEW.id_medico, 'salario', OLD.salario::text, NEW.salario::text);
    END IF;
    IF OLD.id_especialidad IS DISTINCT FROM NEW.id_especialidad THEN
        INSERT INTO auditoria_medico (id_medico, campo, valor_anterior, valor_nuevo)
        VALUES (NEW.id_medico, 'id_especialidad', OLD.id_especialidad::text, NEW.id_especialidad::text);
    END IF;
    IF OLD.nivel_acceso IS DISTINCT FROM NEW.nivel_acceso THEN
        INSERT INTO auditoria_medico (id_medico, campo, valor_anterior, valor_nuevo)
        VALUES (NEW.id_medico, 'nivel_acceso', OLD.nivel_acceso, NEW.nivel_acceso);
    END IF;
    RETURN NULL;
END
$$;


--
-- Name: FUNCTION fn_medico_auditar_cambios(); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.fn_medico_auditar_cambios() IS 'Escribe en auditoria_medico cada cambio de salario, especialidad o nivel de acceso';


--
-- Name: fn_medico_evitar_ciclo(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fn_medico_evitar_ciclo() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF NEW.id_supervisor IS NULL THEN
        RETURN NEW;
    END IF;
    -- sube por la cadena de mando desde el supervisor propuesto; si llega al propio medico, habria un ciclo
    IF EXISTS (
        WITH RECURSIVE cadena AS (
            SELECT id_medico, id_supervisor FROM medico WHERE id_medico = NEW.id_supervisor
            UNION
            SELECT m.id_medico, m.id_supervisor FROM medico m JOIN cadena c ON m.id_medico = c.id_supervisor
        )
        SELECT 1 FROM cadena WHERE id_medico = NEW.id_medico
    ) THEN
        RAISE EXCEPTION 'El supervisor % ya depende del medico %: se formaria un ciclo en la jerarquia', NEW.id_supervisor, NEW.id_medico;
    END IF;
    RETURN NEW;
END
$$;


--
-- Name: FUNCTION fn_medico_evitar_ciclo(); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.fn_medico_evitar_ciclo() IS 'Impide ciclos en la relacion recursiva medico.id_supervisor';


--
-- Name: fn_personal_propagar_datos(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fn_personal_propagar_datos() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF NEW.tipo_personal = 'Medico' THEN
        UPDATE medico SET nombre = NEW.nombre, dpi = NEW.dpi, telefono = NEW.telefono WHERE id_personal = NEW.id_personal;
    ELSIF NEW.tipo_personal = 'Enfermero' THEN
        UPDATE enfermero SET nombre = NEW.nombre, dpi = NEW.dpi WHERE id_personal = NEW.id_personal;
    ELSE
        UPDATE personal_encargado SET nombre = NEW.nombre, dpi = NEW.dpi, telefono = NEW.telefono WHERE id_personal = NEW.id_personal;
    END IF;
    RETURN NULL;
END
$$;


--
-- Name: FUNCTION fn_personal_propagar_datos(); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.fn_personal_propagar_datos() IS 'Propaga a las columnas espejo del subtipo los cambios de nombre, dpi y telefono hechos en personal';


--
-- Name: fn_subtipo_heredar_personal(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fn_subtipo_heredar_personal() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    p personal%ROWTYPE;
BEGIN
    SELECT * INTO p FROM personal WHERE id_personal = NEW.id_personal;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'No existe personal con id_personal = %: primero se inserta el supertipo', NEW.id_personal;
    END IF;
    NEW.nombre := p.nombre;
    NEW.dpi := p.dpi;
    IF TG_TABLE_NAME <> 'enfermero' THEN  -- enfermero no tenia columna telefono en el Proyecto 1
        NEW.telefono := p.telefono;
    END IF;
    RETURN NEW;
END
$$;


--
-- Name: FUNCTION fn_subtipo_heredar_personal(); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.fn_subtipo_heredar_personal() IS 'Copia al subtipo los datos comunes del supertipo al insertar (columnas espejo)';


--
-- Name: fn_turno_validar(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fn_turno_validar() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF (SELECT id_hospital FROM medico WHERE id_medico = NEW.id_medico)
       IS DISTINCT FROM (SELECT id_hospital FROM unidad_hospital WHERE id_unidad_hospital = NEW.id_unidad_hospital) THEN
        RAISE EXCEPTION 'La unidad % no pertenece al hospital del medico %', NEW.id_unidad_hospital, NEW.id_medico;
    END IF;
    IF EXISTS (
        SELECT 1 FROM turno_laboral t
        WHERE t.id_medico = NEW.id_medico
          AND t.id_turno_laboral IS DISTINCT FROM NEW.id_turno_laboral
          AND t.fecha_hora_inicio < NEW.fecha_hora_fin AND NEW.fecha_hora_inicio < t.fecha_hora_fin
    ) THEN
        RAISE EXCEPTION 'El turno se traslapa con otro turno del medico %', NEW.id_medico;
    END IF;
    RETURN NEW;
END
$$;


--
-- Name: FUNCTION fn_turno_validar(); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.fn_turno_validar() IS 'Valida que la unidad sea del hospital del medico y que sus turnos no se traslapen';


--
-- Name: turno_de_hora(timestamp without time zone); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.turno_de_hora(p_fecha_hora timestamp without time zone) RETURNS character varying
    LANGUAGE sql IMMUTABLE
    AS $$
    SELECT CASE
        WHEN EXTRACT(HOUR FROM p_fecha_hora) >= 6  AND EXTRACT(HOUR FROM p_fecha_hora) < 14 THEN 'Matutino'
        WHEN EXTRACT(HOUR FROM p_fecha_hora) >= 14 AND EXTRACT(HOUR FROM p_fecha_hora) < 22 THEN 'Vespertino'
        ELSE 'Nocturno'
    END
$$;


--
-- Name: FUNCTION turno_de_hora(p_fecha_hora timestamp without time zone); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.turno_de_hora(p_fecha_hora timestamp without time zone) IS 'Turno de una hora: Matutino 06-14, Vespertino 14-22, Nocturno 22-06';


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: cirugia; Type: TABLE; Schema: propuesta_cirugia; Owner: -
--

CREATE TABLE propuesta_cirugia.cirugia (
    id_cirugia integer NOT NULL,
    id_cirujano integer NOT NULL,
    id_paciente integer NOT NULL,
    codigo_diagnostico character varying(10) NOT NULL,
    fecha date NOT NULL
);


--
-- Name: TABLE cirugia; Type: COMMENT; Schema: propuesta_cirugia; Owner: -
--

COMMENT ON TABLE propuesta_cirugia.cirugia IS 'Cada cirugia con sus llaves foraneas; ya no repite datos del cirujano, paciente ni diagnostico';


--
-- Name: cirugia_insumo; Type: TABLE; Schema: propuesta_cirugia; Owner: -
--

CREATE TABLE propuesta_cirugia.cirugia_insumo (
    id_cirugia integer NOT NULL,
    id_insumo integer NOT NULL,
    cantidad integer NOT NULL,
    CONSTRAINT chk_prop_cirugiainsumo_cantidad CHECK ((cantidad > 0))
);


--
-- Name: TABLE cirugia_insumo; Type: COMMENT; Schema: propuesta_cirugia; Owner: -
--

COMMENT ON TABLE propuesta_cirugia.cirugia_insumo IS 'Reemplaza los grupos repetidos insumo_1/insumo_2: una fila por insumo usado, sin limite de insumos';


--
-- Name: cirujano; Type: TABLE; Schema: propuesta_cirugia; Owner: -
--

CREATE TABLE propuesta_cirugia.cirujano (
    id_cirujano integer NOT NULL,
    nombre character varying(150) NOT NULL,
    id_especialidad integer NOT NULL
);


--
-- Name: TABLE cirujano; Type: COMMENT; Schema: propuesta_cirugia; Owner: -
--

COMMENT ON TABLE propuesta_cirugia.cirujano IS 'Cirujano con su especialidad, registrado una sola vez';


--
-- Name: cirujano_id_cirujano_seq; Type: SEQUENCE; Schema: propuesta_cirugia; Owner: -
--

ALTER TABLE propuesta_cirugia.cirujano ALTER COLUMN id_cirujano ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME propuesta_cirugia.cirujano_id_cirujano_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: diagnostico; Type: TABLE; Schema: propuesta_cirugia; Owner: -
--

CREATE TABLE propuesta_cirugia.diagnostico (
    codigo character varying(10) NOT NULL,
    descripcion character varying(200) NOT NULL
);


--
-- Name: TABLE diagnostico; Type: COMMENT; Schema: propuesta_cirugia; Owner: -
--

COMMENT ON TABLE propuesta_cirugia.diagnostico IS 'Catalogo de diagnosticos: el codigo determina la descripcion';


--
-- Name: especialidad; Type: TABLE; Schema: propuesta_cirugia; Owner: -
--

CREATE TABLE propuesta_cirugia.especialidad (
    id_especialidad integer NOT NULL,
    nombre character varying(100) NOT NULL
);


--
-- Name: TABLE especialidad; Type: COMMENT; Schema: propuesta_cirugia; Owner: -
--

COMMENT ON TABLE propuesta_cirugia.especialidad IS 'Catalogo de especialidades de los cirujanos (antes repetida en cada fila del reporte)';


--
-- Name: especialidad_id_especialidad_seq; Type: SEQUENCE; Schema: propuesta_cirugia; Owner: -
--

ALTER TABLE propuesta_cirugia.especialidad ALTER COLUMN id_especialidad ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME propuesta_cirugia.especialidad_id_especialidad_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: insumo; Type: TABLE; Schema: propuesta_cirugia; Owner: -
--

CREATE TABLE propuesta_cirugia.insumo (
    id_insumo integer NOT NULL,
    nombre character varying(150) NOT NULL
);


--
-- Name: TABLE insumo; Type: COMMENT; Schema: propuesta_cirugia; Owner: -
--

COMMENT ON TABLE propuesta_cirugia.insumo IS 'Catalogo de insumos: un solo nombre por insumo (evita variantes escritas a mano)';


--
-- Name: insumo_id_insumo_seq; Type: SEQUENCE; Schema: propuesta_cirugia; Owner: -
--

ALTER TABLE propuesta_cirugia.insumo ALTER COLUMN id_insumo ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME propuesta_cirugia.insumo_id_insumo_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: paciente; Type: TABLE; Schema: propuesta_cirugia; Owner: -
--

CREATE TABLE propuesta_cirugia.paciente (
    id_paciente integer NOT NULL,
    nombre character varying(150) NOT NULL
);


--
-- Name: TABLE paciente; Type: COMMENT; Schema: propuesta_cirugia; Owner: -
--

COMMENT ON TABLE propuesta_cirugia.paciente IS 'Paciente operado, identificado por una llave propia y no por su nombre repetido';


--
-- Name: paciente_id_paciente_seq; Type: SEQUENCE; Schema: propuesta_cirugia; Owner: -
--

ALTER TABLE propuesta_cirugia.paciente ALTER COLUMN id_paciente ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME propuesta_cirugia.paciente_id_paciente_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: reporte_cirugia_original; Type: TABLE; Schema: propuesta_cirugia; Owner: -
--

CREATE TABLE propuesta_cirugia.reporte_cirugia_original (
    id_cirugia integer NOT NULL,
    nombre_cirujano character varying(150) NOT NULL,
    especialidad_cirujano character varying(100) NOT NULL,
    nombre_paciente character varying(150) NOT NULL,
    codigo_diagnostico character varying(10) NOT NULL,
    descripcion_diagnostico character varying(200) NOT NULL,
    nombre_insumo_1 character varying(150),
    cantidad_insumo_1 integer,
    nombre_insumo_2 character varying(150),
    cantidad_insumo_2 integer,
    fecha date NOT NULL
);


--
-- Name: TABLE reporte_cirugia_original; Type: COMMENT; Schema: propuesta_cirugia; Owner: -
--

COMMENT ON TABLE propuesta_cirugia.reporte_cirugia_original IS 'Reporte actual en una sola tabla; muestra la redundancia que se quiere eliminar';


--
-- Name: v_reporte_cirugia; Type: VIEW; Schema: propuesta_cirugia; Owner: -
--

CREATE VIEW propuesta_cirugia.v_reporte_cirugia AS
 SELECT c.id_cirugia,
    ci.nombre AS nombre_cirujano,
    e.nombre AS especialidad_cirujano,
    p.nombre AS nombre_paciente,
    c.codigo_diagnostico,
    d.descripcion AS descripcion_diagnostico,
    i1.nombre AS nombre_insumo_1,
    i1.cantidad AS cantidad_insumo_1,
    i2.nombre AS nombre_insumo_2,
    i2.cantidad AS cantidad_insumo_2,
    c.fecha
   FROM ((((((propuesta_cirugia.cirugia c
     JOIN propuesta_cirugia.cirujano ci ON ((ci.id_cirujano = c.id_cirujano)))
     JOIN propuesta_cirugia.especialidad e ON ((e.id_especialidad = ci.id_especialidad)))
     JOIN propuesta_cirugia.paciente p ON ((p.id_paciente = c.id_paciente)))
     JOIN propuesta_cirugia.diagnostico d ON (((d.codigo)::text = (c.codigo_diagnostico)::text)))
     LEFT JOIN LATERAL ( SELECT i.nombre,
            x.cantidad
           FROM (propuesta_cirugia.cirugia_insumo x
             JOIN propuesta_cirugia.insumo i USING (id_insumo))
          WHERE (x.id_cirugia = c.id_cirugia)
          ORDER BY i.id_insumo
         OFFSET 0
         LIMIT 1) i1 ON (true))
     LEFT JOIN LATERAL ( SELECT i.nombre,
            x.cantidad
           FROM (propuesta_cirugia.cirugia_insumo x
             JOIN propuesta_cirugia.insumo i USING (id_insumo))
          WHERE (x.id_cirugia = c.id_cirugia)
          ORDER BY i.id_insumo
         OFFSET 1
         LIMIT 1) i2 ON (true));


--
-- Name: VIEW v_reporte_cirugia; Type: COMMENT; Schema: propuesta_cirugia; Owner: -
--

COMMENT ON VIEW propuesta_cirugia.v_reporte_cirugia IS 'Reconstruye el formato del reporte original desde las tablas normalizadas';


--
-- Name: auditoria_medico; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.auditoria_medico (
    id_auditoria bigint NOT NULL,
    id_medico integer NOT NULL,
    campo character varying(20) NOT NULL,
    valor_anterior text,
    valor_nuevo text,
    usuario_bd character varying(63) DEFAULT SESSION_USER NOT NULL,
    fecha_hora timestamp with time zone DEFAULT clock_timestamp() NOT NULL,
    CONSTRAINT chk_auditoria_cambio_real CHECK ((valor_anterior IS DISTINCT FROM valor_nuevo)),
    CONSTRAINT chk_auditoria_campo CHECK (((campo)::text = ANY ((ARRAY['salario'::character varying, 'id_especialidad'::character varying, 'nivel_acceso'::character varying])::text[])))
);


--
-- Name: TABLE auditoria_medico; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.auditoria_medico IS 'Historial de solo insercion de los cambios de salario, especialidad y nivel de acceso de los medicos';


--
-- Name: COLUMN auditoria_medico.usuario_bd; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.auditoria_medico.usuario_bd IS 'Usuario con el que se inicio la sesion que hizo el cambio (session_user)';


--
-- Name: auditoria_medico_id_auditoria_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.auditoria_medico ALTER COLUMN id_auditoria ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.auditoria_medico_id_auditoria_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: calificacion_enfermero; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.calificacion_enfermero (
    id_calificacion integer NOT NULL,
    id_enfermero integer NOT NULL,
    puntaje smallint NOT NULL,
    fecha date NOT NULL,
    id_paciente integer,
    comentario text,
    CONSTRAINT chk_califenf_puntaje CHECK (((puntaje >= 1) AND (puntaje <= 5)))
);


--
-- Name: TABLE calificacion_enfermero; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.calificacion_enfermero IS 'Calificacion de calidad registrada para un enfermero';


--
-- Name: calificacion_enfermero_id_calificacion_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.calificacion_enfermero ALTER COLUMN id_calificacion ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.calificacion_enfermero_id_calificacion_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: calificacion_hospital; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.calificacion_hospital (
    id_calificacion integer NOT NULL,
    id_hospital integer NOT NULL,
    puntaje smallint NOT NULL,
    fecha date NOT NULL,
    id_paciente integer,
    comentario text,
    CONSTRAINT chk_califhosp_puntaje CHECK (((puntaje >= 1) AND (puntaje <= 5)))
);


--
-- Name: TABLE calificacion_hospital; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.calificacion_hospital IS 'Calificacion de calidad registrada para un hospital';


--
-- Name: calificacion_hospital_id_calificacion_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.calificacion_hospital ALTER COLUMN id_calificacion ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.calificacion_hospital_id_calificacion_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: calificacion_medico; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.calificacion_medico (
    id_calificacion integer NOT NULL,
    id_medico integer NOT NULL,
    puntaje smallint NOT NULL,
    fecha date NOT NULL,
    id_paciente integer,
    comentario text,
    CONSTRAINT chk_califmed_puntaje CHECK (((puntaje >= 1) AND (puntaje <= 5)))
);


--
-- Name: TABLE calificacion_medico; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.calificacion_medico IS 'Calificacion de calidad registrada para un medico';


--
-- Name: calificacion_medico_id_calificacion_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.calificacion_medico ALTER COLUMN id_calificacion ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.calificacion_medico_id_calificacion_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: calificacion_personal_encargado; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.calificacion_personal_encargado (
    id_calificacion integer NOT NULL,
    id_encargado integer NOT NULL,
    puntaje smallint NOT NULL,
    fecha date NOT NULL,
    id_paciente integer,
    comentario text,
    CONSTRAINT chk_califenc_puntaje CHECK (((puntaje >= 1) AND (puntaje <= 5)))
);


--
-- Name: TABLE calificacion_personal_encargado; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.calificacion_personal_encargado IS 'Calificacion de calidad registrada para el personal administrativo/encargado del hospital';


--
-- Name: calificacion_personal_encargado_id_calificacion_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.calificacion_personal_encargado ALTER COLUMN id_calificacion ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.calificacion_personal_encargado_id_calificacion_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: camilla; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.camilla (
    id_camilla integer NOT NULL,
    id_unidad_hospital integer NOT NULL,
    numero integer NOT NULL,
    estado character varying(10) DEFAULT 'Libre'::character varying NOT NULL,
    CONSTRAINT chk_camilla_estado CHECK (((estado)::text = ANY ((ARRAY['Libre'::character varying, 'Ocupada'::character varying])::text[])))
);


--
-- Name: TABLE camilla; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.camilla IS 'Camilla habilitada dentro de una unidad de Emergencias u Hospitalizacion';


--
-- Name: camilla_id_camilla_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.camilla ALTER COLUMN id_camilla ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.camilla_id_camilla_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: chequeo_preanestesico; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.chequeo_preanestesico (
    id_chequeo integer NOT NULL,
    id_solicitud integer NOT NULL,
    clasificacion_asa character varying(3) NOT NULL,
    id_medico_clasifica integer NOT NULL,
    id_anestesista integer NOT NULL,
    plan_anestesia text,
    CONSTRAINT chk_chequeo_asa CHECK (((clasificacion_asa)::text = ANY ((ARRAY['I'::character varying, 'II'::character varying, 'III'::character varying, 'IV'::character varying, 'V'::character varying, 'VI'::character varying])::text[])))
);


--
-- Name: TABLE chequeo_preanestesico; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.chequeo_preanestesico IS 'Chequeo preanestesico previo a la cirugia: clasificacion ASA y plan de anestesia';


--
-- Name: chequeo_preanestesico_id_chequeo_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.chequeo_preanestesico ALTER COLUMN id_chequeo ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.chequeo_preanestesico_id_chequeo_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: cirugia; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.cirugia (
    id_cirugia integer NOT NULL,
    id_solicitud integer NOT NULL,
    id_ingreso integer NOT NULL,
    id_quirofano integer NOT NULL,
    id_enfermero_encargado integer NOT NULL,
    fecha_hora_inicio timestamp without time zone NOT NULL,
    fecha_hora_fin timestamp without time zone,
    costo numeric(10,2),
    CONSTRAINT chk_cirugia_costo CHECK (((costo IS NULL) OR (costo >= (0)::numeric))),
    CONSTRAINT chk_cirugia_fin_posterior CHECK (((fecha_hora_fin IS NULL) OR (fecha_hora_fin >= fecha_hora_inicio)))
);


--
-- Name: TABLE cirugia; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.cirugia IS 'Evento intraoperatorio real: ejecucion de una solicitud de cirugia aprobada';


--
-- Name: cirugia_id_cirugia_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.cirugia ALTER COLUMN id_cirugia ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.cirugia_id_cirugia_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: cita_programada; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.cita_programada (
    id_cita integer NOT NULL,
    id_paciente integer NOT NULL,
    id_medico integer NOT NULL,
    fecha date NOT NULL,
    hora time without time zone NOT NULL,
    estado character varying(15) DEFAULT 'Programada'::character varying NOT NULL,
    consultorio character varying(20),
    CONSTRAINT chk_cita_estado CHECK (((estado)::text = ANY ((ARRAY['Programada'::character varying, 'Realizada'::character varying, 'Reprogramada'::character varying, 'Cancelada'::character varying])::text[])))
);


--
-- Name: TABLE cita_programada; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.cita_programada IS 'Cita de consulta externa asignada via telefono, correo o recepcion general';


--
-- Name: cita_programada_id_cita_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.cita_programada ALTER COLUMN id_cita ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.cita_programada_id_cita_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: consentimiento_informado; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.consentimiento_informado (
    id_consentimiento integer NOT NULL,
    id_solicitud integer NOT NULL,
    nombre_procedimiento character varying(150) NOT NULL,
    objetivo text NOT NULL,
    id_medico integer NOT NULL,
    firma_paciente character varying(150) NOT NULL,
    fecha date NOT NULL,
    caracteristicas text,
    riesgos text
);


--
-- Name: TABLE consentimiento_informado; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.consentimiento_informado IS 'Consentimiento informado firmado antes de la cirugia (paciente, familiar, tutor o representante)';


--
-- Name: consentimiento_informado_id_consentimiento_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.consentimiento_informado ALTER COLUMN id_consentimiento ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.consentimiento_informado_id_consentimiento_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: consulta_paciente; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.consulta_paciente (
    id_consulta integer NOT NULL,
    id_paciente integer NOT NULL,
    id_medico integer NOT NULL,
    fecha date NOT NULL,
    tipo_consulta character varying(15) NOT NULL,
    referido_institucion boolean DEFAULT false NOT NULL,
    id_cita integer,
    diagnostico text,
    notas text,
    CONSTRAINT chk_consulta_tipo CHECK (((tipo_consulta)::text = ANY ((ARRAY['Primera'::character varying, 'Reconsulta'::character varying])::text[])))
);


--
-- Name: TABLE consulta_paciente; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.consulta_paciente IS 'Ficha de consulta realizada en Consulta Externa (programada o de paciente referido)';


--
-- Name: consulta_paciente_id_consulta_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.consulta_paciente ALTER COLUMN id_consulta ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.consulta_paciente_id_consulta_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: cuota; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.cuota (
    id_cuota integer NOT NULL,
    id_factura integer NOT NULL,
    numero_cuota integer NOT NULL,
    monto numeric(10,2) NOT NULL,
    fecha_pago date,
    metodo_pago character varying(20) DEFAULT 'Efectivo'::character varying NOT NULL,
    CONSTRAINT chk_cuota_metodo_pago CHECK (((metodo_pago)::text = ANY ((ARRAY['Efectivo'::character varying, 'Tarjeta de credito'::character varying, 'Tarjeta de debito'::character varying])::text[]))),
    CONSTRAINT chk_cuota_monto CHECK ((monto > (0)::numeric)),
    CONSTRAINT chk_cuota_numero CHECK (((numero_cuota >= 1) AND (numero_cuota <= 12)))
);


--
-- Name: TABLE cuota; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.cuota IS 'Cuota mensual de pago de una factura (hasta 12 pagos)';


--
-- Name: COLUMN cuota.metodo_pago; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.cuota.metodo_pago IS 'Metodo con el que se pago la cuota; las cuotas del Proyecto 1 quedan como Efectivo';


--
-- Name: cuota_id_cuota_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.cuota ALTER COLUMN id_cuota ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.cuota_id_cuota_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: departamento; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.departamento (
    id_departamento integer NOT NULL,
    nombre character varying(100) NOT NULL
);


--
-- Name: TABLE departamento; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.departamento IS 'Catalogo de departamentos de Guatemala, usado en toda direccion registrada';


--
-- Name: departamento_id_departamento_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.departamento ALTER COLUMN id_departamento ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.departamento_id_departamento_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: diagnostico_secundario; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.diagnostico_secundario (
    id_diagnostico_secundario integer NOT NULL,
    id_egreso integer NOT NULL,
    descripcion text NOT NULL
);


--
-- Name: TABLE diagnostico_secundario; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.diagnostico_secundario IS 'Diagnostico secundario adicional registrado en una ficha de egreso (relacion 1:N)';


--
-- Name: diagnostico_secundario_id_diagnostico_secundario_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.diagnostico_secundario ALTER COLUMN id_diagnostico_secundario ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.diagnostico_secundario_id_diagnostico_secundario_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: egreso; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.egreso (
    id_egreso integer NOT NULL,
    id_ingreso integer NOT NULL,
    id_medico integer NOT NULL,
    fecha_hora timestamp without time zone NOT NULL,
    diagnostico_principal text NOT NULL,
    motivo_egreso text NOT NULL,
    codigo_egreso character varying(10) NOT NULL,
    egreso_sin_consentimiento boolean DEFAULT false NOT NULL,
    motivo_sin_consentimiento text,
    id_traslado integer,
    dias_hospitalizado integer,
    referido_otro_hospital character varying(150),
    CONSTRAINT chk_egreso_codigo CHECK (((codigo_egreso)::text = ANY ((ARRAY['Vivo'::character varying, 'Muerto'::character varying, 'Embarazo'::character varying, 'Parto'::character varying])::text[]))),
    CONSTRAINT chk_egreso_dias CHECK (((dias_hospitalizado IS NULL) OR (dias_hospitalizado >= 0))),
    CONSTRAINT chk_egreso_motivo_consentimiento CHECK ((((egreso_sin_consentimiento = false) AND (motivo_sin_consentimiento IS NULL)) OR ((egreso_sin_consentimiento = true) AND (motivo_sin_consentimiento IS NOT NULL))))
);


--
-- Name: TABLE egreso; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.egreso IS 'Ficha de egreso: cierra un ingreso, sea por alta, hospitalizacion, cirugia o defuncion';


--
-- Name: egreso_id_egreso_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.egreso ALTER COLUMN id_egreso ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.egreso_id_egreso_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: enfermero; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.enfermero (
    id_enfermero integer NOT NULL,
    nombre character varying(150) NOT NULL,
    dpi character varying(13) NOT NULL,
    tipo_enfermero character varying(20) NOT NULL,
    id_hospital integer NOT NULL,
    id_personal integer NOT NULL,
    tipo_personal character varying(10) DEFAULT 'Enfermero'::character varying NOT NULL,
    numero_colegiado character varying(20),
    CONSTRAINT chk_enfermero_colegiado CHECK (((numero_colegiado IS NULL) OR ((numero_colegiado)::text ~ '^[A-Z0-9-]{3,20}$'::text))),
    CONSTRAINT chk_enfermero_tipo CHECK (((tipo_enfermero)::text = ANY ((ARRAY['Registrado'::character varying, 'Practicante'::character varying])::text[]))),
    CONSTRAINT chk_enfermero_tipo_personal CHECK (((tipo_personal)::text = 'Enfermero'::text))
);


--
-- Name: TABLE enfermero; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.enfermero IS 'Enfermero registrado o practicante asignado a un hospital';


--
-- Name: COLUMN enfermero.nombre; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.enfermero.nombre IS 'Espejo de personal.nombre (columna del Proyecto 1 conservada; la mantiene un trigger)';


--
-- Name: COLUMN enfermero.dpi; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.enfermero.dpi IS 'Espejo de personal.dpi (columna del Proyecto 1 conservada; la mantiene un trigger)';


--
-- Name: COLUMN enfermero.id_personal; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.enfermero.id_personal IS 'Enlace 1:1 con el supertipo personal';


--
-- Name: COLUMN enfermero.numero_colegiado; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.enfermero.numero_colegiado IS 'Numero de colegiado profesional, si lo tiene';


--
-- Name: enfermero_id_enfermero_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.enfermero ALTER COLUMN id_enfermero ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.enfermero_id_enfermero_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: equipo; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.equipo (
    id_equipo integer NOT NULL,
    nombre character varying(150) NOT NULL,
    tipo character varying(15) NOT NULL,
    funcion character varying(20) NOT NULL,
    descripcion text,
    CONSTRAINT chk_equipo_funcion CHECK (((funcion)::text = ANY ((ARRAY['Exploracion'::character varying, 'Diagnostico'::character varying, 'Tratamiento'::character varying, 'Rehabilitacion'::character varying, 'Otro'::character varying])::text[]))),
    CONSTRAINT chk_equipo_tipo CHECK (((tipo)::text = ANY ((ARRAY['Medico'::character varying, 'Quirurgico'::character varying, 'Otro'::character varying])::text[])))
);


--
-- Name: TABLE equipo; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.equipo IS 'Catalogo de equipos medicos requeridos en una cirugia';


--
-- Name: equipo_id_equipo_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.equipo ALTER COLUMN id_equipo ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.equipo_id_equipo_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: especialidad; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.especialidad (
    id_especialidad integer NOT NULL,
    nombre character varying(100) NOT NULL,
    categoria character varying(25) NOT NULL,
    CONSTRAINT chk_especialidad_categoria CHECK (((categoria)::text = ANY ((ARRAY['Consulta_Emergencia'::character varying, 'Cirugia'::character varying, 'Hospitalizacion'::character varying])::text[])))
);


--
-- Name: TABLE especialidad; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.especialidad IS 'Catalogo unico de especialidades/servicios medicos ofrecidos por unidad';


--
-- Name: especialidad_id_especialidad_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.especialidad ALTER COLUMN id_especialidad ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.especialidad_id_especialidad_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: factura; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.factura (
    id_factura integer NOT NULL,
    id_hospital integer NOT NULL,
    id_paciente integer NOT NULL,
    fecha date NOT NULL,
    descripcion text NOT NULL,
    monto numeric(10,2) NOT NULL,
    id_consulta integer,
    id_ingreso integer,
    CONSTRAINT chk_factura_monto CHECK ((monto > (0)::numeric)),
    CONSTRAINT chk_factura_origen_exclusivo CHECK ((((id_consulta IS NOT NULL) AND (id_ingreso IS NULL)) OR ((id_consulta IS NULL) AND (id_ingreso IS NOT NULL))))
);


--
-- Name: TABLE factura; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.factura IS 'Factura emitida al cancelar el servicio, ya sea de Consulta Externa o de una unidad de internamiento';


--
-- Name: factura_id_factura_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.factura ALTER COLUMN id_factura ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.factura_id_factura_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: hospital; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.hospital (
    id_hospital integer NOT NULL,
    nombre character varying(150) NOT NULL,
    direccion character varying(200) NOT NULL,
    id_municipio integer NOT NULL,
    telefono character varying(20)
);


--
-- Name: TABLE hospital; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.hospital IS 'Cada uno de los hospitales que conforman la cadena Hospitales de Occidente';


--
-- Name: hospital_id_hospital_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.hospital ALTER COLUMN id_hospital ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.hospital_id_hospital_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: hospitalizacion_detalle; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.hospitalizacion_detalle (
    id_hospitalizacion_detalle integer NOT NULL,
    id_ingreso integer NOT NULL,
    id_servicio integer NOT NULL,
    id_camilla integer NOT NULL,
    costo_dia numeric(10,2),
    dias integer,
    CONSTRAINT chk_hospdet_costo_dia CHECK (((costo_dia IS NULL) OR (costo_dia >= (0)::numeric))),
    CONSTRAINT chk_hospdet_dias CHECK (((dias IS NULL) OR (dias >= 0)))
);


--
-- Name: TABLE hospitalizacion_detalle; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.hospitalizacion_detalle IS 'Detalle de la estadia de hospitalizacion asociada a un ingreso (servicio, camilla y costo)';


--
-- Name: hospitalizacion_detalle_id_hospitalizacion_detalle_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.hospitalizacion_detalle ALTER COLUMN id_hospitalizacion_detalle ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.hospitalizacion_detalle_id_hospitalizacion_detalle_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: ingreso; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ingreso (
    id_ingreso integer NOT NULL,
    id_paciente integer NOT NULL,
    id_unidad_hospital integer NOT NULL,
    id_medico integer NOT NULL,
    fecha_hora timestamp without time zone NOT NULL,
    motivo_ingreso text NOT NULL,
    id_responsable integer,
    id_camilla integer,
    diagnostico_presuntivo text,
    turno_espera integer,
    CONSTRAINT chk_ingreso_turno_espera CHECK (((turno_espera IS NULL) OR (turno_espera >= 0)))
);


--
-- Name: TABLE ingreso; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.ingreso IS 'Ficha de ingreso: registra el estado del paciente al ingresar a Emergencias, Cirugia u Hospitalizacion';


--
-- Name: COLUMN ingreso.turno_espera; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.ingreso.turno_espera IS 'Turnos de la fila que espero el paciente antes de ser atendido (0 = atendido de inmediato; NULL = no registrado)';


--
-- Name: ingreso_id_ingreso_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.ingreso ALTER COLUMN id_ingreso ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.ingreso_id_ingreso_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: instrumento; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.instrumento (
    id_instrumento integer NOT NULL,
    nombre character varying(150) NOT NULL,
    tipo character varying(15) NOT NULL,
    funcion character varying(20) NOT NULL,
    descripcion text,
    CONSTRAINT chk_instrumento_funcion CHECK (((funcion)::text = ANY ((ARRAY['Corte'::character varying, 'Contencion'::character varying, 'Hemostatica'::character varying, 'Retractor'::character varying, 'Accesorio'::character varying, 'Implante'::character varying, 'Otro'::character varying])::text[]))),
    CONSTRAINT chk_instrumento_tipo CHECK (((tipo)::text = ANY ((ARRAY['Medico'::character varying, 'Quirurgico'::character varying, 'Otro'::character varying])::text[])))
);


--
-- Name: TABLE instrumento; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.instrumento IS 'Catalogo de instrumental quirurgico requerido en una cirugia';


--
-- Name: instrumento_id_instrumento_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.instrumento ALTER COLUMN id_instrumento ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.instrumento_id_instrumento_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: insumo; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.insumo (
    id_insumo integer NOT NULL,
    nombre character varying(150) NOT NULL,
    material character varying(100) NOT NULL,
    tipo character varying(15) NOT NULL,
    descripcion text,
    CONSTRAINT chk_insumo_tipo CHECK (((tipo)::text = ANY ((ARRAY['Medico'::character varying, 'Quirurgico'::character varying, 'Otro'::character varying])::text[])))
);


--
-- Name: TABLE insumo; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.insumo IS 'Catalogo de insumos que se pueden requerir y utilizar en una cirugia';


--
-- Name: insumo_id_insumo_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.insumo ALTER COLUMN id_insumo ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.insumo_id_insumo_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: insumo_utilizado_cirugia; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.insumo_utilizado_cirugia (
    id_cirugia integer NOT NULL,
    id_insumo integer NOT NULL,
    cantidad integer NOT NULL,
    CONSTRAINT chk_insumoused_cantidad CHECK ((cantidad > 0))
);


--
-- Name: TABLE insumo_utilizado_cirugia; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.insumo_utilizado_cirugia IS 'Insumos efectivamente utilizados durante una cirugia (base para el calculo del costo)';


--
-- Name: medicamento_recetado; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.medicamento_recetado (
    id_medicamento_recetado integer NOT NULL,
    id_receta integer NOT NULL,
    nombre character varying(150) NOT NULL,
    dosis character varying(100) NOT NULL,
    duracion character varying(100) NOT NULL
);


--
-- Name: TABLE medicamento_recetado; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.medicamento_recetado IS 'Medicamento individual prescrito dentro de una receta medica';


--
-- Name: medicamento_recetado_id_medicamento_recetado_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.medicamento_recetado ALTER COLUMN id_medicamento_recetado ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.medicamento_recetado_id_medicamento_recetado_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: medico; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.medico (
    id_medico integer NOT NULL,
    nombre character varying(150) NOT NULL,
    dpi character varying(13) NOT NULL,
    id_especialidad integer NOT NULL,
    tipo_medico character varying(20) NOT NULL,
    id_hospital integer NOT NULL,
    telefono character varying(20),
    id_municipio integer,
    area character varying(10),
    id_personal integer NOT NULL,
    tipo_personal character varying(10) DEFAULT 'Medico'::character varying NOT NULL,
    cargo character varying(20) DEFAULT 'Medico'::character varying NOT NULL,
    id_supervisor integer,
    salario numeric(10,2),
    nivel_acceso character varying(15) DEFAULT 'Basico'::character varying NOT NULL,
    CONSTRAINT chk_medico_area CHECK (((area IS NULL) OR ((area)::text = ANY ((ARRAY['Urbana'::character varying, 'Rural'::character varying])::text[])))),
    CONSTRAINT chk_medico_cargo CHECK (((cargo)::text = ANY ((ARRAY['Director Medico'::character varying, 'Jefe de Servicio'::character varying, 'Medico'::character varying])::text[]))),
    CONSTRAINT chk_medico_director_sin_supervisor CHECK ((((cargo)::text <> 'Director Medico'::text) OR (id_supervisor IS NULL))),
    CONSTRAINT chk_medico_nivel_acceso CHECK (((nivel_acceso)::text = ANY ((ARRAY['Basico'::character varying, 'Intermedio'::character varying, 'Avanzado'::character varying, 'Administrador'::character varying])::text[]))),
    CONSTRAINT chk_medico_no_autosupervisor CHECK (((id_supervisor IS NULL) OR (id_supervisor <> id_medico))),
    CONSTRAINT chk_medico_salario CHECK (((salario IS NULL) OR (salario >= (0)::numeric))),
    CONSTRAINT chk_medico_tipo CHECK (((tipo_medico)::text = ANY ((ARRAY['Residente'::character varying, 'Interno'::character varying, 'Externo'::character varying])::text[]))),
    CONSTRAINT chk_medico_tipo_personal CHECK (((tipo_personal)::text = 'Medico'::text))
);


--
-- Name: TABLE medico; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.medico IS 'Medico que atiende en un hospital, en alguna de sus unidades';


--
-- Name: COLUMN medico.nombre; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.medico.nombre IS 'Espejo de personal.nombre (columna del Proyecto 1 conservada; la mantiene un trigger)';


--
-- Name: COLUMN medico.dpi; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.medico.dpi IS 'Espejo de personal.dpi (columna del Proyecto 1 conservada; la mantiene un trigger)';


--
-- Name: COLUMN medico.telefono; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.medico.telefono IS 'Espejo de personal.telefono (columna del Proyecto 1 conservada; la mantiene un trigger)';


--
-- Name: COLUMN medico.id_personal; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.medico.id_personal IS 'Enlace 1:1 con el supertipo personal';


--
-- Name: COLUMN medico.cargo; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.medico.cargo IS 'Nivel jerarquico: Director Medico, Jefe de Servicio o Medico';


--
-- Name: COLUMN medico.id_supervisor; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.medico.id_supervisor IS 'Jefe directo (relacion recursiva); NULL solo para el director medico o personal aun sin asignar';


--
-- Name: COLUMN medico.salario; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.medico.salario IS 'Salario mensual; dato sensible auditado (objetivo 20)';


--
-- Name: COLUMN medico.nivel_acceso; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.medico.nivel_acceso IS 'Nivel de acceso al sistema; dato sensible auditado (objetivo 20)';


--
-- Name: medico_id_medico_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.medico ALTER COLUMN id_medico ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.medico_id_medico_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: municipio; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.municipio (
    id_municipio integer NOT NULL,
    id_departamento integer NOT NULL,
    nombre character varying(100) NOT NULL
);


--
-- Name: TABLE municipio; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.municipio IS 'Catalogo de municipios; cada uno pertenece a un unico departamento';


--
-- Name: municipio_id_municipio_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.municipio ALTER COLUMN id_municipio ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.municipio_id_municipio_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: paciente; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.paciente (
    id_paciente integer NOT NULL,
    no_expediente character varying(20) NOT NULL,
    nombres character varying(100) NOT NULL,
    apellidos character varying(100) NOT NULL,
    sexo character(1) NOT NULL,
    fecha_nacimiento date NOT NULL,
    id_municipio integer NOT NULL,
    area character varying(10) NOT NULL,
    dpi character varying(13),
    telefono character varying(20),
    no_seguro_social character varying(20),
    CONSTRAINT chk_paciente_area CHECK (((area)::text = ANY ((ARRAY['Urbana'::character varying, 'Rural'::character varying])::text[]))),
    CONSTRAINT chk_paciente_fecha_nacimiento CHECK ((fecha_nacimiento <= CURRENT_DATE)),
    CONSTRAINT chk_paciente_sexo CHECK ((sexo = ANY (ARRAY['M'::bpchar, 'F'::bpchar])))
);


--
-- Name: TABLE paciente; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.paciente IS 'Paciente atendido en cualquier unidad de cualquier hospital de la cadena';


--
-- Name: paciente_id_paciente_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.paciente ALTER COLUMN id_paciente ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.paciente_id_paciente_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: personal; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.personal (
    id_personal integer NOT NULL,
    tipo_personal character varying(10) NOT NULL,
    nombre character varying(150) NOT NULL,
    dpi character varying(13) NOT NULL,
    fecha_contratacion date NOT NULL,
    telefono character varying(20),
    direccion character varying(200),
    CONSTRAINT chk_personal_dpi CHECK (((dpi)::text ~ '^[0-9]{13}$'::text)),
    CONSTRAINT chk_personal_fecha_contratacion CHECK ((fecha_contratacion <= CURRENT_DATE)),
    CONSTRAINT chk_personal_nombre CHECK ((length(btrim((nombre)::text)) > 0)),
    CONSTRAINT chk_personal_telefono CHECK (((telefono IS NULL) OR ((telefono)::text ~ '^[0-9]{8}$'::text))),
    CONSTRAINT chk_personal_tipo CHECK (((tipo_personal)::text = ANY ((ARRAY['Medico'::character varying, 'Enfermero'::character varying, 'Encargado'::character varying])::text[])))
);


--
-- Name: TABLE personal; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.personal IS 'Supertipo del personal del hospital: datos comunes de medicos, enfermeros y personal encargado';


--
-- Name: personal_encargado; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.personal_encargado (
    id_encargado integer NOT NULL,
    nombre character varying(150) NOT NULL,
    dpi character varying(13) NOT NULL,
    puesto character varying(100) NOT NULL,
    id_hospital integer NOT NULL,
    telefono character varying(20),
    id_personal integer NOT NULL,
    tipo_personal character varying(10) DEFAULT 'Encargado'::character varying NOT NULL,
    CONSTRAINT chk_encargado_tipo_personal CHECK (((tipo_personal)::text = 'Encargado'::text))
);


--
-- Name: TABLE personal_encargado; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.personal_encargado IS 'Personal administrativo/encargado de un hospital, sujeto de calificacion de calidad (distinto del responsable del paciente)';


--
-- Name: COLUMN personal_encargado.nombre; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.personal_encargado.nombre IS 'Espejo de personal.nombre (columna del Proyecto 1 conservada; la mantiene un trigger)';


--
-- Name: COLUMN personal_encargado.dpi; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.personal_encargado.dpi IS 'Espejo de personal.dpi (columna del Proyecto 1 conservada; la mantiene un trigger)';


--
-- Name: COLUMN personal_encargado.telefono; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.personal_encargado.telefono IS 'Espejo de personal.telefono (columna del Proyecto 1 conservada; la mantiene un trigger)';


--
-- Name: COLUMN personal_encargado.id_personal; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.personal_encargado.id_personal IS 'Enlace 1:1 con el supertipo personal';


--
-- Name: personal_encargado_id_encargado_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.personal_encargado ALTER COLUMN id_encargado ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.personal_encargado_id_encargado_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: personal_id_personal_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.personal ALTER COLUMN id_personal ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.personal_id_personal_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: quirofano; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.quirofano (
    id_quirofano integer NOT NULL,
    id_hospital integer NOT NULL,
    numero integer NOT NULL,
    estado character varying(10) DEFAULT 'Libre'::character varying NOT NULL,
    CONSTRAINT chk_quirofano_estado CHECK (((estado)::text = ANY ((ARRAY['Libre'::character varying, 'Ocupado'::character varying])::text[])))
);


--
-- Name: TABLE quirofano; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.quirofano IS 'Quirofano habilitado de un hospital (cada hospital cuenta con varios)';


--
-- Name: quirofano_id_quirofano_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.quirofano ALTER COLUMN id_quirofano ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.quirofano_id_quirofano_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: receta_medica; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.receta_medica (
    id_receta integer NOT NULL,
    id_consulta integer NOT NULL,
    fecha date NOT NULL,
    id_hospital integer NOT NULL,
    proxima_cita date,
    numero_clinica character varying(20)
);


--
-- Name: TABLE receta_medica; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.receta_medica IS 'Receta medica emitida al finalizar una consulta de Consulta Externa';


--
-- Name: receta_medica_id_receta_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.receta_medica ALTER COLUMN id_receta ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.receta_medica_id_receta_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: registro_procedimiento_cirugia; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.registro_procedimiento_cirugia (
    id_registro integer NOT NULL,
    id_cirugia integer NOT NULL,
    etapa character varying(15) NOT NULL,
    procedimiento character varying(150) NOT NULL,
    resultado character varying(25) NOT NULL,
    hora_registro timestamp without time zone NOT NULL,
    id_enfermero integer NOT NULL,
    descripcion text,
    CONSTRAINT chk_registro_etapa CHECK (((etapa)::text = ANY ((ARRAY['Preoperatorio'::character varying, 'Intraoperatorio'::character varying, 'Postoperatorio'::character varying])::text[]))),
    CONSTRAINT chk_registro_resultado CHECK (((resultado)::text = ANY ((ARRAY['Aceptable'::character varying, 'Medianamente aceptable'::character varying, 'No aceptable'::character varying, 'Exito'::character varying, 'Falla'::character varying])::text[])))
);


--
-- Name: TABLE registro_procedimiento_cirugia; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.registro_procedimiento_cirugia IS 'Registro normalizado de todos los checklists de la cirugia (preoperatorio, chequeo en quirofano, pausa quirurgica, cuidados intraoperatorios, salida, recuperacion, traslado seguro)';


--
-- Name: registro_procedimiento_cirugia_id_registro_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.registro_procedimiento_cirugia ALTER COLUMN id_registro ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.registro_procedimiento_cirugia_id_registro_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: requerimiento_equipo; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.requerimiento_equipo (
    id_solicitud integer NOT NULL,
    id_equipo integer NOT NULL,
    cantidad integer NOT NULL,
    CONSTRAINT chk_reqequipo_cantidad CHECK ((cantidad > 0))
);


--
-- Name: TABLE requerimiento_equipo; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.requerimiento_equipo IS 'Resuelve la relacion N:M entre solicitud_cirugia y equipo (llave primaria compuesta)';


--
-- Name: requerimiento_instrumento; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.requerimiento_instrumento (
    id_solicitud integer NOT NULL,
    id_instrumento integer NOT NULL,
    cantidad integer NOT NULL,
    CONSTRAINT chk_reqinstr_cantidad CHECK ((cantidad > 0))
);


--
-- Name: TABLE requerimiento_instrumento; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.requerimiento_instrumento IS 'Resuelve la relacion N:M entre solicitud_cirugia e instrumento (llave primaria compuesta)';


--
-- Name: requerimiento_insumo; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.requerimiento_insumo (
    id_solicitud integer NOT NULL,
    id_insumo integer NOT NULL,
    cantidad integer NOT NULL,
    CONSTRAINT chk_reqinsumo_cantidad CHECK ((cantidad > 0))
);


--
-- Name: TABLE requerimiento_insumo; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.requerimiento_insumo IS 'Resuelve la relacion N:M entre solicitud_cirugia e insumo (llave primaria compuesta)';


--
-- Name: responsable_paciente; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.responsable_paciente (
    id_responsable integer NOT NULL,
    id_paciente integer NOT NULL,
    nombre character varying(150) NOT NULL,
    parentesco character varying(50) NOT NULL,
    dpi character varying(13),
    telefono character varying(20),
    id_municipio integer,
    area character varying(10),
    CONSTRAINT chk_responsable_area CHECK (((area IS NULL) OR ((area)::text = ANY ((ARRAY['Urbana'::character varying, 'Rural'::character varying])::text[]))))
);


--
-- Name: TABLE responsable_paciente; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.responsable_paciente IS 'Familiar o responsable del paciente registrado en la ficha de ingreso (no es personal del hospital)';


--
-- Name: responsable_paciente_id_responsable_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.responsable_paciente ALTER COLUMN id_responsable ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.responsable_paciente_id_responsable_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: servicio_hospitalizacion; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.servicio_hospitalizacion (
    id_servicio integer NOT NULL,
    nombre character varying(100) NOT NULL
);


--
-- Name: TABLE servicio_hospitalizacion; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.servicio_hospitalizacion IS 'Catalogo de servicios de Hospitalizacion (Hematologia, Medicina interna, Neumologia, Oncologia, Ortopedia, Pediatria, cuidados intermedios, cuidado critico)';


--
-- Name: servicio_hospitalizacion_id_servicio_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.servicio_hospitalizacion ALTER COLUMN id_servicio ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.servicio_hospitalizacion_id_servicio_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: solicitud_cirugia; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.solicitud_cirugia (
    id_solicitud integer NOT NULL,
    id_paciente integer NOT NULL,
    id_cirujano integer NOT NULL,
    caracter character varying(15) NOT NULL,
    tipo_procedimiento character varying(150) NOT NULL,
    fecha_hora_solicitud timestamp without time zone NOT NULL,
    estado character varying(15) DEFAULT 'Pendiente'::character varying NOT NULL,
    id_hospital integer NOT NULL,
    historia_clinica text,
    tiempo_estimado interval,
    tipo_anestesia character varying(100),
    motivo_rechazo text,
    id_quirofano integer,
    fecha_hora_agendada timestamp without time zone,
    CONSTRAINT chk_solicitud_caracter CHECK (((caracter)::text = ANY ((ARRAY['Urgente'::character varying, 'Programado'::character varying])::text[]))),
    CONSTRAINT chk_solicitud_estado CHECK (((estado)::text = ANY ((ARRAY['Pendiente'::character varying, 'Aprobada'::character varying, 'Rechazada'::character varying])::text[]))),
    CONSTRAINT chk_solicitud_motivo_rechazo CHECK (((((estado)::text = 'Rechazada'::text) AND (motivo_rechazo IS NOT NULL)) OR (((estado)::text <> 'Rechazada'::text) AND (motivo_rechazo IS NULL))))
);


--
-- Name: TABLE solicitud_cirugia; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.solicitud_cirugia IS 'Agendamiento quirurgico solicitado por el cirujano, revisado por el comite medico';


--
-- Name: solicitud_cirugia_id_solicitud_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.solicitud_cirugia ALTER COLUMN id_solicitud ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.solicitud_cirugia_id_solicitud_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: traslado; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.traslado (
    id_traslado integer NOT NULL,
    id_paciente integer NOT NULL,
    id_medico_indica integer NOT NULL,
    fecha_hora timestamp without time zone NOT NULL,
    id_unidad_destino integer NOT NULL,
    interno_destino boolean NOT NULL,
    id_unidad_origen integer,
    interno_origen boolean
);


--
-- Name: TABLE traslado; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.traslado IS 'Ficha de traslado de un paciente entre unidades (o desde/hacia otra institucion)';


--
-- Name: traslado_id_traslado_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.traslado ALTER COLUMN id_traslado ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.traslado_id_traslado_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: turno_laboral; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.turno_laboral (
    id_turno_laboral integer NOT NULL,
    id_medico integer NOT NULL,
    id_unidad_hospital integer NOT NULL,
    fecha_hora_inicio timestamp without time zone NOT NULL,
    fecha_hora_fin timestamp without time zone NOT NULL,
    turno character varying(10) GENERATED ALWAYS AS (public.turno_de_hora(fecha_hora_inicio)) STORED,
    CONSTRAINT chk_turno_duracion CHECK (((fecha_hora_fin - fecha_hora_inicio) <= '24:00:00'::interval)),
    CONSTRAINT chk_turno_fin_posterior CHECK ((fecha_hora_fin > fecha_hora_inicio)),
    CONSTRAINT chk_turno_nombre CHECK (((turno)::text = ANY ((ARRAY['Matutino'::character varying, 'Vespertino'::character varying, 'Nocturno'::character varying])::text[])))
);


--
-- Name: TABLE turno_laboral; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.turno_laboral IS 'Turno trabajado por un medico en una unidad de su hospital; base de las horas y turnos laborados';


--
-- Name: turno_laboral_id_turno_laboral_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.turno_laboral ALTER COLUMN id_turno_laboral ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.turno_laboral_id_turno_laboral_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: unidad_hospital; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.unidad_hospital (
    id_unidad_hospital integer NOT NULL,
    id_hospital integer NOT NULL,
    tipo_unidad character varying(20) NOT NULL,
    CONSTRAINT chk_unidadhosp_tipo CHECK (((tipo_unidad)::text = ANY ((ARRAY['Emergencias'::character varying, 'Cirugia'::character varying, 'Hospitalizacion'::character varying])::text[])))
);


--
-- Name: TABLE unidad_hospital; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.unidad_hospital IS 'Unidad medica (Emergencias/Cirugia/Hospitalizacion) concreta de un hospital especifico';


--
-- Name: unidad_hospital_id_unidad_hospital_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.unidad_hospital ALTER COLUMN id_unidad_hospital ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.unidad_hospital_id_unidad_hospital_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Data for Name: cirugia; Type: TABLE DATA; Schema: propuesta_cirugia; Owner: -
--

COPY propuesta_cirugia.cirugia (id_cirugia, id_cirujano, id_paciente, codigo_diagnostico, fecha) FROM stdin;
2	2	1	K40.9	2026-09-25
5	2	2	K80.2	2026-10-08
3	3	3	K35.8	2026-10-02
6	1	4	S82.2	2026-10-12
1	2	5	K35.8	2026-09-20
4	1	6	S82.2	2026-10-05
\.


--
-- Data for Name: cirugia_insumo; Type: TABLE DATA; Schema: propuesta_cirugia; Owner: -
--

COPY propuesta_cirugia.cirugia_insumo (id_cirugia, id_insumo, cantidad) FROM stdin;
3	1	1
5	2	12
2	2	8
1	2	10
4	3	4
6	4	3
5	1	2
3	2	6
6	3	6
1	4	2
\.


--
-- Data for Name: cirujano; Type: TABLE DATA; Schema: propuesta_cirugia; Owner: -
--

COPY propuesta_cirugia.cirujano (id_cirujano, nombre, id_especialidad) FROM stdin;
1	Dr. Byron Estuardo Giron Cotzojay	2
2	Dr. Julio Cesar Argueta Giron	1
3	Dr. Rigoberto Tepaz Chocoj	1
\.


--
-- Data for Name: diagnostico; Type: TABLE DATA; Schema: propuesta_cirugia; Owner: -
--

COPY propuesta_cirugia.diagnostico (codigo, descripcion) FROM stdin;
K40.9	Hernia inguinal
K35.8	Apendicitis aguda
K80.2	Colelitiasis
S82.2	Fractura de tibia
\.


--
-- Data for Name: especialidad; Type: TABLE DATA; Schema: propuesta_cirugia; Owner: -
--

COPY propuesta_cirugia.especialidad (id_especialidad, nombre) FROM stdin;
1	Cirugia General
2	Cirugia Ortopedica
\.


--
-- Data for Name: insumo; Type: TABLE DATA; Schema: propuesta_cirugia; Owner: -
--

COPY propuesta_cirugia.insumo (id_insumo, nombre) FROM stdin;
1	Sutura Vicryl
2	Gasas esteriles
3	Guantes esteriles
4	Suero fisiologico
\.


--
-- Data for Name: paciente; Type: TABLE DATA; Schema: propuesta_cirugia; Owner: -
--

COPY propuesta_cirugia.paciente (id_paciente, nombre) FROM stdin;
1	Ana Lucia Marroquin Giron
2	Rosa Elvira Tepaz Batz
3	Pedro Cotzojay Ixcoy
4	Maria Xitumul Tzul
5	Jose Manuel Garcia Lopez
6	Carlos Alberto Morales Ramirez
\.


--
-- Data for Name: reporte_cirugia_original; Type: TABLE DATA; Schema: propuesta_cirugia; Owner: -
--

COPY propuesta_cirugia.reporte_cirugia_original (id_cirugia, nombre_cirujano, especialidad_cirujano, nombre_paciente, codigo_diagnostico, descripcion_diagnostico, nombre_insumo_1, cantidad_insumo_1, nombre_insumo_2, cantidad_insumo_2, fecha) FROM stdin;
1	Dr. Julio Cesar Argueta Giron	Cirugia General	Jose Manuel Garcia Lopez	K35.8	Apendicitis aguda	Gasas esteriles	10	Suero fisiologico	2	2026-09-20
2	Dr. Julio Cesar Argueta Giron	Cirugia General	Ana Lucia Marroquin Giron	K40.9	Hernia inguinal	Gasas esteriles	8	\N	\N	2026-09-25
3	Dr. Rigoberto Tepaz Chocoj	Cirugia General	Pedro Cotzojay Ixcoy	K35.8	Apendicitis aguda	Sutura Vicryl	1	Gasas esteriles	6	2026-10-02
4	Dr. Byron Estuardo Giron Cotzojay	Cirugia Ortopedica	Carlos Alberto Morales Ramirez	S82.2	Fractura de tibia	Guantes esteriles	4	\N	\N	2026-10-05
5	Dr. Julio Cesar Argueta Giron	Cirugia General	Rosa Elvira Tepaz Batz	K80.2	Colelitiasis	Gasas esteriles	12	Sutura Vicryl	2	2026-10-08
6	Dr. Byron Estuardo Giron Cotzojay	Cirugia Ortopedica	Maria Xitumul Tzul	S82.2	Fractura de tibia	Suero fisiologico	3	Guantes esteriles	6	2026-10-12
\.


--
-- Data for Name: auditoria_medico; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.auditoria_medico (id_auditoria, id_medico, campo, valor_anterior, valor_nuevo, usuario_bd, fecha_hora) FROM stdin;
1	11	salario	8900.00	9790.00	usr_admin_bd	2026-10-25 12:22:46.37486-06
2	14	nivel_acceso	Basico	Avanzado	usr_admin_bd	2026-10-25 12:22:46.376801-06
3	24	salario	9800.00	10500.00	usr_admin_bd	2026-10-25 12:22:46.377916-06
4	24	id_especialidad	7	1	usr_admin_bd	2026-10-25 12:22:46.378119-06
\.


--
-- Data for Name: calificacion_enfermero; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.calificacion_enfermero (id_calificacion, id_enfermero, puntaje, fecha, id_paciente, comentario) FROM stdin;
1	1	4	2026-09-23	2	Muy atenta durante la recuperacion postoperatoria
2	1	3	2026-08-04	20	\N
3	5	4	2026-10-16	7	\N
4	11	4	2026-09-30	19	\N
5	13	2	2026-09-29	10	\N
6	14	2	2026-08-18	10	\N
7	3	2	2026-09-15	24	\N
8	8	4	2026-09-02	15	\N
9	10	3	2026-08-15	25	\N
10	12	2	2026-10-10	1	\N
11	15	3	2026-10-03	26	\N
12	2	3	2026-10-17	12	\N
13	9	3	2026-09-15	2	\N
14	6	3	2026-10-03	29	\N
15	13	5	2026-09-02	10	\N
16	14	4	2026-08-22	4	\N
17	1	4	2026-10-12	14	\N
18	4	5	2026-09-01	18	\N
19	11	4	2026-09-24	11	\N
20	12	4	2026-10-16	29	\N
21	15	4	2026-08-06	10	\N
22	3	3	2026-09-27	14	\N
23	5	4	2026-08-12	24	\N
\.


--
-- Data for Name: calificacion_hospital; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.calificacion_hospital (id_calificacion, id_hospital, puntaje, fecha, id_paciente, comentario) FROM stdin;
1	1	5	2026-09-23	2	Excelente atencion durante la cirugia de emergencia
2	1	4	2026-08-01	22	\N
3	2	3	2026-10-13	4	\N
4	3	2	2026-09-17	7	\N
5	4	5	2026-10-04	16	\N
6	5	5	2026-08-03	15	\N
7	1	3	2026-09-03	23	\N
8	2	3	2026-10-24	7	\N
9	3	4	2026-08-11	15	\N
10	4	4	2026-08-30	14	\N
11	5	4	2026-08-24	29	\N
12	1	3	2026-10-03	22	\N
13	2	4	2026-09-11	24	\N
14	3	4	2026-09-24	11	\N
15	4	5	2026-10-03	5	\N
16	5	5	2026-09-23	27	\N
17	1	5	2026-08-18	2	\N
18	2	4	2026-10-24	27	\N
19	3	4	2026-08-24	15	\N
20	4	5	2026-10-16	15	\N
21	5	4	2026-09-24	13	\N
22	1	5	2026-09-24	20	\N
23	2	2	2026-10-15	22	\N
24	3	3	2026-10-01	25	\N
25	4	5	2026-10-09	19	\N
26	5	5	2026-08-13	19	\N
\.


--
-- Data for Name: calificacion_medico; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.calificacion_medico (id_calificacion, id_medico, puntaje, fecha, id_paciente, comentario) FROM stdin;
1	6	5	2026-09-23	2	El cirujano explico todo el procedimiento con claridad
2	17	4	2026-08-01	23	Buena atencion y trato amable
3	22	5	2026-08-01	11	Excelente atencion, muy profesional
4	3	5	2026-08-02	6	Excelente atencion, muy profesional
5	25	4	2026-08-02	19	Buena atencion y trato amable
6	25	3	2026-08-02	9	Atencion regular
7	27	2	2026-08-03	12	Larga espera y poca claridad
8	24	3	2026-08-05	24	Atencion regular
9	28	2	2026-08-05	20	Larga espera y poca claridad
10	8	3	2026-08-06	16	Atencion regular
11	22	3	2026-08-07	11	Atencion regular
12	25	4	2026-08-07	18	Buena atencion y trato amable
13	2	4	2026-08-08	24	Buena atencion y trato amable
14	31	3	2026-08-08	7	Atencion regular
15	6	2	2026-08-09	13	Larga espera y poca claridad
16	7	4	2026-08-10	19	Buena atencion y trato amable
17	12	2	2026-08-10	10	Larga espera y poca claridad
18	18	5	2026-08-10	2	Excelente atencion, muy profesional
19	13	3	2026-08-12	29	Atencion regular
20	18	3	2026-08-12	27	Atencion regular
21	27	2	2026-08-12	17	Larga espera y poca claridad
22	31	3	2026-08-13	11	Atencion regular
23	29	2	2026-08-13	18	Larga espera y poca claridad
24	32	4	2026-08-13	16	Buena atencion y trato amable
25	2	5	2026-08-15	17	Excelente atencion, muy profesional
26	4	3	2026-08-15	28	Atencion regular
27	19	3	2026-08-15	30	Atencion regular
28	22	5	2026-08-15	22	Excelente atencion, muy profesional
29	10	5	2026-08-16	16	Excelente atencion, muy profesional
30	5	3	2026-08-16	24	Atencion regular
31	5	2	2026-08-16	4	Larga espera y poca claridad
32	30	5	2026-08-16	15	Excelente atencion, muy profesional
33	25	4	2026-08-17	14	Buena atencion y trato amable
34	7	3	2026-08-18	1	Atencion regular
35	7	3	2026-08-18	20	Atencion regular
36	16	5	2026-08-18	12	Excelente atencion, muy profesional
37	16	3	2026-08-19	13	Atencion regular
38	27	3	2026-08-20	14	Atencion regular
39	25	4	2026-08-21	16	Buena atencion y trato amable
40	14	3	2026-08-22	25	Atencion regular
41	20	3	2026-08-22	5	Atencion regular
42	17	4	2026-08-22	8	Buena atencion y trato amable
43	23	2	2026-08-22	11	Larga espera y poca claridad
44	24	4	2026-08-24	26	Buena atencion y trato amable
45	12	3	2026-08-25	13	Atencion regular
46	21	2	2026-08-25	23	Larga espera y poca claridad
47	27	2	2026-08-25	17	Larga espera y poca claridad
48	29	2	2026-08-25	15	Larga espera y poca claridad
49	29	2	2026-08-25	1	Larga espera y poca claridad
50	8	2	2026-08-27	25	Larga espera y poca claridad
51	15	3	2026-08-27	27	Atencion regular
52	17	4	2026-08-27	1	Buena atencion y trato amable
53	25	4	2026-08-27	4	Buena atencion y trato amable
54	22	5	2026-08-28	1	Excelente atencion, muy profesional
55	27	4	2026-08-29	27	Buena atencion y trato amable
56	1	2	2026-08-30	21	Larga espera y poca claridad
57	18	4	2026-08-31	12	Buena atencion y trato amable
58	19	4	2026-08-31	26	Buena atencion y trato amable
59	24	2	2026-08-31	15	Larga espera y poca claridad
60	32	4	2026-08-31	7	Buena atencion y trato amable
61	31	4	2026-09-01	30	Buena atencion y trato amable
62	14	3	2026-09-02	28	Atencion regular
63	29	4	2026-09-02	13	Buena atencion y trato amable
64	19	3	2026-09-03	10	Atencion regular
65	1	3	2026-09-04	3	Atencion regular
66	1	3	2026-09-04	7	Atencion regular
67	14	4	2026-09-04	12	Buena atencion y trato amable
68	20	3	2026-09-04	17	Atencion regular
69	2	5	2026-09-05	23	Excelente atencion, muy profesional
70	5	1	2026-09-05	11	Atencion deficiente, no explico el tratamiento
71	31	4	2026-09-06	16	Buena atencion y trato amable
72	29	2	2026-09-06	25	Larga espera y poca claridad
73	11	2	2026-09-07	21	Larga espera y poca claridad
74	9	3	2026-09-07	23	Atencion regular
75	9	3	2026-09-07	3	Atencion regular
76	25	5	2026-09-07	8	Excelente atencion, muy profesional
77	31	4	2026-09-07	29	Buena atencion y trato amable
78	6	2	2026-09-08	29	Larga espera y poca claridad
79	4	4	2026-09-08	12	Buena atencion y trato amable
80	13	3	2026-09-08	27	Atencion regular
81	16	4	2026-09-08	21	Buena atencion y trato amable
82	1	2	2026-09-09	24	Larga espera y poca claridad
83	12	4	2026-09-09	16	Buena atencion y trato amable
84	10	4	2026-09-10	16	Buena atencion y trato amable
85	8	2	2026-09-10	17	Larga espera y poca claridad
86	32	2	2026-09-10	10	Larga espera y poca claridad
87	5	3	2026-09-11	19	Atencion regular
88	9	2	2026-09-11	18	Larga espera y poca claridad
89	19	3	2026-09-11	8	Atencion regular
90	26	4	2026-09-11	5	Buena atencion y trato amable
91	3	4	2026-09-12	27	Buena atencion y trato amable
92	4	1	2026-09-13	23	Atencion deficiente, no explico el tratamiento
93	17	4	2026-09-13	9	Buena atencion y trato amable
94	17	5	2026-09-13	28	Excelente atencion, muy profesional
95	19	3	2026-09-14	3	Atencion regular
96	18	2	2026-09-15	24	Larga espera y poca claridad
97	18	4	2026-09-16	5	Buena atencion y trato amable
98	20	2	2026-09-16	11	Larga espera y poca claridad
99	21	4	2026-09-16	20	Buena atencion y trato amable
100	11	2	2026-09-17	12	Larga espera y poca claridad
101	2	4	2026-09-18	15	Buena atencion y trato amable
102	30	5	2026-09-18	29	Excelente atencion, muy profesional
103	31	4	2026-09-18	2	Buena atencion y trato amable
104	4	3	2026-09-19	19	Atencion regular
105	16	3	2026-09-19	6	Atencion regular
106	29	2	2026-09-19	22	Larga espera y poca claridad
107	16	4	2026-09-20	29	Buena atencion y trato amable
108	3	4	2026-09-21	10	Buena atencion y trato amable
109	10	4	2026-09-21	25	Buena atencion y trato amable
110	12	4	2026-09-21	16	Buena atencion y trato amable
111	22	4	2026-09-21	4	Buena atencion y trato amable
112	23	3	2026-09-21	3	Atencion regular
113	7	3	2026-09-22	21	Atencion regular
114	21	4	2026-09-22	3	Buena atencion y trato amable
115	22	4	2026-09-22	17	Buena atencion y trato amable
116	15	4	2026-09-23	9	Buena atencion y trato amable
117	1	5	2026-09-24	20	Excelente atencion, muy profesional
118	10	3	2026-09-26	18	Atencion regular
119	19	3	2026-09-26	12	Atencion regular
120	31	5	2026-09-26	11	Excelente atencion, muy profesional
121	14	3	2026-09-27	9	Atencion regular
122	20	3	2026-09-27	3	Atencion regular
123	20	3	2026-09-27	25	Atencion regular
124	28	2	2026-09-27	16	Larga espera y poca claridad
125	28	5	2026-09-27	11	Excelente atencion, muy profesional
126	30	4	2026-09-27	20	Buena atencion y trato amable
127	30	5	2026-09-27	17	Excelente atencion, muy profesional
128	25	4	2026-09-29	8	Buena atencion y trato amable
129	16	2	2026-09-30	3	Larga espera y poca claridad
130	26	3	2026-10-01	13	Atencion regular
131	30	5	2026-10-01	13	Excelente atencion, muy profesional
132	11	2	2026-10-02	2	Larga espera y poca claridad
133	14	5	2026-10-02	16	Excelente atencion, muy profesional
134	23	2	2026-10-02	6	Larga espera y poca claridad
135	10	5	2026-10-03	17	Excelente atencion, muy profesional
136	28	4	2026-10-03	1	Buena atencion y trato amable
137	3	5	2026-10-04	27	Excelente atencion, muy profesional
138	11	1	2026-10-04	11	Atencion deficiente, no explico el tratamiento
139	13	3	2026-10-05	29	Atencion regular
140	20	3	2026-10-05	8	Atencion regular
141	27	3	2026-10-05	24	Atencion regular
142	10	5	2026-10-06	17	Excelente atencion, muy profesional
143	6	1	2026-10-06	15	Atencion deficiente, no explico el tratamiento
144	6	3	2026-10-06	29	Atencion regular
145	4	3	2026-10-07	7	Atencion regular
146	2	5	2026-10-08	4	Excelente atencion, muy profesional
147	20	3	2026-10-08	17	Atencion regular
148	21	2	2026-10-09	3	Larga espera y poca claridad
149	3	5	2026-10-10	1	Excelente atencion, muy profesional
150	14	5	2026-10-10	29	Excelente atencion, muy profesional
151	24	2	2026-10-11	26	Larga espera y poca claridad
152	21	3	2026-10-12	11	Atencion regular
153	15	3	2026-10-13	25	Atencion regular
154	31	4	2026-10-13	14	Buena atencion y trato amable
155	1	3	2026-10-14	22	Atencion regular
156	18	3	2026-10-14	10	Atencion regular
157	30	5	2026-10-14	22	Excelente atencion, muy profesional
158	17	4	2026-10-15	17	Buena atencion y trato amable
159	21	3	2026-10-16	29	Atencion regular
160	4	3	2026-10-18	7	Atencion regular
161	9	3	2026-10-18	11	Atencion regular
162	18	4	2026-10-18	30	Buena atencion y trato amable
163	3	5	2026-10-20	15	Excelente atencion, muy profesional
164	20	5	2026-10-20	2	Excelente atencion, muy profesional
165	1	4	2026-10-21	11	Buena atencion y trato amable
166	11	1	2026-10-21	14	Atencion deficiente, no explico el tratamiento
167	21	2	2026-10-21	7	Larga espera y poca claridad
168	10	3	2026-10-22	12	Atencion regular
169	26	4	2026-10-22	11	Buena atencion y trato amable
170	1	3	2026-10-23	9	Atencion regular
171	22	5	2026-10-23	8	Excelente atencion, muy profesional
172	22	5	2026-10-24	16	Excelente atencion, muy profesional
\.


--
-- Data for Name: calificacion_personal_encargado; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.calificacion_personal_encargado (id_calificacion, id_encargado, puntaje, fecha, id_paciente, comentario) FROM stdin;
1	1	4	2026-09-10	1	Buena atencion en la recepcion del hospital
2	1	4	2026-09-02	25	\N
3	6	5	2026-10-16	22	\N
4	9	2	2026-10-15	4	\N
5	10	3	2026-09-20	6	\N
6	14	4	2026-09-19	23	\N
7	5	4	2026-08-24	10	\N
8	3	3	2026-09-27	26	\N
9	8	3	2026-10-22	1	\N
10	12	2	2026-10-03	10	\N
11	13	4	2026-09-13	24	\N
12	2	4	2026-08-17	18	\N
13	7	5	2026-10-24	24	\N
14	4	2	2026-09-03	23	\N
15	11	2	2026-09-11	5	\N
16	15	5	2026-09-13	30	\N
17	1	5	2026-08-04	21	\N
18	6	4	2026-09-11	3	\N
19	9	4	2026-10-13	15	\N
20	10	4	2026-08-26	10	\N
21	14	4	2026-08-27	18	\N
22	5	5	2026-08-11	13	\N
23	3	4	2026-10-09	7	\N
\.


--
-- Data for Name: camilla; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.camilla (id_camilla, id_unidad_hospital, numero, estado) FROM stdin;
1	1	1	Ocupada
2	1	2	Libre
3	3	1	Ocupada
4	3	2	Ocupada
5	6	1	Libre
6	4	1	Ocupada
7	1	3	Libre
8	1	4	Libre
9	3	3	Libre
10	3	4	Libre
11	4	2	Libre
12	4	3	Libre
13	4	4	Libre
14	6	2	Libre
15	6	3	Libre
16	6	4	Libre
17	7	1	Libre
18	7	2	Libre
19	7	3	Libre
20	7	4	Libre
21	9	1	Libre
22	9	2	Libre
23	9	3	Libre
24	9	4	Libre
25	10	1	Libre
26	10	2	Libre
27	10	3	Libre
28	10	4	Libre
29	12	1	Libre
30	12	2	Libre
31	12	3	Libre
32	12	4	Libre
33	13	1	Libre
34	13	2	Libre
35	13	3	Libre
36	13	4	Libre
37	15	1	Libre
38	15	2	Libre
39	15	3	Libre
40	15	4	Libre
\.


--
-- Data for Name: chequeo_preanestesico; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.chequeo_preanestesico (id_chequeo, id_solicitud, clasificacion_asa, id_medico_clasifica, id_anestesista, plan_anestesia) FROM stdin;
1	1	II	6	8	Anestesia general balanceada
2	3	II	29	31	Anestesia regional
3	4	I	6	3	Anestesia general
4	5	III	17	18	Anestesia general
5	6	II	6	10	Anestesia general
6	7	III	8	3	Anestesia regional
7	8	I	7	1	Anestesia regional
8	9	I	13	14	Anestesia regional
9	10	II	8	10	Anestesia local
10	11	II	32	31	Anestesia regional
11	12	I	13	4	Anestesia general
12	13	II	6	10	Anestesia regional
13	14	III	13	14	Anestesia local
14	15	II	26	25	Anestesia general
15	16	I	8	11	Anestesia general
16	17	III	19	9	Anestesia regional
17	18	II	29	27	Anestesia regional
18	19	II	8	2	Anestesia regional
19	20	I	6	11	Anestesia regional
\.


--
-- Data for Name: cirugia; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.cirugia (id_cirugia, id_solicitud, id_ingreso, id_quirofano, id_enfermero_encargado, fecha_hora_inicio, fecha_hora_fin, costo) FROM stdin;
1	1	2	1	1	2026-09-20 16:15:00	2026-09-20 17:45:00	3500.00
2	3	86	9	14	2026-08-07 10:35:00	2026-08-07 12:26:00	5610.00
3	4	89	1	3	2026-08-10 12:35:00	2026-08-10 14:00:00	4100.00
4	5	92	5	6	2026-08-11 10:20:00	2026-08-11 12:11:00	3180.00
5	6	95	2	1	2026-08-12 01:50:00	2026-08-12 03:31:00	3610.00
6	7	97	1	1	2026-08-13 07:35:00	2026-08-13 09:32:00	4770.00
7	8	99	1	3	2026-08-13 11:20:00	2026-08-13 13:02:00	8580.00
8	9	100	3	9	2026-08-14 08:20:00	2026-08-14 10:05:00	5760.00
9	10	103	1	2	2026-08-22 17:50:00	2026-08-22 18:56:00	1830.00
10	11	105	9	15	2026-08-24 08:20:00	2026-08-24 10:04:00	7390.00
11	12	108	3	5	2026-09-05 18:05:00	2026-09-05 19:39:00	3930.00
12	13	110	2	1	2026-09-08 08:05:00	2026-09-08 09:40:00	5620.00
13	14	113	4	8	2026-09-10 17:35:00	2026-09-10 18:25:00	2080.00
14	15	116	8	13	2026-09-14 22:50:00	2026-09-15 00:43:00	7890.00
15	16	118	1	1	2026-09-16 07:50:00	2026-09-16 11:09:00	11910.00
16	17	121	5	6	2026-09-29 00:35:00	2026-09-29 03:25:00	9100.00
17	18	123	9	15	2026-09-28 10:50:00	2026-09-28 12:46:00	5430.00
18	19	125	2	2	2026-09-29 10:50:00	2026-09-29 12:26:00	4600.00
19	20	127	2	1	2026-10-12 07:35:00	2026-10-12 09:11:00	4560.00
\.


--
-- Data for Name: cita_programada; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.cita_programada (id_cita, id_paciente, id_medico, fecha, hora, estado, consultorio) FROM stdin;
1	1	1	2026-09-10	08:00:00	Realizada	Clinica 3
2	4	3	2026-09-15	09:30:00	Realizada	Clinica 5
3	8	2	2026-09-30	10:00:00	Programada	Clinica 2
4	5	1	2026-09-12	11:00:00	Cancelada	Clinica 3
5	5	10	2026-08-02	09:00:00	Realizada	Clinica 5
6	13	4	2026-08-07	13:30:00	Reprogramada	Clinica 5
7	6	10	2026-08-08	13:30:00	Realizada	Clinica 5
8	18	11	2026-08-11	11:00:00	Reprogramada	Clinica 6
9	22	18	2026-08-13	12:00:00	Realizada	Clinica 1
10	10	12	2026-08-16	12:30:00	Cancelada	Clinica 1
11	17	24	2026-08-20	11:00:00	Realizada	Clinica 1
12	3	30	2026-08-21	10:00:00	Realizada	Clinica 1
13	10	4	2026-08-21	12:00:00	Reprogramada	Clinica 5
14	1	5	2026-08-21	13:30:00	Realizada	Clinica 6
15	10	31	2026-08-23	12:00:00	Realizada	Clinica 2
16	9	15	2026-08-24	14:30:00	Realizada	Clinica 4
17	18	9	2026-08-26	10:30:00	Realizada	Clinica 4
18	14	1	2026-09-02	14:30:00	Cancelada	Clinica 2
19	14	25	2026-09-04	08:00:00	Realizada	Clinica 2
20	2	11	2026-09-04	13:30:00	Cancelada	Clinica 6
21	26	15	2026-09-05	09:30:00	Realizada	Clinica 4
22	4	27	2026-09-09	09:30:00	Realizada	Clinica 4
23	18	24	2026-09-09	15:30:00	Realizada	Clinica 1
24	1	21	2026-09-11	12:30:00	Realizada	Clinica 4
25	10	20	2026-09-11	15:30:00	Realizada	Clinica 3
26	7	11	2026-09-13	15:00:00	Realizada	Clinica 6
27	19	11	2026-09-14	13:00:00	Reprogramada	Clinica 6
28	22	20	2026-09-17	12:00:00	Cancelada	Clinica 3
29	2	12	2026-09-25	08:00:00	Cancelada	Clinica 1
30	30	11	2026-09-27	11:00:00	Cancelada	Clinica 6
31	27	21	2026-09-28	09:30:00	Realizada	Clinica 4
32	1	28	2026-09-28	13:00:00	Reprogramada	Clinica 5
33	15	11	2026-10-02	13:30:00	Cancelada	Clinica 6
34	23	30	2026-10-05	15:30:00	Realizada	Clinica 1
35	13	2	2026-10-08	14:30:00	Realizada	Clinica 3
36	16	4	2026-10-13	10:30:00	Reprogramada	Clinica 5
37	18	22	2026-10-15	10:00:00	Realizada	Clinica 5
38	30	21	2026-10-17	11:00:00	Realizada	Clinica 4
39	28	16	2026-10-20	15:00:00	Reprogramada	Clinica 5
40	5	9	2026-11-01	10:00:00	Programada	Clinica 4
41	4	16	2026-11-03	11:00:00	Programada	Clinica 5
42	3	31	2026-11-10	13:30:00	Programada	Clinica 2
43	21	22	2026-11-11	13:00:00	Programada	Clinica 5
44	22	3	2026-11-19	15:30:00	Programada	Clinica 4
\.


--
-- Data for Name: consentimiento_informado; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.consentimiento_informado (id_consentimiento, id_solicitud, nombre_procedimiento, objetivo, id_medico, firma_paciente, fecha, caracteristicas, riesgos) FROM stdin;
1	1	Apendicectomia convencional	Extirpar el apendice inflamado para evitar complicaciones	6	Jose Manuel Garcia Lopez	2026-09-20	Cirugia abierta bajo anestesia general	Sangrado, infeccion, reaccion anestesica
2	3	Hernioplastia inguinal	Realizar hernioplastia inguinal para resolver el cuadro clinico	29	Andres Jorge Vail Garcia	2026-08-01	Procedimiento bajo anestesia regional	Sangrado, infeccion, reaccion anestesica
3	4	Apendicectomia convencional	Realizar apendicectomia convencional para resolver el cuadro clinico	6	Rosa Elvira Tepaz Batz	2026-08-10	Procedimiento bajo anestesia general	Sangrado, infeccion, reaccion anestesica
4	5	Apendicectomia convencional	Realizar apendicectomia convencional para resolver el cuadro clinico	17	Hugo Oscar Us Lopez	2026-08-11	Procedimiento bajo anestesia general	Sangrado, infeccion, reaccion anestesica
5	6	Apendicectomia convencional	Realizar apendicectomia convencional para resolver el cuadro clinico	6	Carlos Alberto Morales Ramirez	2026-08-12	Procedimiento bajo anestesia general	Sangrado, infeccion, reaccion anestesica
6	7	Hernioplastia inguinal	Realizar hernioplastia inguinal para resolver el cuadro clinico	8	Ana Lucia Marroquin Giron	2026-08-09	Procedimiento bajo anestesia regional	Sangrado, infeccion, reaccion anestesica
7	8	Artroscopia de rodilla	Realizar artroscopia de rodilla para resolver el cuadro clinico	7	Andres Jorge Cabrera Ixcoy	2026-08-09	Procedimiento bajo anestesia regional	Sangrado, infeccion, reaccion anestesica
8	9	Hernioplastia inguinal	Realizar hernioplastia inguinal para resolver el cuadro clinico	13	Jose Manuel Garcia Lopez	2026-08-11	Procedimiento bajo anestesia regional	Sangrado, infeccion, reaccion anestesica
9	10	Drenaje de absceso	Realizar drenaje de absceso para resolver el cuadro clinico	8	Gloria Julia Alvarado Us	2026-08-22	Procedimiento bajo anestesia local	Sangrado, infeccion, reaccion anestesica
10	11	Artroscopia de rodilla	Realizar artroscopia de rodilla para resolver el cuadro clinico	32	Gloria Julia Alvarado Us	2026-08-22	Procedimiento bajo anestesia regional	Sangrado, infeccion, reaccion anestesica
11	12	Apendicectomia convencional	Realizar apendicectomia convencional para resolver el cuadro clinico	13	Teresa Patricia Ixcoy Batz	2026-09-05	Procedimiento bajo anestesia general	Sangrado, infeccion, reaccion anestesica
12	13	Hernioplastia inguinal	Realizar hernioplastia inguinal para resolver el cuadro clinico	6	Carlos Alberto Morales Ramirez	2026-09-06	Procedimiento bajo anestesia regional	Sangrado, infeccion, reaccion anestesica
13	14	Drenaje de absceso	Realizar drenaje de absceso para resolver el cuadro clinico	13	Andres Jorge Vail Garcia	2026-09-10	Procedimiento bajo anestesia local	Sangrado, infeccion, reaccion anestesica
14	15	Colecistectomia laparoscopica	Realizar colecistectomia laparoscopica para resolver el cuadro clinico	26	Rosa Lucia Ixcoy Cabrera	2026-09-14	Procedimiento bajo anestesia general	Sangrado, infeccion, reaccion anestesica
15	16	Laparotomia exploradora	Realizar laparotomia exploradora para resolver el cuadro clinico	8	Gloria Julia Giron Morales	2026-09-16	Procedimiento bajo anestesia general	Sangrado, infeccion, reaccion anestesica
16	17	Reduccion abierta de fractura de tibia	Realizar reduccion abierta de fractura de tibia para resolver el cuadro clinico	19	Pedro Carlos Vail Cotzojay	2026-09-28	Procedimiento bajo anestesia regional	Sangrado, infeccion, reaccion anestesica
17	18	Hernioplastia inguinal	Realizar hernioplastia inguinal para resolver el cuadro clinico	29	Sofia Marta Garcia Xitumul	2026-09-22	Procedimiento bajo anestesia regional	Sangrado, infeccion, reaccion anestesica
18	19	Hernioplastia inguinal	Realizar hernioplastia inguinal para resolver el cuadro clinico	8	Jose Manuel Garcia Lopez	2026-09-26	Procedimiento bajo anestesia regional	Sangrado, infeccion, reaccion anestesica
19	20	Hernioplastia inguinal	Realizar hernioplastia inguinal para resolver el cuadro clinico	6	Miguel Angel De Leon Argueta	2026-10-08	Procedimiento bajo anestesia regional	Sangrado, infeccion, reaccion anestesica
\.


--
-- Data for Name: consulta_paciente; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.consulta_paciente (id_consulta, id_paciente, id_medico, fecha, tipo_consulta, referido_institucion, id_cita, diagnostico, notas) FROM stdin;
1	1	1	2026-09-10	Primera	f	1	Rinofaringitis aguda	Se indica reposo e hidratacion abundante
2	4	3	2026-09-15	Reconsulta	f	2	Hipertension arterial controlada	Continuar tratamiento, proxima cita en un mes
3	7	4	2026-09-18	Primera	t	\N	Control ginecologico de rutina	Paciente referida del Centro de Salud de Retalhuleu
4	5	10	2026-08-02	Primera	f	5	Gastritis cronica	Dieta blanda y control en un mes
5	4	1	2026-08-05	Reconsulta	t	\N	Dermatitis de contacto	Evitar el agente irritante
6	6	10	2026-08-08	Primera	f	7	Control pediatrico de crecimiento	Desarrollo adecuado para la edad
7	22	18	2026-08-13	Primera	f	9	Hipertension arterial controlada	Continuar tratamiento
8	7	27	2026-08-15	Reconsulta	t	\N	Lumbalgia mecanica	Fisioterapia y analgesicos
9	17	24	2026-08-20	Primera	f	11	Faringoamigdalitis	Antibiotico por 7 dias
10	1	5	2026-08-21	Reconsulta	f	14	Rinofaringitis aguda	Reposo e hidratacion abundante
11	3	30	2026-08-21	Primera	f	12	Diabetes mellitus tipo 2	Control de glucosa semanal
12	10	31	2026-08-23	Primera	f	15	Control prenatal de rutina	Paciente en buen estado
13	9	15	2026-08-24	Primera	f	16	Cefalea tensional	Manejo del estres
14	18	9	2026-08-26	Primera	f	17	Gastritis cronica	Dieta blanda y control en un mes
15	9	5	2026-08-30	Reconsulta	t	\N	Dermatitis de contacto	Evitar el agente irritante
16	14	25	2026-09-04	Primera	f	19	Control pediatrico de crecimiento	Desarrollo adecuado para la edad
17	26	15	2026-09-05	Primera	f	21	Hipertension arterial controlada	Continuar tratamiento
18	18	24	2026-09-09	Reconsulta	f	23	Lumbalgia mecanica	Fisioterapia y analgesicos
19	4	27	2026-09-09	Reconsulta	f	22	Faringoamigdalitis	Antibiotico por 7 dias
20	10	20	2026-09-11	Reconsulta	f	25	Rinofaringitis aguda	Reposo e hidratacion abundante
21	1	21	2026-09-11	Reconsulta	f	24	Diabetes mellitus tipo 2	Control de glucosa semanal
22	7	11	2026-09-13	Reconsulta	f	26	Control prenatal de rutina	Paciente en buen estado
23	12	20	2026-09-19	Primera	t	\N	Cefalea tensional	Manejo del estres
24	10	27	2026-09-24	Reconsulta	t	\N	Gastritis cronica	Dieta blanda y control en un mes
25	27	21	2026-09-28	Primera	f	31	Dermatitis de contacto	Evitar el agente irritante
26	23	30	2026-10-05	Primera	f	34	Control pediatrico de crecimiento	Desarrollo adecuado para la edad
27	13	2	2026-10-08	Primera	f	35	Hipertension arterial controlada	Continuar tratamiento
28	5	2	2026-10-09	Reconsulta	t	\N	Lumbalgia mecanica	Fisioterapia y analgesicos
29	11	21	2026-10-09	Primera	t	\N	Faringoamigdalitis	Antibiotico por 7 dias
30	23	11	2026-10-11	Reconsulta	t	\N	Rinofaringitis aguda	Reposo e hidratacion abundante
31	18	22	2026-10-15	Reconsulta	f	37	Diabetes mellitus tipo 2	Control de glucosa semanal
32	30	21	2026-10-17	Primera	f	38	Control prenatal de rutina	Paciente en buen estado
33	12	11	2026-10-22	Reconsulta	t	\N	Cefalea tensional	Manejo del estres
34	25	14	2026-10-24	Primera	t	\N	Gastritis cronica	Dieta blanda y control en un mes
\.


--
-- Data for Name: cuota; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.cuota (id_cuota, id_factura, numero_cuota, monto, fecha_pago, metodo_pago) FROM stdin;
1	1	1	150.00	2026-09-10	Efectivo
2	2	1	4166.67	2026-09-22	Efectivo
3	2	2	4166.67	2026-10-22	Efectivo
4	2	3	4166.66	\N	Efectivo
5	3	1	800.00	2026-09-25	Efectivo
6	4	1	300.00	2026-08-05	Tarjeta de credito
7	5	1	721.50	2026-08-05	Tarjeta de debito
8	5	2	721.50	2026-09-04	Tarjeta de credito
9	6	1	601.00	2026-08-06	Efectivo
10	6	2	601.00	2026-09-05	Tarjeta de debito
11	7	1	1113.00	2026-08-07	Efectivo
12	8	1	2770.00	\N	Tarjeta de credito
13	8	2	2770.00	2026-09-11	Tarjeta de debito
14	8	3	2770.00	2026-10-11	Efectivo
15	9	1	3010.00	2026-08-12	Tarjeta de credito
16	9	2	3010.00	2026-09-11	Tarjeta de credito
17	10	1	125.00	2026-08-13	Efectivo
18	10	2	125.00	2026-09-12	Efectivo
19	11	1	1630.00	2026-08-13	Tarjeta de credito
20	11	2	1630.00	\N	Tarjeta de debito
21	11	3	1630.00	2026-10-12	Tarjeta de debito
22	11	4	1630.00	\N	Tarjeta de credito
23	11	5	1630.00	\N	Tarjeta de credito
24	11	6	1630.00	\N	Tarjeta de credito
25	12	1	1760.00	2026-08-14	Tarjeta de credito
26	12	2	1760.00	2026-09-13	Efectivo
27	12	3	1760.00	2026-10-13	Efectivo
28	13	1	2123.33	2026-08-16	Tarjeta de debito
29	13	2	2123.33	2026-09-15	Tarjeta de debito
30	13	3	2123.34	2026-10-15	Tarjeta de credito
31	14	1	2533.33	2026-08-16	Efectivo
32	14	2	2533.33	\N	Tarjeta de debito
33	14	3	2533.34	2026-10-15	Tarjeta de debito
34	15	1	1471.00	2026-08-17	Tarjeta de debito
35	16	1	1862.50	2026-08-17	Tarjeta de credito
36	16	2	1862.50	2026-09-16	Efectivo
37	16	3	1862.50	2026-10-16	Tarjeta de debito
38	16	4	1862.50	\N	Tarjeta de debito
39	17	1	300.00	2026-08-21	Efectivo
40	18	1	1900.00	2026-08-21	Efectivo
41	19	1	598.00	2026-08-22	Tarjeta de debito
42	19	2	598.00	2026-09-21	Efectivo
43	19	3	598.00	2026-10-21	Tarjeta de credito
44	19	4	598.00	\N	Efectivo
45	20	1	1167.00	2026-08-24	Efectivo
46	20	2	1167.00	2026-09-23	Efectivo
47	21	1	330.00	2026-08-25	Tarjeta de credito
48	21	2	330.00	2026-09-24	Efectivo
49	22	1	250.00	\N	Efectivo
50	23	1	2335.00	2026-08-26	Efectivo
51	23	2	2335.00	2026-09-25	Tarjeta de credito
52	24	1	1651.67	2026-08-28	Efectivo
53	24	2	1651.67	2026-09-27	Tarjeta de debito
54	24	3	1651.67	\N	Efectivo
55	24	4	1651.67	\N	Efectivo
56	24	5	1651.67	\N	Tarjeta de debito
57	24	6	1651.65	\N	Tarjeta de debito
58	25	1	549.00	2026-08-29	Efectivo
59	25	2	549.00	2026-09-28	Tarjeta de debito
60	26	1	150.00	2026-08-30	Efectivo
61	27	1	349.00	2026-09-05	Tarjeta de credito
62	27	2	349.00	2026-10-05	Tarjeta de credito
63	28	1	3030.00	2026-09-08	Efectivo
64	28	2	3030.00	2026-10-08	Tarjeta de debito
65	29	1	1400.00	2026-09-09	Tarjeta de debito
66	30	1	2513.33	2026-09-10	Tarjeta de debito
67	30	2	2513.33	2026-10-10	Tarjeta de credito
68	30	3	2513.34	\N	Tarjeta de credito
69	31	1	300.00	2026-09-11	Tarjeta de debito
70	32	1	150.00	2026-09-11	Tarjeta de debito
71	33	1	1682.00	2026-09-11	Tarjeta de credito
72	34	1	1210.00	2026-09-11	Tarjeta de credito
73	34	2	1210.00	2026-10-11	Efectivo
74	34	3	1210.00	\N	Tarjeta de credito
75	35	1	1210.00	2026-09-12	Efectivo
76	36	1	250.00	2026-09-13	Tarjeta de credito
77	37	1	833.00	\N	Tarjeta de credito
78	37	2	833.00	2026-10-13	Efectivo
79	38	1	2272.50	2026-09-15	Tarjeta de credito
80	38	2	2272.50	2026-10-15	Tarjeta de credito
81	38	3	2272.50	\N	Efectivo
82	38	4	2272.50	\N	Tarjeta de credito
83	39	1	1029.50	2026-09-16	Tarjeta de credito
84	39	2	1029.50	2026-10-16	Tarjeta de credito
85	40	1	417.50	2026-09-17	Tarjeta de debito
86	40	2	417.50	2026-10-17	Tarjeta de credito
87	41	1	1610.00	2026-09-19	Tarjeta de debito
88	42	1	2934.00	2026-09-20	Tarjeta de debito
89	42	2	2934.00	2026-10-20	Tarjeta de credito
90	42	3	2934.00	\N	Tarjeta de credito
91	42	4	2934.00	\N	Efectivo
92	42	5	2934.00	\N	Tarjeta de credito
93	43	1	950.00	2026-09-21	Tarjeta de credito
94	43	2	950.00	\N	Tarjeta de credito
95	44	1	1630.00	2026-09-22	Tarjeta de credito
96	45	1	700.00	2026-09-23	Tarjeta de credito
97	45	2	700.00	2026-10-23	Tarjeta de credito
98	45	3	700.00	\N	Tarjeta de credito
99	46	1	150.00	2026-09-24	Tarjeta de debito
100	47	1	1160.00	2026-09-25	Efectivo
101	48	1	620.00	2026-09-25	Efectivo
102	48	2	620.00	\N	Efectivo
103	49	1	1550.00	2026-09-26	Efectivo
104	50	1	845.00	2026-09-26	Tarjeta de debito
105	50	2	845.00	\N	Tarjeta de debito
106	50	3	845.00	\N	Tarjeta de debito
107	50	4	845.00	\N	Tarjeta de debito
108	51	1	820.00	2026-09-27	Tarjeta de debito
109	52	1	486.00	\N	Tarjeta de credito
110	52	2	486.00	\N	Tarjeta de credito
111	53	1	511.50	2026-09-29	Tarjeta de credito
112	53	2	511.50	\N	Tarjeta de credito
113	54	1	869.00	\N	Efectivo
114	55	1	462.00	2026-09-30	Efectivo
115	55	2	462.00	\N	Efectivo
116	56	1	3615.00	2026-09-30	Tarjeta de debito
117	56	2	3615.00	\N	Tarjeta de credito
118	57	1	2308.00	2026-10-03	Tarjeta de credito
119	57	2	2308.00	\N	Efectivo
120	57	3	2308.00	\N	Tarjeta de debito
121	57	4	2308.00	\N	Tarjeta de debito
122	57	5	2308.00	\N	Tarjeta de debito
123	58	1	2400.00	2026-10-03	Tarjeta de credito
124	58	2	2400.00	\N	Efectivo
125	58	3	2400.00	\N	Efectivo
126	59	1	200.00	2026-10-05	Efectivo
127	60	1	476.00	2026-10-06	Tarjeta de credito
128	60	2	476.00	\N	Tarjeta de debito
129	61	1	1708.00	2026-10-06	Tarjeta de debito
130	62	1	125.00	2026-10-08	Tarjeta de credito
131	63	1	150.00	2026-10-09	Tarjeta de credito
132	64	1	200.00	2026-10-09	Efectivo
133	65	1	100.00	2026-10-11	Tarjeta de credito
134	66	1	1950.00	2026-10-11	Efectivo
135	67	1	150.00	2026-10-15	Tarjeta de debito
136	68	1	870.00	2026-10-16	Efectivo
137	69	1	964.50	2026-10-16	Tarjeta de debito
138	69	2	964.50	\N	Tarjeta de debito
139	70	1	821.33	2026-10-16	Tarjeta de debito
140	70	2	821.33	\N	Efectivo
141	70	3	821.34	\N	Efectivo
142	71	1	714.50	2026-10-16	Efectivo
143	71	2	714.50	\N	Tarjeta de credito
144	72	1	2570.00	2026-10-17	Efectivo
145	72	2	2570.00	\N	Tarjeta de credito
146	72	3	2570.00	\N	Tarjeta de credito
147	73	1	716.67	2026-10-19	Efectivo
148	73	2	716.67	\N	Efectivo
149	73	3	716.66	\N	Tarjeta de credito
150	74	1	250.00	2026-10-24	Tarjeta de credito
\.


--
-- Data for Name: departamento; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.departamento (id_departamento, nombre) FROM stdin;
1	Quetzaltenango
2	San Marcos
3	Huehuetenango
4	Retalhuleu
5	Totonicapan
\.


--
-- Data for Name: diagnostico_secundario; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.diagnostico_secundario (id_diagnostico_secundario, id_egreso, descripcion) FROM stdin;
1	3	Deshidratacion leve resuelta con hidratacion intravenosa
2	5	Deshidratacion leve resuelta
3	11	Deshidratacion leve resuelta
4	25	Deshidratacion leve resuelta
5	38	Deshidratacion leve resuelta
6	54	Deshidratacion leve resuelta
7	67	Deshidratacion leve resuelta
\.


--
-- Data for Name: egreso; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.egreso (id_egreso, id_ingreso, id_medico, fecha_hora, diagnostico_principal, motivo_egreso, codigo_egreso, egreso_sin_consentimiento, motivo_sin_consentimiento, id_traslado, dias_hospitalizado, referido_otro_hospital) FROM stdin;
1	1	1	2026-09-20 15:00:00	Apendicitis aguda, requiere manejo quirurgico	Traslado a Cirugia	Vivo	f	\N	1	0	\N
2	2	6	2026-09-20 19:00:00	Apendicitis aguda resuelta quirurgicamente	Traslado a Hospitalizacion para recuperacion postoperatoria	Vivo	f	\N	2	\N	\N
3	3	1	2026-09-22 10:00:00	Postoperatorio de apendicectomia sin complicaciones	Alta medica por mejoria	Vivo	f	\N	\N	2	\N
4	4	5	2026-09-25 01:30:00	Crisis asmatica resuelta	Alta por mejoria tras nebulizacion	Vivo	f	\N	\N	0	\N
5	6	30	2026-08-03 21:15:00	Abdomen agudo a descartar resuelta	Alta medica por mejoria	Vivo	f	\N	\N	0	\N
6	7	28	2026-08-05 11:15:00	Parto eutocico sin complicaciones	Alta medica madre y recien nacido estables	Parto	f	\N	\N	0	\N
7	8	18	2026-08-05 15:30:00	Herida penetrante resuelta	Alta medica por mejoria	Vivo	t	Paciente solicita egreso voluntario	\N	0	\N
8	9	3	2026-08-06 14:00:00	Amenaza de parto pretermino controlada	Alta con indicaciones y control prenatal	Embarazo	f	\N	\N	0	\N
9	10	1	2026-08-07 14:15:00	Gastroenteritis aguda resuelta	Alta medica por mejoria	Vivo	f	\N	\N	0	\N
10	11	16	2026-08-14 13:15:00	Sindrome febril en estudio resuelta	Alta medica por mejoria	Vivo	t	Paciente solicita egreso voluntario	\N	0	\N
11	12	25	2026-08-15 01:00:00	Crisis asmatica moderada resuelta	Alta medica por mejoria	Vivo	f	\N	\N	0	\N
12	13	11	2026-08-17 00:45:00	Gastroenteritis aguda resuelta	Alta medica por mejoria	Vivo	f	\N	\N	0	\N
13	14	28	2026-08-16 15:45:00	Crisis asmatica moderada resuelta	Alta medica por mejoria	Vivo	f	\N	\N	0	\N
14	15	30	2026-08-20 12:00:00	Neumonia a descartar resuelta	Alta medica por mejoria	Vivo	f	\N	\N	0	\N
15	16	24	2026-08-20 21:45:00	Parto eutocico sin complicaciones	Alta medica madre y recien nacido estables	Parto	t	Paciente solicita egreso voluntario	\N	0	\N
16	17	20	2026-08-20 17:30:00	Intoxicacion alimentaria resuelta	Alta medica por mejoria	Vivo	f	\N	\N	0	\N
17	18	20	2026-08-21 01:00:00	Gastroenteritis aguda resuelta	Alta medica por mejoria	Vivo	f	\N	\N	0	\N
18	19	18	2026-08-21 12:00:00	Paro cardiorrespiratorio	Fallecimiento durante la atencion de emergencia	Muerto	f	\N	\N	0	\N
19	20	18	2026-08-21 15:45:00	Paro cardiorrespiratorio	Fallecimiento durante la atencion de emergencia	Muerto	f	\N	\N	0	\N
20	21	14	2026-08-24 03:30:00	Trauma craneoencefalico leve resuelta	Alta medica por mejoria	Vivo	f	\N	\N	0	\N
21	22	1	2026-08-23 17:45:00	Herida penetrante resuelta	Alta medica por mejoria	Vivo	f	\N	\N	0	\N
22	23	5	2026-08-24 02:30:00	Amenaza de parto pretermino controlada	Alta con indicaciones y control prenatal	Embarazo	f	\N	\N	0	\N
23	24	12	2026-08-25 01:00:00	Herida penetrante resuelta	Alta medica por mejoria	Vivo	t	Familiar solicita traslado a otro centro	\N	0	\N
24	25	3	2026-08-26 20:45:00	Sindrome coronario agudo a descartar resuelta	Alta medica por mejoria	Vivo	f	\N	\N	0	\N
25	26	31	2026-08-29 10:15:00	Gastroenteritis aguda resuelta	Alta medica por mejoria	Vivo	t	Familiar solicita traslado a otro centro	\N	0	\N
26	27	11	2026-08-31 01:30:00	Crisis convulsiva resuelta	Alta medica por mejoria	Vivo	f	\N	\N	0	\N
27	28	28	2026-09-02 21:00:00	Crisis convulsiva resuelta	Alta medica por mejoria	Vivo	t	Familiar solicita traslado a otro centro	\N	0	\N
28	29	11	2026-09-03 04:00:00	Intoxicacion alimentaria resuelta	Alta medica por mejoria	Vivo	t	Paciente solicita egreso voluntario	\N	0	\N
29	30	15	2026-09-04 13:30:00	Crisis convulsiva resuelta	Alta medica por mejoria	Vivo	f	\N	\N	0	\N
30	31	24	2026-09-05 11:45:00	Crisis convulsiva resuelta	Alta medica por mejoria	Vivo	f	\N	\N	0	\N
31	32	24	2026-09-05 17:00:00	Paro cardiorrespiratorio	Fallecimiento durante la atencion de emergencia	Muerto	f	\N	\N	0	\N
32	33	22	2026-09-05 10:30:00	Paro cardiorrespiratorio	Fallecimiento durante la atencion de emergencia	Muerto	f	\N	\N	0	\N
33	34	24	2026-09-09 13:15:00	Intoxicacion alimentaria resuelta	Alta medica por mejoria	Vivo	f	\N	\N	0	\N
34	35	1	2026-09-10 04:30:00	Herida penetrante resuelta	Alta medica por mejoria	Vivo	f	\N	\N	0	\N
35	36	22	2026-09-11 05:15:00	Gastroenteritis aguda resuelta	Alta medica por mejoria	Vivo	f	\N	\N	0	\N
36	37	24	2026-09-12 00:00:00	Parto eutocico sin complicaciones	Alta medica madre y recien nacido estables	Parto	f	\N	\N	0	\N
37	38	11	2026-09-12 09:30:00	Crisis convulsiva resuelta	Alta medica por mejoria	Vivo	f	\N	\N	1	\N
38	39	24	2026-09-12 17:15:00	Sindrome coronario agudo a descartar resuelta	Alta medica por mejoria	Vivo	f	\N	\N	1	\N
39	40	16	2026-09-12 14:30:00	Trauma craneoencefalico leve resuelta	Alta medica por mejoria	Vivo	f	\N	\N	0	\N
40	41	1	2026-09-12 10:15:00	Paro cardiorrespiratorio	Fallecimiento durante la atencion de emergencia	Muerto	f	\N	\N	0	\N
41	42	18	2026-09-13 01:00:00	Sindrome febril en estudio resuelta	Alta medica por mejoria	Vivo	f	\N	\N	0	\N
42	43	11	2026-09-12 15:30:00	Paro cardiorrespiratorio	Fallecimiento durante la atencion de emergencia	Muerto	f	\N	\N	0	\N
43	44	5	2026-09-13 03:00:00	Herida penetrante resuelta	Alta medica por mejoria	Vivo	f	\N	\N	0	\N
44	45	2	2026-09-15 10:00:00	Parto eutocico sin complicaciones	Alta medica madre y recien nacido estables	Parto	f	\N	\N	0	\N
45	46	3	2026-09-16 14:15:00	Gastroenteritis aguda resuelta	Alta medica por mejoria	Vivo	f	\N	\N	0	\N
46	47	18	2026-09-18 03:00:00	Intoxicacion alimentaria resuelta	Alta medica por mejoria	Vivo	f	\N	\N	0	\N
47	48	12	2026-09-22 02:15:00	Sindrome coronario agudo a descartar resuelta	Alta medica por mejoria	Vivo	f	\N	\N	0	\N
48	49	22	2026-09-22 23:00:00	Gastroenteritis aguda resuelta	Alta medica por mejoria	Vivo	f	\N	\N	0	\N
49	50	12	2026-09-23 04:00:00	Neumonia a descartar resuelta	Alta medica por mejoria	Vivo	f	\N	\N	0	\N
50	51	12	2026-09-27 09:15:00	Paro cardiorrespiratorio	Fallecimiento durante la atencion de emergencia	Muerto	f	\N	\N	0	\N
51	52	12	2026-09-27 18:30:00	Paro cardiorrespiratorio	Fallecimiento durante la atencion de emergencia	Muerto	f	\N	\N	0	\N
52	53	15	2026-09-27 22:30:00	Paro cardiorrespiratorio	Fallecimiento durante la atencion de emergencia	Muerto	f	\N	\N	0	\N
53	54	2	2026-09-28 11:00:00	Abdomen agudo a descartar resuelta	Alta medica por mejoria	Vivo	f	\N	\N	0	\N
54	55	5	2026-09-30 07:15:00	Abdomen agudo a descartar resuelta	Alta medica por mejoria	Vivo	f	\N	\N	1	\N
55	56	15	2026-09-30 02:00:00	Herida penetrante resuelta	Alta medica por mejoria	Vivo	f	\N	\N	0	\N
56	57	5	2026-09-30 04:30:00	Sindrome febril en estudio resuelta	Alta medica por mejoria	Vivo	f	\N	\N	0	\N
57	58	2	2026-10-01 02:45:00	Neumonia a descartar resuelta	Alta medica por mejoria	Vivo	f	\N	\N	0	\N
58	59	30	2026-10-02 23:15:00	Herida penetrante resuelta	Alta medica por mejoria	Vivo	f	\N	\N	0	\N
59	60	31	2026-10-03 20:30:00	Intoxicacion alimentaria resuelta	Alta medica por mejoria	Vivo	f	\N	\N	1	\N
60	61	25	2026-10-03 13:30:00	Herida penetrante resuelta	Alta medica por mejoria	Vivo	t	Familiar solicita traslado a otro centro	\N	0	\N
61	62	11	2026-10-03 11:30:00	Paro cardiorrespiratorio	Fallecimiento durante la atencion de emergencia	Muerto	f	\N	\N	0	\N
62	63	2	2026-10-03 19:15:00	Paro cardiorrespiratorio	Fallecimiento durante la atencion de emergencia	Muerto	f	\N	\N	0	\N
63	64	25	2026-10-04 02:00:00	Fractura de tibia resuelta	Alta medica por mejoria	Vivo	f	\N	\N	0	\N
64	65	20	2026-10-05 14:30:00	Gastroenteritis aguda resuelta	Alta medica por mejoria	Vivo	f	\N	\N	0	\N
65	66	28	2026-10-05 19:30:00	Trauma craneoencefalico leve resuelta	Alta medica por mejoria	Vivo	f	\N	\N	0	\N
66	67	31	2026-10-06 12:30:00	Sindrome febril en estudio resuelta	Alta medica por mejoria	Vivo	f	\N	\N	0	\N
67	68	11	2026-10-07 20:30:00	Abdomen agudo a descartar resuelta	Alta medica por mejoria	Vivo	f	\N	\N	1	\N
68	69	22	2026-10-07 23:00:00	Parto eutocico sin complicaciones	Alta medica madre y recien nacido estables	Parto	f	\N	\N	0	\N
69	70	14	2026-10-08 05:15:00	Crisis asmatica moderada resuelta	Alta medica por mejoria	Vivo	f	\N	\N	0	\N
70	71	1	2026-10-09 01:00:00	Crisis convulsiva resuelta	Alta medica por mejoria	Vivo	f	\N	\N	0	\N
71	72	28	2026-10-09 10:15:00	Trauma craneoencefalico leve resuelta	Alta medica por mejoria	Vivo	f	\N	\N	0	\N
72	73	24	2026-10-10 08:30:00	Intoxicacion alimentaria resuelta	Alta medica por mejoria	Vivo	f	\N	\N	0	\N
73	74	16	2026-10-10 15:45:00	Paro cardiorrespiratorio	Fallecimiento durante la atencion de emergencia	Muerto	f	\N	\N	0	\N
74	75	15	2026-10-12 23:15:00	Crisis asmatica moderada resuelta	Alta medica por mejoria	Vivo	f	\N	\N	0	\N
75	76	30	2026-10-15 19:15:00	Paro cardiorrespiratorio	Fallecimiento durante la atencion de emergencia	Muerto	f	\N	\N	0	\N
76	77	28	2026-10-15 10:30:00	Paro cardiorrespiratorio	Fallecimiento durante la atencion de emergencia	Muerto	f	\N	\N	0	\N
77	78	15	2026-10-16 12:15:00	Crisis asmatica moderada resuelta	Alta medica por mejoria	Vivo	t	Paciente solicita egreso voluntario	\N	0	\N
78	79	2	2026-10-16 00:30:00	Fractura de tibia resuelta	Alta medica por mejoria	Vivo	f	\N	\N	0	\N
79	80	2	2026-10-19 11:15:00	Abdomen agudo a descartar resuelta	Alta medica por mejoria	Vivo	f	\N	\N	0	\N
80	81	14	2026-10-21 21:00:00	Sindrome febril en estudio resuelta	Alta medica por mejoria	Vivo	f	\N	\N	0	\N
81	86	29	2026-08-07 12:56:00	Hernioplastia inguinal realizada	Traslado a Hospitalizacion para recuperacion	Vivo	f	\N	3	\N	\N
82	87	27	2026-08-12 13:11:00	Postoperatorio de hernioplastia inguinal sin complicaciones	Alta medica por mejoria	Vivo	f	\N	\N	5	\N
83	88	1	2026-08-10 12:00:00	Cuadro quirurgico agudo	Traslado a Cirugia	Vivo	f	\N	4	0	\N
84	89	6	2026-08-10 14:30:00	Apendicectomia convencional realizada	Traslado a Hospitalizacion para recuperacion	Vivo	f	\N	5	\N	\N
85	90	11	2026-08-12 14:45:00	Postoperatorio de apendicectomia convencional sin complicaciones	Alta medica por mejoria	Vivo	f	\N	\N	2	\N
86	91	20	2026-08-11 09:45:00	Cuadro quirurgico agudo	Traslado a Cirugia	Vivo	f	\N	6	0	\N
87	92	17	2026-08-11 12:41:00	Apendicectomia convencional realizada	Traslado a Hospitalizacion para recuperacion	Vivo	f	\N	7	\N	\N
88	93	20	2026-08-14 12:56:00	Postoperatorio de apendicectomia convencional sin complicaciones	Alta medica por mejoria	Vivo	f	\N	\N	3	\N
89	94	2	2026-08-12 01:15:00	Cuadro quirurgico agudo	Traslado a Cirugia	Vivo	f	\N	8	0	\N
90	95	6	2026-08-12 04:01:00	Apendicectomia convencional realizada	Traslado a Hospitalizacion para recuperacion	Vivo	f	\N	9	\N	\N
91	96	11	2026-08-16 04:16:00	Postoperatorio de apendicectomia convencional sin complicaciones	Alta medica por mejoria	Vivo	f	\N	\N	4	\N
92	97	8	2026-08-13 10:02:00	Hernioplastia inguinal realizada	Traslado a Hospitalizacion para recuperacion	Vivo	f	\N	10	\N	\N
93	98	2	2026-08-17 10:17:00	Postoperatorio de hernioplastia inguinal sin complicaciones	Alta medica por mejoria	Vivo	f	\N	\N	4	\N
94	99	7	2026-08-13 13:32:00	Falla multiorganica postoperatoria	Fallecimiento durante la cirugia	Muerto	f	\N	\N	0	\N
95	100	13	2026-08-14 10:35:00	Hernioplastia inguinal realizada	Traslado a Hospitalizacion para recuperacion	Vivo	f	\N	11	\N	\N
96	101	12	2026-08-16 10:50:00	Postoperatorio de hernioplastia inguinal sin complicaciones	Alta medica por mejoria	Vivo	f	\N	\N	2	\N
97	102	2	2026-08-22 17:15:00	Cuadro quirurgico agudo	Traslado a Cirugia	Vivo	f	\N	12	0	\N
98	103	8	2026-08-22 19:26:00	Drenaje de absceso realizada	Traslado a Hospitalizacion para recuperacion	Vivo	f	\N	13	\N	\N
99	104	11	2026-08-26 19:41:00	Postoperatorio de drenaje de absceso sin complicaciones	Alta medica por mejoria	Vivo	f	\N	\N	4	\N
100	105	32	2026-08-24 10:34:00	Artroscopia de rodilla realizada	Traslado a Hospitalizacion para recuperacion	Vivo	f	\N	14	\N	\N
101	106	30	2026-08-28 10:49:00	Postoperatorio de artroscopia de rodilla con complicaciones	Fallecimiento en recuperacion	Muerto	f	\N	\N	4	\N
102	107	14	2026-09-05 17:30:00	Cuadro quirurgico agudo	Traslado a Cirugia	Vivo	f	\N	15	0	\N
103	108	13	2026-09-05 20:09:00	Apendicectomia convencional realizada	Traslado a Hospitalizacion para recuperacion	Vivo	f	\N	16	\N	\N
104	109	14	2026-09-08 20:24:00	Postoperatorio de apendicectomia convencional sin complicaciones	Alta medica por mejoria	Vivo	f	\N	\N	3	\N
105	110	6	2026-09-08 10:10:00	Hernioplastia inguinal realizada	Traslado a Hospitalizacion para recuperacion	Vivo	f	\N	17	\N	\N
106	111	11	2026-09-10 10:25:00	Postoperatorio de hernioplastia inguinal sin complicaciones	Alta medica por mejoria	Vivo	f	\N	\N	2	\N
107	112	5	2026-09-10 17:00:00	Cuadro quirurgico agudo	Traslado a Cirugia	Vivo	f	\N	18	0	\N
108	113	13	2026-09-10 18:55:00	Drenaje de absceso realizada	Traslado a Hospitalizacion para recuperacion	Vivo	f	\N	19	\N	\N
109	114	4	2026-09-11 19:10:00	Postoperatorio de drenaje de absceso sin complicaciones	Alta medica por mejoria	Vivo	f	\N	\N	1	\N
110	115	25	2026-09-14 22:15:00	Cuadro quirurgico agudo	Traslado a Cirugia	Vivo	f	\N	20	0	\N
111	116	26	2026-09-15 01:13:00	Falla multiorganica postoperatoria	Fallecimiento durante la cirugia	Muerto	f	\N	\N	0	\N
112	117	1	2026-09-16 07:15:00	Cuadro quirurgico agudo	Traslado a Cirugia	Vivo	f	\N	21	0	\N
113	118	8	2026-09-16 11:39:00	Laparotomia exploradora realizada	Traslado a Hospitalizacion para recuperacion	Vivo	f	\N	22	\N	\N
114	119	3	2026-09-20 11:54:00	Postoperatorio de laparotomia exploradora sin complicaciones	Alta medica por mejoria	Vivo	f	\N	\N	4	\N
115	120	18	2026-09-29 00:00:00	Cuadro quirurgico agudo	Traslado a Cirugia	Vivo	f	\N	23	0	\N
116	121	19	2026-09-29 03:55:00	Reduccion abierta de fractura de tibia realizada	Traslado a Hospitalizacion para recuperacion	Vivo	f	\N	24	\N	\N
117	122	9	2026-10-03 04:10:00	Postoperatorio de reduccion abierta de fractura de tibia sin complicaciones	Alta medica por mejoria	Vivo	f	\N	\N	4	\N
118	123	29	2026-09-28 13:16:00	Hernioplastia inguinal realizada	Traslado a Hospitalizacion para recuperacion	Vivo	f	\N	25	\N	\N
119	124	27	2026-09-30 13:31:00	Postoperatorio de hernioplastia inguinal con complicaciones	Fallecimiento en recuperacion	Muerto	f	\N	\N	2	\N
120	125	8	2026-09-29 12:56:00	Hernioplastia inguinal realizada	Traslado a Hospitalizacion para recuperacion	Vivo	f	\N	26	\N	\N
121	126	3	2026-10-03 13:11:00	Postoperatorio de hernioplastia inguinal sin complicaciones	Alta medica por mejoria	Vivo	f	\N	\N	4	\N
122	127	6	2026-10-12 09:41:00	Hernioplastia inguinal realizada	Traslado a Hospitalizacion para recuperacion	Vivo	f	\N	27	\N	\N
123	128	2	2026-10-17 09:56:00	Postoperatorio de hernioplastia inguinal sin complicaciones	Alta medica por mejoria	Vivo	f	\N	\N	5	\N
124	129	14	2026-09-25 11:00:00	Fractura de cadera tratada	Alta medica por mejoria	Vivo	f	\N	\N	2	\N
125	130	21	2026-10-19 11:00:00	Neumonia adquirida en la comunidad tratada	Alta medica por mejoria	Vivo	f	\N	\N	5	\N
126	131	12	2026-09-27 12:00:00	Cetoacidosis diabetica tratada	Alta medica por mejoria	Vivo	f	\N	\N	1	\N
127	132	4	2026-09-26 19:00:00	Fractura de cadera tratada	Alta medica por mejoria	Vivo	f	\N	\N	3	\N
128	133	10	2026-09-21 07:00:00	Insuficiencia cardiaca descompensada tratada	Alta medica por mejoria	Vivo	f	\N	\N	4	\N
129	134	11	2026-09-23 11:00:00	Fractura de cadera tratada	Alta medica por mejoria	Vivo	f	\N	\N	4	\N
130	135	21	2026-10-11 08:00:00	Fractura de cadera tratada	Alta medica por mejoria	Vivo	f	\N	\N	5	\N
131	136	16	2026-09-09 10:00:00	Anemia severa tratada	Alta medica por mejoria	Vivo	f	\N	\N	3	\N
132	137	5	2026-09-19 17:00:00	Neumonia adquirida en la comunidad tratada	Alta medica por mejoria	Vivo	f	\N	\N	3	\N
133	138	11	2026-08-21 10:00:00	Fractura de cadera tratada	Alta medica por mejoria	Vivo	f	\N	\N	4	\N
134	139	27	2026-09-26 20:00:00	Anemia severa tratada	Alta medica por mejoria	Vivo	f	\N	\N	8	\N
135	140	5	2026-09-25 17:00:00	Anemia severa tratada	Alta medica por mejoria	Vivo	f	\N	\N	2	\N
\.


--
-- Data for Name: enfermero; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.enfermero (id_enfermero, nombre, dpi, tipo_enfermero, id_hospital, id_personal, tipo_personal, numero_colegiado) FROM stdin;
1	Marta Lidia Ixcoy Us	1212121212121	Registrado	1	11	Enfermero	\N
2	Jose Domingo Chocoj Tzul	1313131313131	Practicante	1	12	Enfermero	\N
3	Blanca Estela Vail Marroquin	1414141414141	Registrado	1	13	Enfermero	\N
4	Wilson Aroldo Giron Argueta	1515151515151	Registrado	2	14	Enfermero	\N
5	Petrona Us Cotzojay	1616161616161	Practicante	2	15	Enfermero	\N
6	Hugo Leonel Batz Sican	1717171717171	Registrado	3	16	Enfermero	\N
7	Gloria Julia Alvarado Us	3000000000043	Registrado	1	43	Enfermero	ENF-3007
8	Ana Carmen Us Toc	3000000000044	Practicante	2	44	Enfermero	\N
9	Jorge Andres Ixcoy Tepaz	3000000000045	Registrado	2	45	Enfermero	ENF-3009
10	Marta Sofia Vail Garcia	3000000000046	Practicante	3	46	Enfermero	\N
11	Carmen Ana Giron Mendez	3000000000047	Registrado	3	47	Enfermero	ENF-3011
12	Hugo Oscar Morales Chocoj	3000000000048	Practicante	4	48	Enfermero	\N
13	Rosa Lucia Garcia Vail	3000000000049	Registrado	4	49	Enfermero	ENF-3013
14	Patricia Teresa Cabrera Argueta	3000000000050	Practicante	5	50	Enfermero	\N
15	Jose Juan Alvarado De Leon	3000000000051	Registrado	5	51	Enfermero	ENF-3015
\.


--
-- Data for Name: equipo; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.equipo (id_equipo, nombre, tipo, funcion, descripcion) FROM stdin;
1	Maquina de anestesia	Medico	Tratamiento	Equipo para administracion de anestesia general
2	Monitor de signos vitales	Medico	Diagnostico	Monitoreo continuo de signos vitales
3	Electrobisturi	Quirurgico	Tratamiento	Corte y coagulacion por electrocirugia
4	Lampara quirurgica	Quirurgico	Exploracion	Iluminacion del campo quirurgico
5	Monitor de CO2	Medico	Diagnostico	Capnografia
6	Bomba de infusion	Medico	Tratamiento	Infusion controlada
7	Torre de laparoscopia	Quirurgico	Exploracion	Cirugia minimamente invasiva
8	Sierra ortopedica electrica	Quirurgico	Tratamiento	Corte oseo
\.


--
-- Data for Name: especialidad; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.especialidad (id_especialidad, nombre, categoria) FROM stdin;
1	Cardiologia	Consulta_Emergencia
2	Dermatologia	Consulta_Emergencia
3	Fisioterapia	Consulta_Emergencia
4	Ginecologia Oncologica	Consulta_Emergencia
5	Hematologia	Consulta_Emergencia
6	Medicina Fisica y Rehabilitacion	Consulta_Emergencia
7	Medicina General	Consulta_Emergencia
8	Nutricion y Dietetica	Consulta_Emergencia
9	Odontologia General	Consulta_Emergencia
10	Oftalmologia	Consulta_Emergencia
11	Psicologia	Consulta_Emergencia
12	Pediatria	Consulta_Emergencia
13	Urologia	Consulta_Emergencia
14	Terapia del Lenguaje	Consulta_Emergencia
15	Cirugia Cardiovascular Adulto y Pediatrica	Cirugia
16	Cirugia de la Mano	Cirugia
17	Cirugia General	Cirugia
18	Videolaparoscopia Quirurgica	Cirugia
19	Cirugia Ginecologica	Cirugia
20	Cirugia Neurologica	Cirugia
21	Cirugia Oftalmologica	Cirugia
22	Cirugia Oncologica	Cirugia
23	Cirugia Ortopedica	Cirugia
24	Cirugia Otorrinolaringologica	Cirugia
25	Cirugia Pediatrica	Cirugia
26	Cirugia Plastica	Cirugia
27	Cirugia de Torax	Cirugia
28	Cirugia Urologica	Cirugia
\.


--
-- Data for Name: factura; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.factura (id_factura, id_hospital, id_paciente, fecha, descripcion, monto, id_consulta, id_ingreso) FROM stdin;
1	1	1	2026-09-10	Consulta externa de Medicina General - primera consulta	150.00	1	\N
2	1	2	2026-09-22	Atencion de emergencia, cirugia de apendicectomia y hospitalizacion asociada	12500.00	\N	1
3	2	3	2026-09-25	Atencion de emergencia por crisis asmatica	800.00	\N	4
4	1	4	2026-08-05	Consulta externa de primera consulta	300.00	5	\N
5	5	21	2026-08-05	Atencion de emergencia	1443.00	\N	7
6	3	26	2026-08-06	Atencion de emergencia	1202.00	\N	8
7	1	13	2026-08-07	Atencion de emergencia	1113.00	\N	9
8	5	26	2026-08-12	Cirugia y hospitalizacion asociada	8310.00	\N	86
9	1	5	2026-08-12	Cirugia y hospitalizacion asociada	6020.00	\N	89
10	3	22	2026-08-13	Consulta externa de primera consulta	250.00	7	\N
11	1	14	2026-08-13	Cirugia y hospitalizacion asociada	9780.00	\N	99
12	3	16	2026-08-14	Cirugia y hospitalizacion asociada	5280.00	\N	92
13	1	4	2026-08-16	Cirugia y hospitalizacion asociada	6370.00	\N	95
14	2	2	2026-08-16	Cirugia y hospitalizacion asociada	7600.00	\N	100
15	1	1	2026-08-17	Atencion de emergencia	1471.00	\N	13
16	1	7	2026-08-17	Cirugia y hospitalizacion asociada	7450.00	\N	97
17	5	3	2026-08-21	Consulta externa de primera consulta	300.00	11	\N
18	1	1	2026-08-21	Hospitalizacion	1900.00	\N	138
19	3	8	2026-08-22	Atencion de emergencia	2392.00	\N	20
20	2	21	2026-08-24	Atencion de emergencia	2334.00	\N	23
21	2	25	2026-08-25	Atencion de emergencia	660.00	\N	24
22	3	18	2026-08-26	Consulta externa de primera consulta	250.00	14	\N
23	1	23	2026-08-26	Cirugia y hospitalizacion asociada	4670.00	\N	103
24	5	23	2026-08-28	Cirugia y hospitalizacion asociada	9910.00	\N	105
25	5	24	2026-08-29	Atencion de emergencia	1098.00	\N	26
26	2	9	2026-08-30	Consulta externa de reconsulta	150.00	15	\N
27	4	19	2026-09-05	Atencion de emergencia	698.00	\N	31
28	2	9	2026-09-08	Cirugia y hospitalizacion asociada	6060.00	\N	108
29	3	20	2026-09-09	Hospitalizacion	1400.00	\N	136
30	1	4	2026-09-10	Cirugia y hospitalizacion asociada	7540.00	\N	110
31	3	10	2026-09-11	Consulta externa de primera consulta	300.00	20	\N
32	4	1	2026-09-11	Consulta externa de reconsulta	150.00	21	\N
33	4	10	2026-09-11	Atencion de emergencia	1682.00	\N	36
34	2	26	2026-09-11	Cirugia y hospitalizacion asociada	3630.00	\N	113
35	4	29	2026-09-12	Atencion de emergencia	1210.00	\N	37
36	1	7	2026-09-13	Consulta externa de primera consulta	250.00	22	\N
37	3	19	2026-09-13	Atencion de emergencia	1666.00	\N	42
38	4	17	2026-09-15	Cirugia y hospitalizacion asociada	9090.00	\N	116
39	1	1	2026-09-16	Atencion de emergencia	2059.00	\N	45
40	1	27	2026-09-17	Atencion de emergencia	835.00	\N	46
41	2	13	2026-09-19	Hospitalizacion	1610.00	\N	137
42	1	11	2026-09-20	Cirugia y hospitalizacion asociada	14670.00	\N	118
43	1	25	2026-09-21	Hospitalizacion	1900.00	\N	133
44	2	16	2026-09-22	Atencion de emergencia	1630.00	\N	48
45	1	9	2026-09-23	Hospitalizacion	2100.00	\N	134
46	5	10	2026-09-24	Consulta externa de reconsulta	150.00	24	\N
47	2	8	2026-09-25	Hospitalizacion	1160.00	\N	129
48	2	5	2026-09-25	Hospitalizacion	1240.00	\N	140
49	2	26	2026-09-26	Hospitalizacion	1550.00	\N	132
50	5	5	2026-09-26	Hospitalizacion	3380.00	\N	139
51	2	2	2026-09-27	Hospitalizacion	820.00	\N	131
52	2	22	2026-09-28	Atencion de emergencia	972.00	\N	51
53	1	10	2026-09-29	Atencion de emergencia	1023.00	\N	54
54	2	15	2026-09-30	Atencion de emergencia	869.00	\N	55
55	2	20	2026-09-30	Atencion de emergencia	924.00	\N	56
56	5	13	2026-09-30	Cirugia y hospitalizacion asociada	7230.00	\N	123
57	3	10	2026-10-03	Cirugia y hospitalizacion asociada	11540.00	\N	121
58	1	2	2026-10-03	Cirugia y hospitalizacion asociada	7200.00	\N	125
59	5	23	2026-10-05	Consulta externa de primera consulta	200.00	26	\N
60	3	29	2026-10-06	Atencion de emergencia	952.00	\N	65
61	5	28	2026-10-06	Atencion de emergencia	1708.00	\N	67
62	1	13	2026-10-08	Consulta externa de reconsulta	125.00	27	\N
63	1	5	2026-10-09	Consulta externa de primera consulta	150.00	28	\N
64	4	11	2026-10-09	Consulta externa de primera consulta	200.00	29	\N
65	1	23	2026-10-11	Consulta externa de reconsulta	100.00	30	\N
66	4	22	2026-10-11	Hospitalizacion	1950.00	\N	135
67	4	18	2026-10-15	Consulta externa de primera consulta	150.00	31	\N
68	5	24	2026-10-16	Atencion de emergencia	870.00	\N	76
69	5	13	2026-10-16	Atencion de emergencia	1929.00	\N	77
70	2	11	2026-10-16	Atencion de emergencia	2464.00	\N	78
71	1	11	2026-10-16	Atencion de emergencia	1429.00	\N	79
72	1	6	2026-10-17	Cirugia y hospitalizacion asociada	7710.00	\N	127
73	4	16	2026-10-19	Hospitalizacion	2150.00	\N	130
74	2	25	2026-10-24	Consulta externa de primera consulta	250.00	34	\N
\.


--
-- Data for Name: hospital; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.hospital (id_hospital, nombre, direccion, id_municipio, telefono) FROM stdin;
1	Hospital Regional de Occidente	0 avenida 5-45, zona 1	1	77612345
2	Hospital Nacional de San Marcos	4a calle 8-20, zona 3	3	77762210
3	Hospital Nacional de Huehuetenango	2a avenida 3-15, zona 2	5	77641180
4	Hospital Nacional de Retalhuleu	5a avenida 2-30, zona 1	7	77711400
5	Hospital Nacional de Totonicapan	3a calle 4-15, zona 2	9	77661250
\.


--
-- Data for Name: hospitalizacion_detalle; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.hospitalizacion_detalle (id_hospitalizacion_detalle, id_ingreso, id_servicio, id_camilla, costo_dia, dias) FROM stdin;
1	3	7	3	350.00	2
2	5	3	4	300.00	\N
3	87	7	39	300.00	5
4	90	5	9	360.00	2
5	93	2	22	300.00	3
6	96	5	4	390.00	4
7	98	2	9	370.00	4
8	101	2	14	320.00	2
9	104	5	4	410.00	4
10	106	7	38	330.00	4
11	109	6	5	310.00	3
12	111	2	10	360.00	2
13	114	5	15	350.00	1
14	119	5	3	390.00	4
15	122	7	22	310.00	4
16	124	6	37	300.00	2
17	126	5	9	350.00	4
18	128	5	4	390.00	5
19	129	6	5	330.00	2
20	130	3	30	330.00	5
21	131	2	14	320.00	1
22	132	5	16	350.00	3
23	133	7	3	350.00	4
24	134	6	9	400.00	4
25	135	5	30	290.00	5
26	136	1	23	300.00	3
27	137	6	16	370.00	3
28	138	5	3	350.00	4
29	139	1	37	360.00	8
30	140	1	14	370.00	2
\.


--
-- Data for Name: ingreso; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.ingreso (id_ingreso, id_paciente, id_unidad_hospital, id_medico, fecha_hora, motivo_ingreso, id_responsable, id_camilla, diagnostico_presuntivo, turno_espera) FROM stdin;
1	2	1	1	2026-09-20 14:30:00	Dolor abdominal agudo de 12 horas de evolucion	\N	1	Apendicitis aguda probable	\N
2	2	2	6	2026-09-20 16:00:00	Intervencion quirurgica: apendicectomia	\N	\N	Apendicitis aguda	\N
3	2	3	1	2026-09-20 19:15:00	Recuperacion postoperatoria de apendicectomia	\N	3	Postoperatorio de apendicectomia	\N
4	3	4	5	2026-09-24 22:00:00	Crisis asmatica	2	6	Crisis asmatica moderada	\N
5	5	3	1	2026-09-23 09:00:00	Neumonia adquirida en la comunidad	\N	4	Neumonia bacteriana	\N
6	27	13	30	2026-08-02 22:15:00	Dolor abdominal agudo	\N	34	Abdomen agudo a descartar	1
7	21	13	28	2026-08-04 22:15:00	Trabajo de parto	\N	36	Embarazo a termino en trabajo de parto	0
8	26	7	18	2026-08-05 00:30:00	Herida por arma blanca	\N	17	Herida penetrante	4
9	13	1	3	2026-08-06 05:00:00	Control obstetrico de emergencia	\N	\N	Embarazo con amenaza de parto pretermino	3
10	4	1	1	2026-08-07 09:15:00	Deshidratacion por vomitos y diarrea	\N	\N	Gastroenteritis aguda	4
11	14	7	16	2026-08-14 11:15:00	Fiebre alta persistente	\N	\N	Sindrome febril en estudio	2
12	4	10	25	2026-08-14 17:00:00	Crisis asmatica	\N	28	Crisis asmatica moderada	1
13	1	1	11	2026-08-16 02:45:00	Deshidratacion por vomitos y diarrea	\N	7	Gastroenteritis aguda	4
14	26	13	28	2026-08-16 13:45:00	Crisis asmatica	\N	34	Crisis asmatica moderada	1
15	25	13	30	2026-08-19 23:00:00	Dificultad respiratoria	\N	33	Neumonia a descartar	1
16	21	10	24	2026-08-20 00:45:00	Trabajo de parto	\N	25	Embarazo a termino en trabajo de parto	1
17	24	7	20	2026-08-20 03:30:00	Intoxicacion alimentaria	\N	\N	Intoxicacion alimentaria	3
18	15	7	20	2026-08-20 12:00:00	Deshidratacion por vomitos y diarrea	\N	\N	Gastroenteritis aguda	3
19	27	7	18	2026-08-21 07:00:00	Dificultad respiratoria	\N	\N	Neumonia a descartar	2
20	8	7	18	2026-08-21 11:45:00	Intoxicacion alimentaria	\N	19	Intoxicacion alimentaria	3
21	4	4	14	2026-08-23 13:30:00	Trauma craneoencefalico por accidente de transito	\N	12	Trauma craneoencefalico leve	2
22	29	1	1	2026-08-23 14:45:00	Herida por arma blanca	\N	1	Herida penetrante	1
23	21	4	5	2026-08-23 17:30:00	Control obstetrico de emergencia	\N	6	Embarazo con amenaza de parto pretermino	1
24	25	4	12	2026-08-24 02:00:00	Herida por arma blanca	\N	13	Herida penetrante	1
25	13	1	3	2026-08-26 07:45:00	Dolor toracico opresivo	\N	8	Sindrome coronario agudo a descartar	3
26	24	13	31	2026-08-28 16:15:00	Deshidratacion por vomitos y diarrea	\N	35	Gastroenteritis aguda	0
27	11	1	11	2026-08-30 06:30:00	Convulsiones	\N	\N	Crisis convulsiva	5
28	3	13	28	2026-09-02 11:00:00	Convulsiones	\N	\N	Crisis convulsiva	2
29	1	1	11	2026-09-02 12:00:00	Intoxicacion alimentaria	\N	2	Intoxicacion alimentaria	3
30	2	4	15	2026-09-04 04:30:00	Convulsiones	\N	\N	Crisis convulsiva	2
31	19	10	24	2026-09-04 18:45:00	Convulsiones	\N	\N	Crisis convulsiva	3
32	17	10	24	2026-09-05 02:00:00	Intoxicacion alimentaria	\N	28	Intoxicacion alimentaria	1
33	18	10	22	2026-09-05 03:30:00	Dolor toracico opresivo	\N	25	Sindrome coronario agudo a descartar	0
34	3	10	24	2026-09-08 21:15:00	Intoxicacion alimentaria	\N	26	Intoxicacion alimentaria	0
35	26	1	1	2026-09-09 12:30:00	Herida por arma blanca	\N	\N	Herida penetrante	2
36	10	10	22	2026-09-10 13:15:00	Deshidratacion por vomitos y diarrea	\N	27	Gastroenteritis aguda	0
37	29	10	24	2026-09-11 02:00:00	Trabajo de parto	\N	26	Embarazo a termino en trabajo de parto	0
38	7	1	11	2026-09-11 05:30:00	Convulsiones	\N	\N	Crisis convulsiva	5
39	27	10	24	2026-09-11 14:15:00	Dolor toracico opresivo	\N	26	Sindrome coronario agudo a descartar	0
40	24	7	16	2026-09-11 19:30:00	Trauma craneoencefalico por accidente de transito	\N	18	Trauma craneoencefalico leve	2
41	11	1	1	2026-09-12 05:15:00	Deshidratacion por vomitos y diarrea	\N	2	Gastroenteritis aguda	2
42	19	7	18	2026-09-12 06:00:00	Fiebre alta persistente	\N	17	Sindrome febril en estudio	3
43	24	1	11	2026-09-12 06:30:00	Trauma craneoencefalico por accidente de transito	\N	8	Trauma craneoencefalico leve	2
44	7	4	5	2026-09-12 14:00:00	Herida por arma blanca	\N	11	Herida penetrante	2
45	1	1	2	2026-09-15 06:00:00	Trabajo de parto	\N	8	Embarazo a termino en trabajo de parto	4
46	27	1	3	2026-09-16 12:15:00	Deshidratacion por vomitos y diarrea	\N	8	Gastroenteritis aguda	1
47	23	7	18	2026-09-17 18:00:00	Intoxicacion alimentaria	\N	20	Intoxicacion alimentaria	0
48	16	4	12	2026-09-21 13:15:00	Dolor toracico opresivo	\N	6	Sindrome coronario agudo a descartar	2
49	23	10	22	2026-09-22 03:00:00	Deshidratacion por vomitos y diarrea	\N	25	Gastroenteritis aguda	1
50	4	4	12	2026-09-22 12:00:00	Dificultad respiratoria	\N	6	Neumonia a descartar	1
51	22	4	12	2026-09-27 00:15:00	Intoxicacion alimentaria	\N	13	Intoxicacion alimentaria	0
52	1	4	12	2026-09-27 06:30:00	Dolor abdominal agudo	\N	\N	Abdomen agudo a descartar	3
53	16	4	15	2026-09-27 08:30:00	Herida por arma blanca	\N	\N	Herida penetrante	2
54	10	1	2	2026-09-28 09:00:00	Dolor abdominal agudo	\N	2	Abdomen agudo a descartar	4
55	15	4	5	2026-09-29 03:15:00	Dolor abdominal agudo	\N	13	Abdomen agudo a descartar	1
56	20	4	15	2026-09-29 22:00:00	Herida por arma blanca	\N	13	Herida penetrante	0
57	15	4	5	2026-09-30 00:30:00	Fiebre alta persistente	\N	11	Sindrome febril en estudio	4
58	14	1	2	2026-09-30 08:45:00	Dificultad respiratoria	\N	\N	Neumonia a descartar	5
59	3	13	30	2026-10-02 07:15:00	Herida por arma blanca	\N	36	Herida penetrante	3
60	23	13	31	2026-10-02 17:30:00	Intoxicacion alimentaria	\N	35	Intoxicacion alimentaria	1
61	2	10	25	2026-10-02 19:30:00	Herida por arma blanca	\N	27	Herida penetrante	0
62	8	1	11	2026-10-03 03:30:00	Convulsiones	\N	8	Crisis convulsiva	2
63	3	1	2	2026-10-03 13:15:00	Fractura por caida	\N	\N	Fractura de tibia	2
64	21	10	25	2026-10-03 15:00:00	Fractura por caida	\N	26	Fractura de tibia	0
65	29	7	20	2026-10-05 02:30:00	Deshidratacion por vomitos y diarrea	\N	\N	Gastroenteritis aguda	5
66	7	13	28	2026-10-05 13:30:00	Trauma craneoencefalico por accidente de transito	\N	34	Trauma craneoencefalico leve	0
67	28	13	31	2026-10-05 15:30:00	Fiebre alta persistente	\N	33	Sindrome febril en estudio	1
68	24	1	11	2026-10-06 15:30:00	Dolor abdominal agudo	\N	2	Abdomen agudo a descartar	0
69	21	10	22	2026-10-07 13:00:00	Trabajo de parto	\N	26	Embarazo a termino en trabajo de parto	0
70	9	4	14	2026-10-08 03:15:00	Crisis asmatica	\N	12	Crisis asmatica moderada	1
71	4	1	1	2026-10-08 04:00:00	Convulsiones	\N	\N	Crisis convulsiva	3
72	21	13	28	2026-10-09 08:15:00	Trauma craneoencefalico por accidente de transito	\N	35	Trauma craneoencefalico leve	0
73	25	10	24	2026-10-09 13:30:00	Intoxicacion alimentaria	\N	28	Intoxicacion alimentaria	0
74	22	7	16	2026-10-10 01:45:00	Convulsiones	\N	17	Crisis convulsiva	4
75	2	4	15	2026-10-12 07:15:00	Crisis asmatica	\N	6	Crisis asmatica moderada	1
76	24	13	30	2026-10-15 07:15:00	Herida por arma blanca	\N	34	Herida penetrante	0
77	13	13	28	2026-10-15 07:30:00	Dolor toracico opresivo	\N	33	Sindrome coronario agudo a descartar	0
78	11	4	15	2026-10-15 22:15:00	Crisis asmatica	\N	13	Crisis asmatica moderada	0
79	11	1	2	2026-10-15 22:30:00	Fractura por caida	\N	\N	Fractura de tibia	3
80	8	1	2	2026-10-18 17:15:00	Dolor abdominal agudo	\N	2	Abdomen agudo a descartar	0
81	17	4	14	2026-10-21 11:00:00	Fiebre alta persistente	\N	6	Sindrome febril en estudio	2
82	14	13	28	2026-10-22 10:30:00	Dolor toracico opresivo	\N	\N	Sindrome coronario agudo a descartar	2
83	3	7	20	2026-10-22 23:15:00	Intoxicacion alimentaria	\N	18	Intoxicacion alimentaria	3
84	13	10	24	2026-10-24 00:30:00	Dolor abdominal agudo	\N	27	Abdomen agudo a descartar	0
85	21	13	28	2026-10-24 05:30:00	Control obstetrico de emergencia	\N	34	Embarazo con amenaza de parto pretermino	0
86	26	14	29	2026-08-07 10:15:00	Intervencion quirurgica: hernioplastia inguinal	\N	\N	Hernioplastia inguinal	\N
87	26	15	27	2026-08-07 13:11:00	Recuperacion postoperatoria de hernioplastia inguinal	\N	39	Postoperatorio	\N
88	5	1	1	2026-08-10 11:15:00	Cuadro agudo con indicacion quirurgica	\N	8	Apendicectomia convencional requerida	0
89	5	2	6	2026-08-10 12:15:00	Intervencion quirurgica: apendicectomia convencional	\N	\N	Apendicectomia convencional	\N
90	5	3	11	2026-08-10 14:45:00	Recuperacion postoperatoria de apendicectomia convencional	\N	9	Postoperatorio	\N
91	16	7	20	2026-08-11 09:00:00	Cuadro agudo con indicacion quirurgica	\N	19	Apendicectomia convencional requerida	0
92	16	8	17	2026-08-11 10:00:00	Intervencion quirurgica: apendicectomia convencional	\N	\N	Apendicectomia convencional	\N
93	16	9	20	2026-08-11 12:56:00	Recuperacion postoperatoria de apendicectomia convencional	\N	22	Postoperatorio	\N
94	4	1	2	2026-08-12 00:30:00	Cuadro agudo con indicacion quirurgica	\N	1	Apendicectomia convencional requerida	0
95	4	2	6	2026-08-12 01:30:00	Intervencion quirurgica: apendicectomia convencional	\N	\N	Apendicectomia convencional	\N
96	4	3	11	2026-08-12 04:16:00	Recuperacion postoperatoria de apendicectomia convencional	\N	4	Postoperatorio	\N
97	7	2	8	2026-08-13 07:15:00	Intervencion quirurgica: hernioplastia inguinal	\N	\N	Hernioplastia inguinal	\N
98	7	3	2	2026-08-13 10:17:00	Recuperacion postoperatoria de hernioplastia inguinal	\N	9	Postoperatorio	\N
99	14	2	7	2026-08-13 11:00:00	Intervencion quirurgica: artroscopia de rodilla	\N	\N	Artroscopia de rodilla	\N
100	2	5	13	2026-08-14 08:00:00	Intervencion quirurgica: hernioplastia inguinal	\N	\N	Hernioplastia inguinal	\N
101	2	6	12	2026-08-14 10:50:00	Recuperacion postoperatoria de hernioplastia inguinal	\N	14	Postoperatorio	\N
102	23	1	2	2026-08-22 16:30:00	Cuadro agudo con indicacion quirurgica	\N	7	Drenaje de absceso requerida	0
103	23	2	8	2026-08-22 17:30:00	Intervencion quirurgica: drenaje de absceso	\N	\N	Drenaje de absceso	\N
104	23	3	11	2026-08-22 19:41:00	Recuperacion postoperatoria de drenaje de absceso	\N	4	Postoperatorio	\N
105	23	14	32	2026-08-24 08:00:00	Intervencion quirurgica: artroscopia de rodilla	\N	\N	Artroscopia de rodilla	\N
106	23	15	30	2026-08-24 10:49:00	Recuperacion postoperatoria de artroscopia de rodilla	\N	38	Postoperatorio	\N
107	9	4	14	2026-09-05 16:45:00	Cuadro agudo con indicacion quirurgica	\N	13	Apendicectomia convencional requerida	0
108	9	5	13	2026-09-05 17:45:00	Intervencion quirurgica: apendicectomia convencional	\N	\N	Apendicectomia convencional	\N
109	9	6	14	2026-09-05 20:24:00	Recuperacion postoperatoria de apendicectomia convencional	\N	5	Postoperatorio	\N
110	4	2	6	2026-09-08 07:45:00	Intervencion quirurgica: hernioplastia inguinal	\N	\N	Hernioplastia inguinal	\N
111	4	3	11	2026-09-08 10:25:00	Recuperacion postoperatoria de hernioplastia inguinal	\N	10	Postoperatorio	\N
112	26	4	5	2026-09-10 16:15:00	Cuadro agudo con indicacion quirurgica	\N	6	Drenaje de absceso requerida	0
113	26	5	13	2026-09-10 17:15:00	Intervencion quirurgica: drenaje de absceso	\N	\N	Drenaje de absceso	\N
114	26	6	4	2026-09-10 19:10:00	Recuperacion postoperatoria de drenaje de absceso	\N	15	Postoperatorio	\N
115	17	10	25	2026-09-14 21:30:00	Cuadro agudo con indicacion quirurgica	\N	28	Colecistectomia laparoscopica requerida	0
116	17	11	26	2026-09-14 22:30:00	Intervencion quirurgica: colecistectomia laparoscopica	\N	\N	Colecistectomia laparoscopica	\N
117	11	1	1	2026-09-16 06:30:00	Cuadro agudo con indicacion quirurgica	\N	7	Laparotomia exploradora requerida	0
118	11	2	8	2026-09-16 07:30:00	Intervencion quirurgica: laparotomia exploradora	\N	\N	Laparotomia exploradora	\N
119	11	3	3	2026-09-16 11:54:00	Recuperacion postoperatoria de laparotomia exploradora	\N	3	Postoperatorio	\N
120	10	7	18	2026-09-28 23:15:00	Cuadro agudo con indicacion quirurgica	\N	19	Reduccion abierta de fractura de tibia requerida	0
121	10	8	19	2026-09-29 00:15:00	Intervencion quirurgica: reduccion abierta de fractura de tibia	\N	\N	Reduccion abierta de fractura de tibia	\N
122	10	9	9	2026-09-29 04:10:00	Recuperacion postoperatoria de reduccion abierta de fractura de tibia	\N	22	Postoperatorio	\N
123	13	14	29	2026-09-28 10:30:00	Intervencion quirurgica: hernioplastia inguinal	\N	\N	Hernioplastia inguinal	\N
124	13	15	27	2026-09-28 13:31:00	Recuperacion postoperatoria de hernioplastia inguinal	\N	37	Postoperatorio	\N
125	2	2	8	2026-09-29 10:30:00	Intervencion quirurgica: hernioplastia inguinal	\N	\N	Hernioplastia inguinal	\N
126	2	3	3	2026-09-29 13:11:00	Recuperacion postoperatoria de hernioplastia inguinal	\N	9	Postoperatorio	\N
127	6	2	6	2026-10-12 07:15:00	Intervencion quirurgica: hernioplastia inguinal	\N	\N	Hernioplastia inguinal	\N
128	6	3	2	2026-10-12 09:56:00	Recuperacion postoperatoria de hernioplastia inguinal	\N	4	Postoperatorio	\N
129	8	6	14	2026-09-23 11:00:00	Fractura de cadera	\N	5	Fractura de cadera	\N
130	16	12	21	2026-10-14 11:00:00	Neumonia adquirida en la comunidad	\N	30	Neumonia adquirida en la comunidad	\N
131	2	6	12	2026-09-26 12:00:00	Cetoacidosis diabetica	\N	14	Cetoacidosis diabetica	\N
132	26	6	4	2026-09-23 19:00:00	Fractura de cadera	\N	16	Fractura de cadera	\N
133	25	3	10	2026-09-17 07:00:00	Insuficiencia cardiaca descompensada	\N	3	Insuficiencia cardiaca descompensada	\N
134	9	3	11	2026-09-19 11:00:00	Fractura de cadera	\N	9	Fractura de cadera	\N
135	22	12	21	2026-10-06 08:00:00	Fractura de cadera	\N	30	Fractura de cadera	\N
136	20	9	16	2026-09-06 10:00:00	Anemia severa	\N	23	Anemia severa	\N
137	13	6	5	2026-09-16 17:00:00	Neumonia adquirida en la comunidad	\N	16	Neumonia adquirida en la comunidad	\N
138	1	3	11	2026-08-17 10:00:00	Fractura de cadera	\N	3	Fractura de cadera	\N
139	5	15	27	2026-09-18 20:00:00	Anemia severa	\N	37	Anemia severa	\N
140	5	6	5	2026-09-23 17:00:00	Anemia severa	\N	14	Anemia severa	\N
\.


--
-- Data for Name: instrumento; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.instrumento (id_instrumento, nombre, tipo, funcion, descripcion) FROM stdin;
1	Bisturi No. 4	Quirurgico	Corte	Mango de bisturi con hoja no. 4
2	Pinza Kelly	Quirurgico	Hemostatica	Pinza hemostatica curva
3	Separador de Farabeuf	Quirurgico	Retractor	Separador manual de tejidos
4	Porta-agujas Mayo-Hegar	Quirurgico	Accesorio	Para sutura manual
5	Tijera Metzenbaum	Quirurgico	Corte	Tijera de diseccion de tejido fino
6	Pinza de diseccion Adson	Quirurgico	Accesorio	Manipulacion de tejidos
7	Separador Gelpi	Quirurgico	Retractor	Separacion de planos
8	Clamp vascular	Quirurgico	Hemostatica	Control de sangrado
9	Taladro ortopedico	Quirurgico	Corte	Perforacion de hueso
10	Tijera Mayo	Quirurgico	Corte	Corte de suturas y tejido
\.


--
-- Data for Name: insumo; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.insumo (id_insumo, nombre, material, tipo, descripcion) FROM stdin;
1	Gasas esteriles	Textil	Quirurgico	Paquete de gasas esteriles para cirugia
2	Suero fisiologico 0.9%	Liquido	Medico	Solucion salina para hidratacion e irrigacion
3	Sutura Vicryl 2-0	Sintetico	Quirurgico	Sutura absorbible
4	Guantes esteriles	Latex	Medico	Guantes quirurgicos esteriles
5	Anestesico local Lidocaina 2%	Liquido	Medico	Anestesico de uso local
6	Compresas quirurgicas	Textil	Quirurgico	Compresas absorbentes esteriles
7	Sutura Nylon 3-0	Sintetico	Quirurgico	Sutura no absorbible
8	Solucion antiseptica yodada	Liquido	Medico	Antisepsia de la piel
9	Mascarilla quirurgica	Textil	Medico	Proteccion del equipo
10	Malla quirurgica	Polipropileno	Quirurgico	Refuerzo en hernioplastia
\.


--
-- Data for Name: insumo_utilizado_cirugia; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.insumo_utilizado_cirugia (id_cirugia, id_insumo, cantidad) FROM stdin;
1	1	8
1	2	2
1	3	1
2	3	10
2	8	4
2	2	4
3	3	1
3	9	1
3	6	5
4	9	3
4	5	1
4	3	3
5	2	10
5	10	8
5	1	7
6	9	9
6	2	4
6	7	2
7	5	11
7	4	9
7	6	7
8	6	3
8	5	10
8	7	10
9	1	4
9	4	1
9	5	2
10	8	1
10	10	1
10	6	3
11	7	11
11	3	12
11	6	8
12	1	4
12	6	11
12	3	1
13	6	6
13	4	7
13	1	6
14	2	3
14	9	1
14	7	3
15	9	9
15	2	4
15	3	2
16	3	9
16	9	6
16	7	8
17	2	1
17	5	14
17	6	5
18	6	6
18	8	1
18	1	7
19	3	5
19	2	5
19	5	7
\.


--
-- Data for Name: medicamento_recetado; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.medicamento_recetado (id_medicamento_recetado, id_receta, nombre, dosis, duracion) FROM stdin;
1	1	Paracetamol	500 mg cada 6 horas	5 dias
2	1	Loratadina	10 mg cada dia	5 dias
3	2	Losartan	50 mg cada dia	30 dias
4	3	Loratadina	10 mg cada dia	7 dias
5	3	Losartan	50 mg cada dia	30 dias
6	4	Paracetamol	500 mg cada 6 horas	5 dias
7	5	Loratadina	10 mg cada dia	7 dias
8	5	Losartan	50 mg cada dia	30 dias
9	5	Losartan	50 mg cada dia	30 dias
10	6	Omeprazol	20 mg cada dia	14 dias
11	6	Salbutamol	2 inhalaciones cada 6 horas	10 dias
12	6	Paracetamol	500 mg cada 6 horas	5 dias
13	7	Metformina	850 mg cada 12 horas	30 dias
14	7	Losartan	50 mg cada dia	30 dias
15	7	Omeprazol	20 mg cada dia	14 dias
16	8	Losartan	50 mg cada dia	30 dias
17	8	Salbutamol	2 inhalaciones cada 6 horas	10 dias
18	9	Loratadina	10 mg cada dia	7 dias
19	9	Omeprazol	20 mg cada dia	14 dias
20	9	Amoxicilina	500 mg cada 8 horas	7 dias
21	10	Metformina	850 mg cada 12 horas	30 dias
22	10	Paracetamol	500 mg cada 6 horas	5 dias
23	11	Loratadina	10 mg cada dia	7 dias
24	11	Amoxicilina	500 mg cada 8 horas	7 dias
25	11	Ibuprofeno	400 mg cada 8 horas	5 dias
26	12	Loratadina	10 mg cada dia	7 dias
27	12	Paracetamol	500 mg cada 6 horas	5 dias
28	12	Metformina	850 mg cada 12 horas	30 dias
29	13	Amoxicilina	500 mg cada 8 horas	7 dias
30	13	Ibuprofeno	400 mg cada 8 horas	5 dias
31	13	Ibuprofeno	400 mg cada 8 horas	5 dias
32	14	Loratadina	10 mg cada dia	7 dias
33	14	Paracetamol	500 mg cada 6 horas	5 dias
34	15	Loratadina	10 mg cada dia	7 dias
35	15	Losartan	50 mg cada dia	30 dias
36	16	Salbutamol	2 inhalaciones cada 6 horas	10 dias
37	17	Paracetamol	500 mg cada 6 horas	5 dias
38	18	Ibuprofeno	400 mg cada 8 horas	5 dias
39	19	Paracetamol	500 mg cada 6 horas	5 dias
40	19	Losartan	50 mg cada dia	30 dias
41	19	Ibuprofeno	400 mg cada 8 horas	5 dias
42	20	Omeprazol	20 mg cada dia	14 dias
43	20	Amoxicilina	500 mg cada 8 horas	7 dias
44	20	Ibuprofeno	400 mg cada 8 horas	5 dias
45	21	Ibuprofeno	400 mg cada 8 horas	5 dias
46	21	Metformina	850 mg cada 12 horas	30 dias
47	21	Loratadina	10 mg cada dia	7 dias
48	22	Salbutamol	2 inhalaciones cada 6 horas	10 dias
49	22	Ibuprofeno	400 mg cada 8 horas	5 dias
50	23	Salbutamol	2 inhalaciones cada 6 horas	10 dias
51	23	Losartan	50 mg cada dia	30 dias
52	23	Ibuprofeno	400 mg cada 8 horas	5 dias
53	24	Loratadina	10 mg cada dia	7 dias
54	24	Loratadina	10 mg cada dia	7 dias
55	25	Losartan	50 mg cada dia	30 dias
56	25	Losartan	50 mg cada dia	30 dias
57	25	Salbutamol	2 inhalaciones cada 6 horas	10 dias
58	26	Losartan	50 mg cada dia	30 dias
\.


--
-- Data for Name: medico; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.medico (id_medico, nombre, dpi, id_especialidad, tipo_medico, id_hospital, telefono, id_municipio, area, id_personal, tipo_personal, cargo, id_supervisor, salario, nivel_acceso) FROM stdin;
12	Dr. Luis Miguel Morales Velasquez	3000000000022	12	Residente	2	50000022	3	Urbana	22	Medico	Jefe de Servicio	4	16500.00	Avanzado
13	Dra. Sofia Marta Garcia Xitumul	3000000000023	17	Interno	2	50000023	3	Urbana	23	Medico	Jefe de Servicio	4	16500.00	Avanzado
15	Dra. Carmen Ana Alvarado Marroquin	3000000000025	1	Residente	2	50000025	3	Urbana	25	Medico	Medico	12	9700.00	Intermedio
16	Dr. Hugo Oscar Us Lopez	3000000000026	12	Residente	3	50000026	5	Urbana	26	Medico	Jefe de Servicio	9	16300.00	Avanzado
17	Dra. Rosa Lucia Ixcoy Cabrera	3000000000027	17	Interno	3	50000027	5	Urbana	27	Medico	Jefe de Servicio	9	16200.00	Avanzado
18	Dr. Mario Raul Vail Tzul	3000000000028	7	Residente	3	50000028	5	Urbana	28	Medico	Medico	16	11400.00	Intermedio
19	Dra. Maria Elena Giron Sican	3000000000029	23	Externo	3	50000029	5	Urbana	29	Medico	Medico	17	11000.00	Intermedio
20	Dr. Juan Jose Morales Giron	3000000000030	1	Residente	3	50000030	5	Urbana	30	Medico	Medico	16	11200.00	Intermedio
21	Dra. Teresa Patricia Garcia Ramirez	3000000000031	7	Residente	4	50000031	7	Urbana	31	Medico	Director Medico	\N	21100.00	Administrador
14	Dr. Andres Jorge Cabrera Ixcoy	3000000000024	7	Residente	2	50000024	3	Urbana	24	Medico	Medico	12	10300.00	Avanzado
24	Dr. Luis Miguel Us Toc	3000000000034	1	Residente	4	50000034	7	Rural	34	Medico	Medico	22	10500.00	Intermedio
11	Dra. Gloria Julia Giron Morales	3000000000021	1	Residente	1	50000021	1	Urbana	21	Medico	Medico	3	9790.00	Intermedio
1	Dr. Luis Fernando Sican Toc	1111222233341	7	Residente	1	77611001	1	Urbana	1	Medico	Director Medico	\N	18500.00	Administrador
2	Dra. Gabriela Marisol Cabrera Us	2222333344452	12	Residente	1	77611002	1	Urbana	2	Medico	Jefe de Servicio	1	15300.00	Avanzado
3	Dr. Edgar Rolando Velasquez Marroquin	3333444455563	1	Interno	1	77611003	\N	\N	3	Medico	Medico	2	10100.00	Intermedio
4	Dra. Silvia Patricia Xitumul Us	4444555566674	4	Residente	2	77762211	3	Urbana	4	Medico	Director Medico	\N	21900.00	Administrador
5	Dr. Mario Estuardo Chocoj Vail	5555666677785	7	Residente	2	77762212	3	Urbana	5	Medico	Jefe de Servicio	4	16100.00	Avanzado
6	Dr. Julio Cesar Argueta Giron	6666777788896	17	Residente	1	77611006	1	Urbana	6	Medico	Jefe de Servicio	1	16600.00	Avanzado
7	Dr. Byron Estuardo Giron Cotzojay	7777888899907	23	Externo	1	48870077	\N	\N	7	Medico	Medico	6	11500.00	Basico
8	Dr. Rigoberto Tepaz Chocoj	8888999900018	17	Interno	1	77611008	1	Urbana	8	Medico	Medico	6	11900.00	Intermedio
9	Dra. Claudia Beatriz Us Batz	9999000011129	7	Residente	3	77641181	5	Urbana	9	Medico	Director Medico	\N	18400.00	Administrador
10	Dra. Karla Beatriz Tzul Ixcoy	0000111122230	6	Residente	1	77611010	1	Urbana	10	Medico	Medico	2	11600.00	Intermedio
22	Dr. Pedro Carlos Cabrera Perez	3000000000032	12	Residente	4	50000032	7	Urbana	32	Medico	Jefe de Servicio	21	16000.00	Avanzado
23	Dra. Gloria Julia Alvarado Us	3000000000033	17	Interno	4	50000033	7	Urbana	33	Medico	Jefe de Servicio	21	16400.00	Avanzado
25	Dra. Sofia Marta Ixcoy Tepaz	3000000000035	1	Residente	4	50000035	7	Urbana	35	Medico	Medico	22	9000.00	Intermedio
26	Dr. Andres Jorge Vail Garcia	3000000000036	18	Externo	4	50000036	7	Urbana	36	Medico	Medico	23	8000.00	Intermedio
27	Dra. Carmen Ana Giron Mendez	3000000000037	7	Residente	5	50000037	9	Urbana	37	Medico	Director Medico	\N	20500.00	Administrador
28	Dr. Hugo Oscar Morales Chocoj	3000000000038	12	Residente	5	50000038	9	Urbana	38	Medico	Jefe de Servicio	27	14300.00	Basico
29	Dra. Rosa Lucia Garcia Vail	3000000000039	17	Interno	5	50000039	9	Urbana	39	Medico	Jefe de Servicio	27	14500.00	Avanzado
30	Dr. Mario Raul Cabrera Argueta	3000000000040	7	Residente	5	50000040	9	Urbana	40	Medico	Medico	28	9200.00	Intermedio
31	Dra. Maria Elena Alvarado De Leon	3000000000041	1	Residente	5	50000041	9	Urbana	41	Medico	Medico	28	11300.00	Intermedio
32	Dr. Juan Jose Us Alvarado	3000000000042	23	Externo	5	50000042	9	Urbana	42	Medico	Medico	29	8400.00	Intermedio
\.


--
-- Data for Name: municipio; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.municipio (id_municipio, id_departamento, nombre) FROM stdin;
1	1	Quetzaltenango
2	1	Coatepeque
3	2	San Marcos
4	2	Malacatan
5	3	Huehuetenango
6	3	Jacaltenango
7	4	Retalhuleu
8	4	Champerico
9	5	Totonicapan
10	5	Momostenango
\.


--
-- Data for Name: paciente; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.paciente (id_paciente, no_expediente, nombres, apellidos, sexo, fecha_nacimiento, id_municipio, area, dpi, telefono, no_seguro_social) FROM stdin;
1	EXP-2026-0001	Maria	Xitumul Tzul	F	1990-03-14	1	Urbana	1234567890101	55123456	IGSS-880011
2	EXP-2026-0002	Jose Manuel	Garcia Lopez	M	1975-11-02	2	Rural	2345678901202	42198765	\N
3	EXP-2026-0003	Juana	Us Chocoj	F	2003-07-22	3	Rural	3456789012303	30456789	\N
4	EXP-2026-0004	Carlos Alberto	Morales Ramirez	M	1988-05-30	4	Urbana	4567890123404	51122334	IGSS-770234
5	EXP-2026-0005	Rosa Elvira	Tepaz Batz	F	1965-01-09	5	Urbana	5678901234505	77650099	IGSS-650098
6	EXP-2026-0006	Miguel Angel	De Leon Argueta	M	1999-09-19	6	Rural	6789012345606	48871122	\N
7	EXP-2026-0007	Ana Lucia	Marroquin Giron	F	1980-12-25	7	Urbana	7890123456707	33445566	IGSS-800456
8	EXP-2026-0008	Pedro	Cotzojay Ixcoy	M	2010-02-14	10	Rural	8901234567808	30112233	\N
9	EXP-2026-0009	Teresa Patricia	Ixcoy Batz	F	2019-10-16	8	Rural	\N	30000009	IGSS-900153
10	EXP-2026-0010	Pedro Carlos	Vail Cotzojay	M	1952-03-27	1	Urbana	4000000000010	30000010	\N
11	EXP-2026-0011	Gloria Julia	Giron Morales	F	1987-08-10	4	Rural	4000000000011	30000011	\N
12	EXP-2026-0012	Luis Miguel	Morales Velasquez	M	1994-01-21	7	Rural	4000000000012	30000012	IGSS-900204
13	EXP-2026-0013	Sofia Marta	Garcia Xitumul	F	2008-06-04	10	Rural	\N	30000013	\N
14	EXP-2026-0014	Andres Jorge	Cabrera Ixcoy	M	1976-11-15	3	Urbana	4000000000014	30000014	\N
15	EXP-2026-0015	Carmen Ana	Alvarado Marroquin	F	1961-04-26	6	Rural	4000000000015	30000015	IGSS-900255
16	EXP-2026-0016	Hugo Oscar	Us Lopez	M	2001-09-09	9	Rural	4000000000016	30000016	\N
17	EXP-2026-0017	Rosa Lucia	Ixcoy Cabrera	F	1983-02-20	2	Rural	4000000000017	30000017	\N
18	EXP-2026-0018	Mario Raul	Vail Tzul	M	1999-07-03	5	Urbana	4000000000018	30000018	IGSS-900306
19	EXP-2026-0019	Maria Elena	Giron Sican	F	2015-12-14	8	Rural	\N	30000019	\N
20	EXP-2026-0020	Juan Jose	Morales Giron	M	1948-05-25	1	Rural	4000000000020	30000020	\N
21	EXP-2026-0021	Teresa Patricia	Garcia Ramirez	F	1970-10-08	4	Rural	4000000000021	30000021	IGSS-900357
22	EXP-2026-0022	Pedro Carlos	Cabrera Perez	M	1991-03-19	7	Urbana	4000000000022	30000022	\N
23	EXP-2026-0023	Gloria Julia	Alvarado Us	F	1980-08-02	10	Rural	4000000000023	30000023	\N
24	EXP-2026-0024	Luis Miguel	Us Toc	M	2022-01-13	3	Rural	\N	30000024	IGSS-900408
25	EXP-2026-0025	Sofia Marta	Ixcoy Tepaz	F	1958-06-24	6	Rural	4000000000025	30000025	\N
26	EXP-2026-0026	Andres Jorge	Vail Garcia	M	1996-11-07	9	Urbana	4000000000026	30000026	\N
27	EXP-2026-0027	Carmen Ana	Giron Mendez	F	1973-04-18	2	Rural	4000000000027	30000027	IGSS-900459
28	EXP-2026-0028	Hugo Oscar	Morales Chocoj	M	2005-09-01	5	Rural	4000000000028	30000028	\N
29	EXP-2026-0029	Rosa Lucia	Garcia Vail	F	1985-02-12	8	Rural	4000000000029	30000029	\N
30	EXP-2026-0030	Mario Raul	Cabrera Argueta	M	1967-07-23	1	Urbana	4000000000030	30000030	IGSS-900510
\.


--
-- Data for Name: personal; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.personal (id_personal, tipo_personal, nombre, dpi, fecha_contratacion, telefono, direccion) FROM stdin;
21	Medico	Dra. Gloria Julia Giron Morales	3000000000021	2024-02-01	50000021	4 calle 10-77, zona 4, Quetzaltenango
22	Medico	Dr. Luis Miguel Morales Velasquez	3000000000022	2014-04-05	50000022	5 avenida 11-84, zona 5, San Marcos
23	Medico	Dra. Sofia Marta Garcia Xitumul	3000000000023	2024-12-30	50000023	6 calle 12-11, zona 6, San Marcos
24	Medico	Dr. Andres Jorge Cabrera Ixcoy	3000000000024	2021-01-18	50000024	7 avenida 1-18, zona 1, San Marcos
25	Medico	Dra. Carmen Ana Alvarado Marroquin	3000000000025	2018-09-19	50000025	8 calle 2-25, zona 2, San Marcos
26	Medico	Dr. Hugo Oscar Us Lopez	3000000000026	2022-11-29	50000026	9 avenida 3-32, zona 3, Huehuetenango
27	Medico	Dra. Rosa Lucia Ixcoy Cabrera	3000000000027	2019-08-23	50000027	1 calle 4-39, zona 4, Huehuetenango
28	Medico	Dr. Mario Raul Vail Tzul	3000000000028	2021-10-19	50000028	2 avenida 5-46, zona 5, Huehuetenango
29	Medico	Dra. Maria Elena Giron Sican	3000000000029	2021-12-31	50000029	3 calle 6-53, zona 6, Huehuetenango
30	Medico	Dr. Juan Jose Morales Giron	3000000000030	2022-06-11	50000030	4 avenida 7-60, zona 1, Huehuetenango
31	Medico	Dra. Teresa Patricia Garcia Ramirez	3000000000031	2025-07-09	50000031	5 calle 8-67, zona 2, Retalhuleu
32	Medico	Dr. Pedro Carlos Cabrera Perez	3000000000032	2015-09-18	50000032	6 avenida 9-74, zona 3, Retalhuleu
33	Medico	Dra. Gloria Julia Alvarado Us	3000000000033	2021-08-20	50000033	7 calle 10-81, zona 4, Retalhuleu
34	Medico	Dr. Luis Miguel Us Toc	3000000000034	2016-01-05	50000034	8 avenida 11-88, zona 5, Retalhuleu
35	Medico	Dra. Sofia Marta Ixcoy Tepaz	3000000000035	2026-07-03	50000035	9 calle 12-15, zona 6, Retalhuleu
36	Medico	Dr. Andres Jorge Vail Garcia	3000000000036	2026-01-25	50000036	1 avenida 1-22, zona 1, Retalhuleu
37	Medico	Dra. Carmen Ana Giron Mendez	3000000000037	2020-07-21	50000037	2 calle 2-29, zona 2, Totonicapan
38	Medico	Dr. Hugo Oscar Morales Chocoj	3000000000038	2020-06-14	50000038	3 avenida 3-36, zona 3, Totonicapan
39	Medico	Dra. Rosa Lucia Garcia Vail	3000000000039	2024-04-05	50000039	4 calle 4-43, zona 4, Totonicapan
40	Medico	Dr. Mario Raul Cabrera Argueta	3000000000040	2017-02-28	50000040	5 avenida 5-50, zona 5, Totonicapan
41	Medico	Dra. Maria Elena Alvarado De Leon	3000000000041	2020-12-06	50000041	6 calle 6-57, zona 6, Totonicapan
42	Medico	Dr. Juan Jose Us Alvarado	3000000000042	2014-07-22	50000042	7 avenida 7-64, zona 1, Totonicapan
43	Enfermero	Gloria Julia Alvarado Us	3000000000043	2025-07-04	\N	8 calle 8-71, zona 2, Quetzaltenango
44	Enfermero	Ana Carmen Us Toc	3000000000044	2023-12-21	\N	9 avenida 9-78, zona 3, San Marcos
45	Enfermero	Jorge Andres Ixcoy Tepaz	3000000000045	2020-02-19	\N	1 calle 10-85, zona 4, San Marcos
46	Enfermero	Marta Sofia Vail Garcia	3000000000046	2020-01-29	\N	2 avenida 11-12, zona 5, Huehuetenango
47	Enfermero	Carmen Ana Giron Mendez	3000000000047	2021-03-03	\N	3 calle 12-19, zona 6, Huehuetenango
48	Enfermero	Hugo Oscar Morales Chocoj	3000000000048	2020-09-25	\N	4 avenida 1-26, zona 1, Retalhuleu
49	Enfermero	Rosa Lucia Garcia Vail	3000000000049	2017-01-06	\N	5 calle 2-33, zona 2, Retalhuleu
50	Enfermero	Patricia Teresa Cabrera Argueta	3000000000050	2020-06-21	\N	6 avenida 3-40, zona 3, Totonicapan
51	Enfermero	Jose Juan Alvarado De Leon	3000000000051	2025-12-28	\N	7 calle 4-47, zona 4, Totonicapan
52	Encargado	Carmen Ana Giron Mendez	3000000000052	2022-07-27	50000052	8 avenida 5-54, zona 5, Quetzaltenango
53	Encargado	Hugo Oscar Morales Chocoj	3000000000053	2022-03-21	50000053	9 calle 6-61, zona 6, San Marcos
54	Encargado	Rosa Lucia Garcia Vail	3000000000054	2021-08-03	50000054	1 avenida 7-68, zona 1, San Marcos
55	Encargado	Mario Raul Cabrera Argueta	3000000000055	2025-09-22	50000055	2 calle 8-75, zona 2, Huehuetenango
56	Encargado	Maria Elena Alvarado De Leon	3000000000056	2017-04-21	50000056	3 avenida 9-82, zona 3, Huehuetenango
57	Encargado	Juan Jose Us Alvarado	3000000000057	2020-10-08	50000057	4 calle 10-89, zona 4, Retalhuleu
58	Encargado	Teresa Patricia Ixcoy Batz	3000000000058	2021-09-05	50000058	5 avenida 11-16, zona 5, Retalhuleu
59	Encargado	Pedro Carlos Vail Cotzojay	3000000000059	2024-12-31	50000059	6 calle 12-23, zona 6, Retalhuleu
60	Encargado	Gloria Julia Giron Morales	3000000000060	2024-05-30	50000060	7 avenida 1-30, zona 1, Totonicapan
61	Encargado	Luis Miguel Morales Velasquez	3000000000061	2025-09-20	50000061	8 calle 2-37, zona 2, Totonicapan
62	Encargado	Sofia Marta Garcia Xitumul	3000000000062	2022-09-24	50000062	9 avenida 3-44, zona 3, Totonicapan
1	Medico	Dr. Luis Fernando Sican Toc	1111222233341	2023-01-05	77611001	2 calle 2-17, zona 2, Quetzaltenango
2	Medico	Dra. Gabriela Marisol Cabrera Us	2222333344452	2020-12-05	77611002	3 avenida 3-24, zona 3, Quetzaltenango
3	Medico	Dr. Edgar Rolando Velasquez Marroquin	3333444455563	2023-10-07	77611003	4 calle 4-31, zona 4, Quetzaltenango
4	Medico	Dra. Silvia Patricia Xitumul Us	4444555566674	2017-10-19	77762211	5 avenida 5-38, zona 5, San Marcos
5	Medico	Dr. Mario Estuardo Chocoj Vail	5555666677785	2021-06-02	77762212	6 calle 6-45, zona 6, San Marcos
6	Medico	Dr. Julio Cesar Argueta Giron	6666777788896	2024-08-25	77611006	7 avenida 7-52, zona 1, Quetzaltenango
7	Medico	Dr. Byron Estuardo Giron Cotzojay	7777888899907	2022-09-30	48870077	8 calle 8-59, zona 2, Quetzaltenango
8	Medico	Dr. Rigoberto Tepaz Chocoj	8888999900018	2023-07-04	77611008	9 avenida 9-66, zona 3, Quetzaltenango
9	Medico	Dra. Claudia Beatriz Us Batz	9999000011129	2023-08-14	77641181	1 calle 10-73, zona 4, Huehuetenango
10	Medico	Dra. Karla Beatriz Tzul Ixcoy	0000111122230	2012-07-26	77611010	2 avenida 11-80, zona 5, Quetzaltenango
11	Enfermero	Marta Lidia Ixcoy Us	1212121212121	2024-11-27	\N	3 calle 12-87, zona 6, San Marcos
12	Enfermero	Jose Domingo Chocoj Tzul	1313131313131	2017-01-13	\N	4 avenida 1-14, zona 1, Huehuetenango
13	Enfermero	Blanca Estela Vail Marroquin	1414141414141	2014-11-22	\N	5 calle 2-21, zona 2, Retalhuleu
14	Enfermero	Wilson Aroldo Giron Argueta	1515151515151	2013-02-04	\N	6 avenida 3-28, zona 3, Totonicapan
15	Enfermero	Petrona Us Cotzojay	1616161616161	2023-09-26	\N	7 calle 4-35, zona 4, Quetzaltenango
16	Enfermero	Hugo Leonel Batz Sican	1717171717171	2014-04-20	\N	8 avenida 5-42, zona 5, San Marcos
17	Encargado	Sofia Elizabeth Marroquin Toc	2121212121212	2025-12-15	77611020	9 calle 6-49, zona 6, Huehuetenango
18	Encargado	Ruben Alexander Us Giron	2222222222223	2021-08-18	77611021	1 avenida 7-56, zona 1, Retalhuleu
19	Encargado	Deysi Marisol Chocoj Argueta	2323232323232	2022-07-17	77762220	2 calle 8-63, zona 2, Totonicapan
20	Encargado	Anselmo Tzul Vail	2424242424242	2015-03-12	77641190	3 avenida 9-70, zona 3, Quetzaltenango
\.


--
-- Data for Name: personal_encargado; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.personal_encargado (id_encargado, nombre, dpi, puesto, id_hospital, telefono, id_personal, tipo_personal) FROM stdin;
1	Sofia Elizabeth Marroquin Toc	2121212121212	Jefa de Recepcion	1	77611020	17	Encargado
2	Ruben Alexander Us Giron	2222222222223	Encargado de Admisiones	1	77611021	18	Encargado
3	Deysi Marisol Chocoj Argueta	2323232323232	Encargada de Facturacion	2	77762220	19	Encargado
4	Anselmo Tzul Vail	2424242424242	Coordinador de Turno	3	77641190	20	Encargado
5	Carmen Ana Giron Mendez	3000000000052	Recepcion	1	50000052	52	Encargado
6	Hugo Oscar Morales Chocoj	3000000000053	Admisiones	2	50000053	53	Encargado
7	Rosa Lucia Garcia Vail	3000000000054	Facturacion	2	50000054	54	Encargado
8	Mario Raul Cabrera Argueta	3000000000055	Archivo Clinico	3	50000055	55	Encargado
9	Maria Elena Alvarado De Leon	3000000000056	Trabajo Social	3	50000056	56	Encargado
10	Juan Jose Us Alvarado	3000000000057	Coordinador de Turno	4	50000057	57	Encargado
11	Teresa Patricia Ixcoy Batz	3000000000058	Recepcion	4	50000058	58	Encargado
12	Pedro Carlos Vail Cotzojay	3000000000059	Admisiones	4	50000059	59	Encargado
13	Gloria Julia Giron Morales	3000000000060	Facturacion	5	50000060	60	Encargado
14	Luis Miguel Morales Velasquez	3000000000061	Archivo Clinico	5	50000061	61	Encargado
15	Sofia Marta Garcia Xitumul	3000000000062	Trabajo Social	5	50000062	62	Encargado
\.


--
-- Data for Name: quirofano; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.quirofano (id_quirofano, id_hospital, numero, estado) FROM stdin;
1	1	1	Ocupado
2	1	2	Libre
3	2	1	Libre
4	2	2	Libre
5	3	1	Libre
6	3	2	Libre
7	4	1	Libre
8	4	2	Libre
9	5	1	Libre
10	5	2	Libre
\.


--
-- Data for Name: receta_medica; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.receta_medica (id_receta, id_consulta, fecha, id_hospital, proxima_cita, numero_clinica) FROM stdin;
1	1	2026-09-10	1	2026-10-10	3
2	2	2026-09-15	1	2026-11-15	5
3	4	2026-08-02	1	2026-09-15	2
4	5	2026-08-05	1	2026-08-24	2
5	6	2026-08-08	1	\N	2
6	7	2026-08-13	3	\N	1
7	9	2026-08-20	4	\N	7
8	10	2026-08-21	2	2026-09-16	6
9	11	2026-08-21	5	2026-10-04	4
10	12	2026-08-23	5	2026-09-06	5
11	13	2026-08-24	2	2026-09-30	7
12	15	2026-08-30	2	2026-10-27	6
13	16	2026-09-04	4	\N	8
14	17	2026-09-05	2	2026-10-24	7
15	19	2026-09-09	5	2026-10-11	1
16	20	2026-09-11	3	2026-11-04	3
17	22	2026-09-13	1	2026-10-31	3
18	23	2026-09-19	3	2026-10-13	3
19	24	2026-09-24	5	\N	1
20	25	2026-09-28	4	2026-10-21	4
21	27	2026-10-08	1	\N	3
22	28	2026-10-09	1	2026-11-14	3
23	29	2026-10-09	4	2026-11-14	4
24	30	2026-10-11	1	\N	3
25	32	2026-10-17	4	2026-12-02	4
26	33	2026-10-22	1	2026-12-04	3
\.


--
-- Data for Name: registro_procedimiento_cirugia; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.registro_procedimiento_cirugia (id_registro, id_cirugia, etapa, procedimiento, resultado, hora_registro, id_enfermero, descripcion) FROM stdin;
1	1	Preoperatorio	Entrada: brazalete de identificacion y ficha clinica	Aceptable	2026-09-20 16:00:00	1	Paciente confirma nombre y procedimiento a realizar
2	1	Intraoperatorio	Chequeo en quirofano	Aceptable	2026-09-20 16:15:00	1	Equipo completo y camilla trasladada correctamente
3	1	Intraoperatorio	Procedimientos de pausa quirurgica	Aceptable	2026-09-20 16:20:00	1	Confirmacion de paciente, equipo y esterilidad
4	1	Intraoperatorio	Gestion de cuidados intraoperatoria: balance hidrico	Exito	2026-09-20 17:00:00	1	Balance hidrico dentro de parametros normales
5	1	Intraoperatorio	Salida quirurgica: conteo de instrumental	Aceptable	2026-09-20 17:40:00	1	Conteo de instrumental satisfactorio, cierre de incision
6	1	Postoperatorio	Ingreso a sala de recuperacion	Exito	2026-09-20 17:50:00	3	Sin complicaciones durante la cirugia
7	1	Postoperatorio	Traslado seguro a Hospitalizacion	Exito	2026-09-20 19:00:00	3	Signos vitales normales, zona operatoria limpia
8	2	Preoperatorio	Entrada: brazalete de identificacion y ficha clinica	Aceptable	2026-08-07 10:15:00	14	Sin complicaciones
9	2	Intraoperatorio	Chequeo en quirofano	Aceptable	2026-08-07 10:53:00	14	Sin complicaciones
10	2	Intraoperatorio	Procedimientos de pausa quirurgica	Exito	2026-08-07 11:12:00	14	Sin complicaciones
11	2	Intraoperatorio	Gestion de cuidados intraoperatoria: balance hidrico	Falla	2026-08-07 11:30:00	14	Sin complicaciones
12	2	Intraoperatorio	Salida quirurgica: conteo de instrumental	Exito	2026-08-07 11:49:00	14	Sin complicaciones
13	2	Postoperatorio	Ingreso a sala de recuperacion	Exito	2026-08-07 12:36:00	14	Sin complicaciones
14	2	Postoperatorio	Traslado seguro a Hospitalizacion	Exito	2026-08-07 12:46:00	14	Sin complicaciones
15	3	Preoperatorio	Entrada: brazalete de identificacion y ficha clinica	Aceptable	2026-08-10 12:15:00	3	Sin complicaciones
16	3	Intraoperatorio	Chequeo en quirofano	Aceptable	2026-08-10 12:49:00	3	Sin complicaciones
17	3	Intraoperatorio	Procedimientos de pausa quirurgica	Exito	2026-08-10 13:03:00	3	Sin complicaciones
18	3	Intraoperatorio	Gestion de cuidados intraoperatoria: balance hidrico	Aceptable	2026-08-10 13:17:00	3	Sin complicaciones
19	3	Intraoperatorio	Salida quirurgica: conteo de instrumental	Aceptable	2026-08-10 13:31:00	3	Sin complicaciones
20	3	Postoperatorio	Ingreso a sala de recuperacion	Exito	2026-08-10 14:10:00	3	Sin complicaciones
21	3	Postoperatorio	Traslado seguro a Hospitalizacion	Exito	2026-08-10 14:20:00	3	Sin complicaciones
22	4	Preoperatorio	Entrada: brazalete de identificacion y ficha clinica	Aceptable	2026-08-11 10:00:00	6	Sin complicaciones
23	4	Intraoperatorio	Chequeo en quirofano	Aceptable	2026-08-11 10:38:00	6	Sin complicaciones
24	4	Intraoperatorio	Procedimientos de pausa quirurgica	Exito	2026-08-11 10:57:00	6	Sin complicaciones
25	4	Intraoperatorio	Gestion de cuidados intraoperatoria: balance hidrico	Aceptable	2026-08-11 11:15:00	6	Sin complicaciones
26	4	Intraoperatorio	Salida quirurgica: conteo de instrumental	Exito	2026-08-11 11:34:00	6	Sin complicaciones
27	4	Postoperatorio	Ingreso a sala de recuperacion	Exito	2026-08-11 12:21:00	6	Sin complicaciones
28	4	Postoperatorio	Traslado seguro a Hospitalizacion	Exito	2026-08-11 12:31:00	6	Sin complicaciones
29	5	Preoperatorio	Entrada: brazalete de identificacion y ficha clinica	Aceptable	2026-08-12 01:30:00	1	Sin complicaciones
30	5	Intraoperatorio	Chequeo en quirofano	Exito	2026-08-12 02:06:00	1	Sin complicaciones
31	5	Intraoperatorio	Procedimientos de pausa quirurgica	Aceptable	2026-08-12 02:23:00	1	Sin complicaciones
32	5	Intraoperatorio	Gestion de cuidados intraoperatoria: balance hidrico	No aceptable	2026-08-12 02:40:00	1	Sin complicaciones
33	5	Intraoperatorio	Salida quirurgica: conteo de instrumental	Aceptable	2026-08-12 02:57:00	1	Sin complicaciones
34	5	Postoperatorio	Ingreso a sala de recuperacion	Exito	2026-08-12 03:41:00	1	Sin complicaciones
35	5	Postoperatorio	Traslado seguro a Hospitalizacion	Exito	2026-08-12 03:51:00	1	Sin complicaciones
36	6	Preoperatorio	Entrada: brazalete de identificacion y ficha clinica	Aceptable	2026-08-13 07:15:00	1	Sin complicaciones
37	6	Intraoperatorio	Chequeo en quirofano	Aceptable	2026-08-13 07:54:00	1	Sin complicaciones
38	6	Intraoperatorio	Procedimientos de pausa quirurgica	Aceptable	2026-08-13 08:14:00	1	Sin complicaciones
39	6	Intraoperatorio	Gestion de cuidados intraoperatoria: balance hidrico	Exito	2026-08-13 08:33:00	1	Sin complicaciones
40	6	Intraoperatorio	Salida quirurgica: conteo de instrumental	Exito	2026-08-13 08:53:00	1	Sin complicaciones
41	6	Postoperatorio	Ingreso a sala de recuperacion	Exito	2026-08-13 09:42:00	1	Sin complicaciones
42	6	Postoperatorio	Traslado seguro a Hospitalizacion	Exito	2026-08-13 09:52:00	1	Sin complicaciones
43	7	Preoperatorio	Entrada: brazalete de identificacion y ficha clinica	Aceptable	2026-08-13 11:00:00	3	Sin complicaciones
44	7	Intraoperatorio	Chequeo en quirofano	Aceptable	2026-08-13 11:37:00	3	Sin complicaciones
45	7	Intraoperatorio	Procedimientos de pausa quirurgica	Exito	2026-08-13 11:54:00	3	Sin complicaciones
46	7	Intraoperatorio	Gestion de cuidados intraoperatoria: balance hidrico	Medianamente aceptable	2026-08-13 12:11:00	3	Sin complicaciones
47	7	Intraoperatorio	Salida quirurgica: conteo de instrumental	Aceptable	2026-08-13 12:28:00	3	Sin complicaciones
48	8	Preoperatorio	Entrada: brazalete de identificacion y ficha clinica	Aceptable	2026-08-14 08:00:00	9	Sin complicaciones
49	8	Intraoperatorio	Chequeo en quirofano	Exito	2026-08-14 08:37:00	9	Sin complicaciones
50	8	Intraoperatorio	Procedimientos de pausa quirurgica	Exito	2026-08-14 08:55:00	9	Sin complicaciones
51	8	Intraoperatorio	Gestion de cuidados intraoperatoria: balance hidrico	Medianamente aceptable	2026-08-14 09:12:00	9	Sin complicaciones
52	8	Intraoperatorio	Salida quirurgica: conteo de instrumental	Exito	2026-08-14 09:30:00	9	Sin complicaciones
53	8	Postoperatorio	Ingreso a sala de recuperacion	Exito	2026-08-14 10:15:00	9	Sin complicaciones
54	8	Postoperatorio	Traslado seguro a Hospitalizacion	Exito	2026-08-14 10:25:00	9	Sin complicaciones
55	9	Preoperatorio	Entrada: brazalete de identificacion y ficha clinica	Aceptable	2026-08-22 17:30:00	2	Sin complicaciones
56	9	Intraoperatorio	Chequeo en quirofano	Aceptable	2026-08-22 18:01:00	2	Sin complicaciones
57	9	Intraoperatorio	Procedimientos de pausa quirurgica	Exito	2026-08-22 18:12:00	2	Sin complicaciones
58	9	Intraoperatorio	Gestion de cuidados intraoperatoria: balance hidrico	Aceptable	2026-08-22 18:23:00	2	Sin complicaciones
59	9	Intraoperatorio	Salida quirurgica: conteo de instrumental	Exito	2026-08-22 18:34:00	2	Sin complicaciones
60	9	Postoperatorio	Ingreso a sala de recuperacion	Exito	2026-08-22 19:06:00	2	Sin complicaciones
61	9	Postoperatorio	Traslado seguro a Hospitalizacion	Exito	2026-08-22 19:16:00	2	Sin complicaciones
62	10	Preoperatorio	Entrada: brazalete de identificacion y ficha clinica	Aceptable	2026-08-24 08:00:00	15	Sin complicaciones
63	10	Intraoperatorio	Chequeo en quirofano	Exito	2026-08-24 08:37:00	15	Sin complicaciones
64	10	Intraoperatorio	Procedimientos de pausa quirurgica	Aceptable	2026-08-24 08:54:00	15	Sin complicaciones
65	10	Intraoperatorio	Gestion de cuidados intraoperatoria: balance hidrico	Aceptable	2026-08-24 09:12:00	15	Sin complicaciones
66	10	Intraoperatorio	Salida quirurgica: conteo de instrumental	Exito	2026-08-24 09:29:00	15	Sin complicaciones
67	10	Postoperatorio	Ingreso a sala de recuperacion	Exito	2026-08-24 10:14:00	15	Sin complicaciones
68	10	Postoperatorio	Traslado seguro a Hospitalizacion	Exito	2026-08-24 10:24:00	15	Sin complicaciones
69	11	Preoperatorio	Entrada: brazalete de identificacion y ficha clinica	Aceptable	2026-09-05 17:45:00	5	Sin complicaciones
70	11	Intraoperatorio	Chequeo en quirofano	Aceptable	2026-09-05 18:20:00	5	Sin complicaciones
71	11	Intraoperatorio	Procedimientos de pausa quirurgica	Exito	2026-09-05 18:36:00	5	Sin complicaciones
72	11	Intraoperatorio	Gestion de cuidados intraoperatoria: balance hidrico	Exito	2026-09-05 18:52:00	5	Sin complicaciones
73	11	Intraoperatorio	Salida quirurgica: conteo de instrumental	Exito	2026-09-05 19:07:00	5	Sin complicaciones
74	11	Postoperatorio	Ingreso a sala de recuperacion	Falla	2026-09-05 19:49:00	5	Complicacion registrada durante la evolucion
75	11	Postoperatorio	Traslado seguro a Hospitalizacion	No aceptable	2026-09-05 19:59:00	5	Complicacion registrada durante la evolucion
76	12	Preoperatorio	Entrada: brazalete de identificacion y ficha clinica	Aceptable	2026-09-08 07:45:00	1	Sin complicaciones
77	12	Intraoperatorio	Chequeo en quirofano	Exito	2026-09-08 08:20:00	1	Sin complicaciones
78	12	Intraoperatorio	Procedimientos de pausa quirurgica	Aceptable	2026-09-08 08:36:00	1	Sin complicaciones
79	12	Intraoperatorio	Gestion de cuidados intraoperatoria: balance hidrico	Exito	2026-09-08 08:52:00	1	Sin complicaciones
80	12	Intraoperatorio	Salida quirurgica: conteo de instrumental	Aceptable	2026-09-08 09:08:00	1	Sin complicaciones
81	12	Postoperatorio	Ingreso a sala de recuperacion	Exito	2026-09-08 09:50:00	1	Sin complicaciones
82	12	Postoperatorio	Traslado seguro a Hospitalizacion	Exito	2026-09-08 10:00:00	1	Sin complicaciones
83	13	Preoperatorio	Entrada: brazalete de identificacion y ficha clinica	Aceptable	2026-09-10 17:15:00	8	Sin complicaciones
84	13	Intraoperatorio	Chequeo en quirofano	Aceptable	2026-09-10 17:43:00	8	Sin complicaciones
85	13	Intraoperatorio	Procedimientos de pausa quirurgica	Aceptable	2026-09-10 17:51:00	8	Sin complicaciones
86	13	Intraoperatorio	Gestion de cuidados intraoperatoria: balance hidrico	Aceptable	2026-09-10 18:00:00	8	Sin complicaciones
87	13	Intraoperatorio	Salida quirurgica: conteo de instrumental	Exito	2026-09-10 18:08:00	8	Sin complicaciones
88	13	Postoperatorio	Ingreso a sala de recuperacion	Exito	2026-09-10 18:35:00	8	Sin complicaciones
89	13	Postoperatorio	Traslado seguro a Hospitalizacion	Exito	2026-09-10 18:45:00	8	Sin complicaciones
90	14	Preoperatorio	Entrada: brazalete de identificacion y ficha clinica	Aceptable	2026-09-14 22:30:00	13	Sin complicaciones
91	14	Intraoperatorio	Chequeo en quirofano	Exito	2026-09-14 23:08:00	13	Sin complicaciones
92	14	Intraoperatorio	Procedimientos de pausa quirurgica	Aceptable	2026-09-14 23:27:00	13	Sin complicaciones
93	14	Intraoperatorio	Gestion de cuidados intraoperatoria: balance hidrico	Exito	2026-09-14 23:46:00	13	Sin complicaciones
94	14	Intraoperatorio	Salida quirurgica: conteo de instrumental	Exito	2026-09-15 00:05:00	13	Sin complicaciones
95	15	Preoperatorio	Entrada: brazalete de identificacion y ficha clinica	Aceptable	2026-09-16 07:30:00	1	Sin complicaciones
96	15	Intraoperatorio	Chequeo en quirofano	Exito	2026-09-16 08:23:00	1	Sin complicaciones
97	15	Intraoperatorio	Procedimientos de pausa quirurgica	Aceptable	2026-09-16 08:56:00	1	Sin complicaciones
98	15	Intraoperatorio	Gestion de cuidados intraoperatoria: balance hidrico	Falla	2026-09-16 09:29:00	1	Sin complicaciones
99	15	Intraoperatorio	Salida quirurgica: conteo de instrumental	Aceptable	2026-09-16 10:02:00	1	Sin complicaciones
100	15	Postoperatorio	Ingreso a sala de recuperacion	Exito	2026-09-16 11:19:00	1	Sin complicaciones
101	15	Postoperatorio	Traslado seguro a Hospitalizacion	Exito	2026-09-16 11:29:00	1	Sin complicaciones
102	16	Preoperatorio	Entrada: brazalete de identificacion y ficha clinica	Aceptable	2026-09-29 00:15:00	6	Sin complicaciones
103	16	Intraoperatorio	Chequeo en quirofano	Aceptable	2026-09-29 01:03:00	6	Sin complicaciones
104	16	Intraoperatorio	Procedimientos de pausa quirurgica	Aceptable	2026-09-29 01:31:00	6	Sin complicaciones
105	16	Intraoperatorio	Gestion de cuidados intraoperatoria: balance hidrico	Medianamente aceptable	2026-09-29 02:00:00	6	Sin complicaciones
106	16	Intraoperatorio	Salida quirurgica: conteo de instrumental	Aceptable	2026-09-29 02:28:00	6	Sin complicaciones
107	16	Postoperatorio	Ingreso a sala de recuperacion	Exito	2026-09-29 03:35:00	6	Sin complicaciones
108	16	Postoperatorio	Traslado seguro a Hospitalizacion	Exito	2026-09-29 03:45:00	6	Sin complicaciones
109	17	Preoperatorio	Entrada: brazalete de identificacion y ficha clinica	Aceptable	2026-09-28 10:30:00	15	Sin complicaciones
110	17	Intraoperatorio	Chequeo en quirofano	Aceptable	2026-09-28 11:09:00	15	Sin complicaciones
111	17	Intraoperatorio	Procedimientos de pausa quirurgica	Exito	2026-09-28 11:28:00	15	Sin complicaciones
112	17	Intraoperatorio	Gestion de cuidados intraoperatoria: balance hidrico	Aceptable	2026-09-28 11:48:00	15	Sin complicaciones
113	17	Intraoperatorio	Salida quirurgica: conteo de instrumental	Exito	2026-09-28 12:07:00	15	Sin complicaciones
114	17	Postoperatorio	Ingreso a sala de recuperacion	Exito	2026-09-28 12:56:00	15	Sin complicaciones
115	17	Postoperatorio	Traslado seguro a Hospitalizacion	Exito	2026-09-28 13:06:00	15	Sin complicaciones
116	18	Preoperatorio	Entrada: brazalete de identificacion y ficha clinica	Aceptable	2026-09-29 10:30:00	2	Sin complicaciones
117	18	Intraoperatorio	Chequeo en quirofano	Exito	2026-09-29 11:06:00	2	Sin complicaciones
118	18	Intraoperatorio	Procedimientos de pausa quirurgica	Exito	2026-09-29 11:22:00	2	Sin complicaciones
119	18	Intraoperatorio	Gestion de cuidados intraoperatoria: balance hidrico	No aceptable	2026-09-29 11:38:00	2	Sin complicaciones
120	18	Intraoperatorio	Salida quirurgica: conteo de instrumental	Aceptable	2026-09-29 11:54:00	2	Sin complicaciones
121	18	Postoperatorio	Ingreso a sala de recuperacion	Exito	2026-09-29 12:36:00	2	Sin complicaciones
122	18	Postoperatorio	Traslado seguro a Hospitalizacion	Exito	2026-09-29 12:46:00	2	Sin complicaciones
123	19	Preoperatorio	Entrada: brazalete de identificacion y ficha clinica	Aceptable	2026-10-12 07:15:00	1	Sin complicaciones
124	19	Intraoperatorio	Chequeo en quirofano	Aceptable	2026-10-12 07:51:00	1	Sin complicaciones
125	19	Intraoperatorio	Procedimientos de pausa quirurgica	Exito	2026-10-12 08:07:00	1	Sin complicaciones
126	19	Intraoperatorio	Gestion de cuidados intraoperatoria: balance hidrico	Exito	2026-10-12 08:23:00	1	Sin complicaciones
127	19	Intraoperatorio	Salida quirurgica: conteo de instrumental	Exito	2026-10-12 08:39:00	1	Sin complicaciones
128	19	Postoperatorio	Ingreso a sala de recuperacion	Exito	2026-10-12 09:21:00	1	Sin complicaciones
129	19	Postoperatorio	Traslado seguro a Hospitalizacion	Exito	2026-10-12 09:31:00	1	Sin complicaciones
\.


--
-- Data for Name: requerimiento_equipo; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.requerimiento_equipo (id_solicitud, id_equipo, cantidad) FROM stdin;
1	1	1
1	3	1
3	3	1
3	8	3
3	7	1
3	2	1
4	7	2
4	5	2
4	3	2
5	2	1
5	7	1
5	5	1
6	8	1
6	5	1
6	1	2
7	6	3
7	8	3
7	4	2
7	7	3
8	5	4
8	6	1
8	2	3
9	8	3
9	4	4
9	3	1
9	1	3
10	1	2
10	3	3
10	2	1
11	4	2
11	6	2
11	7	2
11	5	2
12	4	1
12	8	3
12	5	4
12	7	4
13	3	1
13	8	3
13	1	1
14	5	1
14	3	1
14	8	3
14	6	1
15	6	2
15	1	1
15	7	1
15	8	1
16	2	1
16	6	2
16	8	2
16	3	2
17	8	2
17	7	1
17	3	4
17	6	1
18	4	4
18	3	4
18	5	3
18	2	3
19	5	1
19	8	3
19	6	3
19	4	1
20	6	1
20	1	3
20	7	1
20	2	1
\.


--
-- Data for Name: requerimiento_instrumento; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.requerimiento_instrumento (id_solicitud, id_instrumento, cantidad) FROM stdin;
1	1	1
1	2	2
1	5	1
3	9	1
3	6	1
3	2	3
4	3	1
4	2	1
4	7	2
4	8	1
5	9	1
5	1	2
5	6	1
6	1	1
6	8	1
6	10	3
7	1	1
7	7	2
7	9	2
7	8	3
8	8	4
8	10	4
8	4	1
8	5	4
9	3	4
9	2	1
9	4	6
9	1	1
10	3	1
10	7	4
10	2	3
10	8	4
11	2	3
11	5	1
11	9	2
12	5	1
12	6	3
12	1	4
12	4	3
13	8	3
13	6	2
13	2	2
14	2	4
14	10	1
14	8	4
15	10	1
15	7	3
15	1	2
15	2	1
16	8	3
16	7	1
16	9	1
16	1	3
17	4	2
17	7	5
17	5	1
18	3	1
18	4	4
18	1	4
18	10	1
19	7	3
19	3	1
19	2	3
20	4	2
20	10	2
20	3	4
20	2	4
\.


--
-- Data for Name: requerimiento_insumo; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.requerimiento_insumo (id_solicitud, id_insumo, cantidad) FROM stdin;
1	1	10
1	2	2
1	3	1
3	3	10
3	8	5
3	2	5
4	3	1
4	9	2
4	6	7
4	10	8
5	9	3
5	5	1
5	3	3
5	1	6
6	2	10
6	10	9
6	1	7
7	9	9
7	2	5
7	7	4
8	5	13
8	4	10
8	6	8
8	2	1
9	6	4
9	5	10
9	7	12
9	8	8
10	1	6
10	4	1
10	5	3
10	8	4
11	8	2
11	10	2
11	6	5
12	7	12
12	3	14
12	6	10
13	1	5
13	6	11
13	3	1
14	6	8
14	4	7
14	1	7
14	2	3
15	2	4
15	9	1
15	7	5
15	5	6
16	9	9
16	2	6
16	3	4
17	3	11
17	9	8
17	7	9
18	2	1
18	5	14
18	6	5
19	6	8
19	8	2
19	1	7
20	3	5
20	2	7
20	5	8
\.


--
-- Data for Name: responsable_paciente; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.responsable_paciente (id_responsable, id_paciente, nombre, parentesco, dpi, telefono, id_municipio, area) FROM stdin;
1	8	Juana Ixcoy Batz	Madre	9012345678909	30112200	10	Rural
2	3	Domingo Us Sican	Padre	0123456789010	30456700	3	Rural
3	6	Elena Argueta Toc	Hermana	1122334455667	48870000	6	Rural
4	1	Fernando Xitumul Vail	Esposo	2233445566778	55123400	1	Urbana
5	9	Carmen Ana Giron Mendez	Madre	5000000000009	30000009	8	Rural
6	13	Jose Juan Alvarado De Leon	Padre	5000000000013	30000013	10	Rural
7	19	Sofia Marta Garcia Xitumul	Madre	5000000000019	30000019	8	Rural
8	24	Mario Raul Vail Tzul	Padre	5000000000024	30000024	3	Rural
\.


--
-- Data for Name: servicio_hospitalizacion; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.servicio_hospitalizacion (id_servicio, nombre) FROM stdin;
1	Hematologia
2	Medicina interna
3	Neumologia
4	Oncologia
5	Ortopedia
6	Pediatria
7	Unidad de cuidados intermedios
8	Unidad de cuidado critico de adultos
\.


--
-- Data for Name: solicitud_cirugia; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.solicitud_cirugia (id_solicitud, id_paciente, id_cirujano, caracter, tipo_procedimiento, fecha_hora_solicitud, estado, id_hospital, historia_clinica, tiempo_estimado, tipo_anestesia, motivo_rechazo, id_quirofano, fecha_hora_agendada) FROM stdin;
1	2	6	Urgente	Apendicectomia convencional	2026-09-20 15:10:00	Aprobada	1	Paciente masculino, 51 anios, dolor en fosa iliaca derecha de 12 horas de evolucion	01:30:00	General	\N	1	2026-09-20 16:00:00
2	7	7	Programado	Artroscopia de rodilla	2026-09-18 09:00:00	Rechazada	1	Paciente femenina, 46 anios, gonalgia cronica	02:00:00	Regional	Estudios preoperatorios incompletos: falta evaluacion cardiologica	\N	\N
3	26	29	Programado	Hernioplastia inguinal	2026-08-01 10:15:00	Aprobada	5	Paciente con indicacion quirurgica segun valoracion clinica	01:40:00	Regional	\N	9	2026-08-07 10:20:00
4	5	6	Urgente	Apendicectomia convencional	2026-08-10 11:25:00	Aprobada	1	Paciente con indicacion quirurgica segun valoracion clinica	01:30:00	General	\N	1	2026-08-10 12:20:00
5	16	17	Urgente	Apendicectomia convencional	2026-08-11 09:10:00	Aprobada	3	Paciente con indicacion quirurgica segun valoracion clinica	01:30:00	General	\N	5	2026-08-11 10:05:00
6	4	6	Urgente	Apendicectomia convencional	2026-08-12 00:40:00	Aprobada	1	Paciente con indicacion quirurgica segun valoracion clinica	01:30:00	General	\N	2	2026-08-12 01:35:00
7	7	8	Programado	Hernioplastia inguinal	2026-08-09 07:15:00	Aprobada	1	Paciente con indicacion quirurgica segun valoracion clinica	01:40:00	Regional	\N	1	2026-08-13 07:20:00
8	14	7	Programado	Artroscopia de rodilla	2026-08-09 11:00:00	Aprobada	1	Paciente con indicacion quirurgica segun valoracion clinica	01:50:00	Regional	\N	1	2026-08-13 11:05:00
9	2	13	Programado	Hernioplastia inguinal	2026-08-11 08:00:00	Aprobada	2	Paciente con indicacion quirurgica segun valoracion clinica	01:40:00	Regional	\N	3	2026-08-14 08:05:00
10	23	8	Urgente	Drenaje de absceso	2026-08-22 16:40:00	Aprobada	1	Paciente con indicacion quirurgica segun valoracion clinica	00:45:00	Local	\N	1	2026-08-22 17:35:00
11	23	32	Programado	Artroscopia de rodilla	2026-08-22 08:00:00	Aprobada	5	Paciente con indicacion quirurgica segun valoracion clinica	01:50:00	Regional	\N	9	2026-08-24 08:05:00
12	9	13	Urgente	Apendicectomia convencional	2026-09-05 16:55:00	Aprobada	2	Paciente con indicacion quirurgica segun valoracion clinica	01:30:00	General	\N	3	2026-09-05 17:50:00
13	4	6	Programado	Hernioplastia inguinal	2026-09-06 07:45:00	Aprobada	1	Paciente con indicacion quirurgica segun valoracion clinica	01:40:00	Regional	\N	2	2026-09-08 07:50:00
14	26	13	Urgente	Drenaje de absceso	2026-09-10 16:25:00	Aprobada	2	Paciente con indicacion quirurgica segun valoracion clinica	00:45:00	Local	\N	4	2026-09-10 17:20:00
15	17	26	Urgente	Colecistectomia laparoscopica	2026-09-14 21:40:00	Aprobada	4	Paciente con indicacion quirurgica segun valoracion clinica	02:00:00	General	\N	8	2026-09-14 22:35:00
16	11	8	Urgente	Laparotomia exploradora	2026-09-16 06:40:00	Aprobada	1	Paciente con indicacion quirurgica segun valoracion clinica	03:00:00	General	\N	1	2026-09-16 07:35:00
17	10	19	Urgente	Reduccion abierta de fractura de tibia	2026-09-28 23:25:00	Aprobada	3	Paciente con indicacion quirurgica segun valoracion clinica	02:30:00	Regional	\N	5	2026-09-29 00:20:00
18	13	29	Programado	Hernioplastia inguinal	2026-09-22 10:30:00	Aprobada	5	Paciente con indicacion quirurgica segun valoracion clinica	01:40:00	Regional	\N	9	2026-09-28 10:35:00
19	2	8	Programado	Hernioplastia inguinal	2026-09-26 10:30:00	Aprobada	1	Paciente con indicacion quirurgica segun valoracion clinica	01:40:00	Regional	\N	2	2026-09-29 10:35:00
20	6	6	Programado	Hernioplastia inguinal	2026-10-08 07:15:00	Aprobada	1	Paciente con indicacion quirurgica segun valoracion clinica	01:40:00	Regional	\N	2	2026-10-12 07:20:00
21	11	7	Programado	Reduccion abierta de fractura de tibia	2026-10-18 13:00:00	Rechazada	1	Valoracion clinica en curso	01:30:00	Regional	Estudios preoperatorios incompletos	\N	\N
22	10	13	Programado	Laparotomia exploradora	2026-08-15 16:00:00	Rechazada	2	Valoracion clinica en curso	01:30:00	General	Paciente con riesgo anestesico no controlado (ASA IV)	\N	\N
23	18	19	Programado	Artroscopia de rodilla	2026-09-10 11:00:00	Rechazada	3	Valoracion clinica en curso	01:30:00	Regional	Falta de insumos para el procedimiento	\N	\N
24	4	23	Programado	Apendicectomia convencional	2026-10-14 12:00:00	Pendiente	4	Valoracion clinica en curso	01:30:00	General	\N	\N	\N
25	23	32	Programado	Artroscopia de rodilla	2026-09-18 09:00:00	Pendiente	5	Valoracion clinica en curso	01:30:00	Regional	\N	\N	\N
26	14	6	Programado	Hernioplastia inguinal	2026-08-11 15:00:00	Pendiente	1	Valoracion clinica en curso	01:30:00	Regional	\N	\N	\N
\.


--
-- Data for Name: traslado; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.traslado (id_traslado, id_paciente, id_medico_indica, fecha_hora, id_unidad_destino, interno_destino, id_unidad_origen, interno_origen) FROM stdin;
1	2	1	2026-09-20 15:00:00	2	t	1	t
2	2	6	2026-09-20 19:00:00	3	t	2	t
3	26	29	2026-08-07 12:56:00	15	t	14	t
4	5	1	2026-08-10 12:00:00	2	t	1	t
5	5	6	2026-08-10 14:30:00	3	t	2	t
6	16	20	2026-08-11 09:45:00	8	t	7	t
7	16	17	2026-08-11 12:41:00	9	t	8	t
8	4	2	2026-08-12 01:15:00	2	t	1	t
9	4	6	2026-08-12 04:01:00	3	t	2	t
10	7	8	2026-08-13 10:02:00	3	t	2	t
11	2	13	2026-08-14 10:35:00	6	t	5	t
12	23	2	2026-08-22 17:15:00	2	t	1	t
13	23	8	2026-08-22 19:26:00	3	t	2	t
14	23	32	2026-08-24 10:34:00	15	t	14	t
15	9	14	2026-09-05 17:30:00	5	t	4	t
16	9	13	2026-09-05 20:09:00	6	t	5	t
17	4	6	2026-09-08 10:10:00	3	t	2	t
18	26	5	2026-09-10 17:00:00	5	t	4	t
19	26	13	2026-09-10 18:55:00	6	t	5	t
20	17	25	2026-09-14 22:15:00	11	t	10	t
21	11	1	2026-09-16 07:15:00	2	t	1	t
22	11	8	2026-09-16 11:39:00	3	t	2	t
23	10	18	2026-09-29 00:00:00	8	t	7	t
24	10	19	2026-09-29 03:55:00	9	t	8	t
25	13	29	2026-09-28 13:16:00	15	t	14	t
26	2	8	2026-09-29 12:56:00	3	t	2	t
27	6	6	2026-10-12 09:41:00	3	t	2	t
\.


--
-- Data for Name: turno_laboral; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.turno_laboral (id_turno_laboral, id_medico, id_unidad_hospital, fecha_hora_inicio, fecha_hora_fin) FROM stdin;
1	3	1	2026-08-01 06:00:00	2026-08-01 14:00:00
2	22	10	2026-08-01 06:00:00	2026-08-01 18:00:00
3	30	13	2026-08-01 06:00:00	2026-08-01 14:00:00
4	20	7	2026-08-02 14:00:00	2026-08-02 22:00:00
5	2	1	2026-08-03 06:00:00	2026-08-03 14:00:00
6	3	1	2026-08-03 06:00:00	2026-08-03 14:00:00
7	22	10	2026-08-03 06:00:00	2026-08-03 14:00:00
8	12	4	2026-08-03 14:00:00	2026-08-04 02:00:00
9	16	7	2026-08-04 22:00:00	2026-08-05 10:00:00
10	2	1	2026-08-05 06:00:00	2026-08-05 14:00:00
11	30	13	2026-08-05 14:00:00	2026-08-05 22:00:00
12	12	4	2026-08-05 22:00:00	2026-08-06 10:00:00
13	28	13	2026-08-05 22:00:00	2026-08-06 06:00:00
14	20	7	2026-08-06 06:00:00	2026-08-06 14:00:00
15	1	1	2026-08-06 22:00:00	2026-08-07 10:00:00
16	14	4	2026-08-06 22:00:00	2026-08-07 10:00:00
17	2	1	2026-08-07 06:00:00	2026-08-07 18:00:00
18	11	1	2026-08-07 06:00:00	2026-08-07 14:00:00
19	30	13	2026-08-07 22:00:00	2026-08-08 10:00:00
20	1	1	2026-08-08 22:00:00	2026-08-09 10:00:00
21	3	1	2026-08-09 06:00:00	2026-08-09 14:00:00
22	11	1	2026-08-09 06:00:00	2026-08-09 18:00:00
23	15	4	2026-08-09 06:00:00	2026-08-09 14:00:00
24	2	1	2026-08-09 22:00:00	2026-08-10 10:00:00
25	30	13	2026-08-09 22:00:00	2026-08-10 06:00:00
26	1	1	2026-08-10 06:00:00	2026-08-10 18:00:00
27	18	7	2026-08-10 14:00:00	2026-08-10 22:00:00
28	24	10	2026-08-10 14:00:00	2026-08-10 22:00:00
29	16	7	2026-08-10 22:00:00	2026-08-11 10:00:00
30	3	1	2026-08-11 14:00:00	2026-08-12 02:00:00
31	1	1	2026-08-12 14:00:00	2026-08-12 22:00:00
32	20	7	2026-08-12 14:00:00	2026-08-12 22:00:00
33	25	10	2026-08-12 14:00:00	2026-08-13 02:00:00
34	5	4	2026-08-12 22:00:00	2026-08-13 06:00:00
35	3	1	2026-08-13 06:00:00	2026-08-13 14:00:00
36	11	1	2026-08-13 22:00:00	2026-08-14 06:00:00
37	14	4	2026-08-14 06:00:00	2026-08-14 18:00:00
38	20	7	2026-08-14 06:00:00	2026-08-14 14:00:00
39	31	13	2026-08-14 14:00:00	2026-08-15 02:00:00
40	3	1	2026-08-15 06:00:00	2026-08-15 14:00:00
41	30	13	2026-08-15 06:00:00	2026-08-15 18:00:00
42	15	4	2026-08-15 22:00:00	2026-08-16 06:00:00
43	20	7	2026-08-16 14:00:00	2026-08-16 22:00:00
44	24	10	2026-08-16 14:00:00	2026-08-16 22:00:00
45	5	4	2026-08-16 22:00:00	2026-08-17 10:00:00
46	25	10	2026-08-16 22:00:00	2026-08-17 10:00:00
47	2	1	2026-08-17 06:00:00	2026-08-17 14:00:00
48	11	1	2026-08-17 22:00:00	2026-08-18 06:00:00
49	12	4	2026-08-17 22:00:00	2026-08-18 06:00:00
50	16	7	2026-08-18 06:00:00	2026-08-18 14:00:00
51	5	4	2026-08-18 14:00:00	2026-08-19 02:00:00
52	14	4	2026-08-18 14:00:00	2026-08-18 22:00:00
53	18	7	2026-08-18 22:00:00	2026-08-19 06:00:00
54	25	10	2026-08-18 22:00:00	2026-08-19 10:00:00
55	18	7	2026-08-20 14:00:00	2026-08-20 22:00:00
56	12	4	2026-08-21 22:00:00	2026-08-22 06:00:00
57	15	4	2026-08-21 22:00:00	2026-08-22 10:00:00
58	24	10	2026-08-22 06:00:00	2026-08-22 18:00:00
59	1	1	2026-08-22 14:00:00	2026-08-22 22:00:00
60	18	7	2026-08-22 14:00:00	2026-08-22 22:00:00
61	20	7	2026-08-22 14:00:00	2026-08-22 22:00:00
62	25	10	2026-08-22 22:00:00	2026-08-23 06:00:00
63	15	4	2026-08-23 06:00:00	2026-08-23 14:00:00
64	22	10	2026-08-23 06:00:00	2026-08-23 14:00:00
65	30	13	2026-08-23 06:00:00	2026-08-23 14:00:00
66	3	1	2026-08-23 14:00:00	2026-08-24 02:00:00
67	15	4	2026-08-25 06:00:00	2026-08-25 18:00:00
68	11	1	2026-08-25 14:00:00	2026-08-25 22:00:00
69	30	13	2026-08-25 22:00:00	2026-08-26 06:00:00
70	14	4	2026-08-26 14:00:00	2026-08-27 02:00:00
71	25	10	2026-08-26 14:00:00	2026-08-27 02:00:00
72	5	4	2026-08-26 22:00:00	2026-08-27 06:00:00
73	11	1	2026-08-27 06:00:00	2026-08-27 14:00:00
74	15	4	2026-08-27 06:00:00	2026-08-27 18:00:00
75	1	1	2026-08-28 14:00:00	2026-08-28 22:00:00
76	31	13	2026-08-28 14:00:00	2026-08-28 22:00:00
77	16	7	2026-08-28 22:00:00	2026-08-29 06:00:00
78	24	10	2026-08-28 22:00:00	2026-08-29 06:00:00
79	12	4	2026-08-29 14:00:00	2026-08-30 02:00:00
80	15	4	2026-08-29 22:00:00	2026-08-30 06:00:00
81	25	10	2026-08-30 06:00:00	2026-08-30 18:00:00
82	20	7	2026-08-30 14:00:00	2026-08-30 22:00:00
83	16	7	2026-08-30 22:00:00	2026-08-31 06:00:00
84	31	13	2026-08-30 22:00:00	2026-08-31 06:00:00
85	15	4	2026-08-31 06:00:00	2026-08-31 18:00:00
86	3	1	2026-08-31 14:00:00	2026-09-01 02:00:00
87	30	13	2026-09-02 06:00:00	2026-09-02 14:00:00
88	3	1	2026-09-02 22:00:00	2026-09-03 10:00:00
89	5	4	2026-09-03 14:00:00	2026-09-03 22:00:00
90	18	7	2026-09-03 22:00:00	2026-09-04 06:00:00
91	20	7	2026-09-03 22:00:00	2026-09-04 10:00:00
92	15	4	2026-09-04 06:00:00	2026-09-04 18:00:00
93	18	7	2026-09-05 06:00:00	2026-09-05 14:00:00
94	24	10	2026-09-05 06:00:00	2026-09-05 14:00:00
95	1	1	2026-09-05 14:00:00	2026-09-06 02:00:00
96	5	4	2026-09-05 22:00:00	2026-09-06 06:00:00
97	12	4	2026-09-06 06:00:00	2026-09-06 14:00:00
98	28	13	2026-09-06 06:00:00	2026-09-06 18:00:00
99	30	13	2026-09-06 22:00:00	2026-09-07 06:00:00
100	14	4	2026-09-07 06:00:00	2026-09-07 18:00:00
101	1	1	2026-09-07 14:00:00	2026-09-07 22:00:00
102	18	7	2026-09-07 14:00:00	2026-09-07 22:00:00
103	25	10	2026-09-07 14:00:00	2026-09-08 02:00:00
104	20	7	2026-09-07 22:00:00	2026-09-08 06:00:00
105	3	1	2026-09-08 06:00:00	2026-09-08 18:00:00
106	30	13	2026-09-08 06:00:00	2026-09-08 14:00:00
107	20	7	2026-09-09 06:00:00	2026-09-09 14:00:00
108	18	7	2026-09-09 22:00:00	2026-09-10 06:00:00
109	2	1	2026-09-10 06:00:00	2026-09-10 14:00:00
110	18	7	2026-09-11 06:00:00	2026-09-11 18:00:00
111	31	13	2026-09-11 14:00:00	2026-09-11 22:00:00
112	5	4	2026-09-11 22:00:00	2026-09-12 10:00:00
113	30	13	2026-09-12 06:00:00	2026-09-12 14:00:00
114	28	13	2026-09-12 22:00:00	2026-09-13 10:00:00
115	1	1	2026-09-13 22:00:00	2026-09-14 06:00:00
116	3	1	2026-09-14 06:00:00	2026-09-14 14:00:00
117	1	1	2026-09-15 14:00:00	2026-09-16 02:00:00
118	24	10	2026-09-15 14:00:00	2026-09-16 02:00:00
119	14	4	2026-09-15 22:00:00	2026-09-16 06:00:00
120	15	4	2026-09-16 14:00:00	2026-09-16 22:00:00
121	12	4	2026-09-16 22:00:00	2026-09-17 10:00:00
122	28	13	2026-09-16 22:00:00	2026-09-17 06:00:00
123	25	10	2026-09-17 14:00:00	2026-09-17 22:00:00
124	1	1	2026-09-17 22:00:00	2026-09-18 06:00:00
125	16	7	2026-09-17 22:00:00	2026-09-18 06:00:00
126	1	1	2026-09-19 22:00:00	2026-09-20 10:00:00
127	24	10	2026-09-19 22:00:00	2026-09-20 06:00:00
128	31	13	2026-09-19 22:00:00	2026-09-20 06:00:00
129	3	1	2026-09-20 06:00:00	2026-09-20 14:00:00
130	12	4	2026-09-20 06:00:00	2026-09-20 18:00:00
131	20	7	2026-09-21 06:00:00	2026-09-21 14:00:00
132	16	7	2026-09-21 14:00:00	2026-09-21 22:00:00
133	18	7	2026-09-21 14:00:00	2026-09-21 22:00:00
134	14	4	2026-09-21 22:00:00	2026-09-22 06:00:00
135	11	1	2026-09-22 14:00:00	2026-09-22 22:00:00
136	28	13	2026-09-22 14:00:00	2026-09-22 22:00:00
137	22	10	2026-09-22 22:00:00	2026-09-23 06:00:00
138	30	13	2026-09-22 22:00:00	2026-09-23 06:00:00
139	25	10	2026-09-23 14:00:00	2026-09-23 22:00:00
140	31	13	2026-09-23 22:00:00	2026-09-24 06:00:00
141	28	13	2026-09-24 06:00:00	2026-09-24 18:00:00
142	18	7	2026-09-25 14:00:00	2026-09-26 02:00:00
143	1	1	2026-09-25 22:00:00	2026-09-26 10:00:00
144	14	4	2026-09-25 22:00:00	2026-09-26 06:00:00
145	24	10	2026-09-25 22:00:00	2026-09-26 06:00:00
146	20	7	2026-09-27 06:00:00	2026-09-27 14:00:00
147	24	10	2026-09-27 06:00:00	2026-09-27 14:00:00
148	25	10	2026-09-27 06:00:00	2026-09-27 14:00:00
149	18	7	2026-09-27 14:00:00	2026-09-28 02:00:00
150	31	13	2026-09-27 14:00:00	2026-09-27 22:00:00
151	5	4	2026-09-27 22:00:00	2026-09-28 06:00:00
152	12	4	2026-09-28 22:00:00	2026-09-29 06:00:00
153	5	4	2026-09-29 06:00:00	2026-09-29 18:00:00
154	14	4	2026-09-29 06:00:00	2026-09-29 18:00:00
155	20	7	2026-09-29 06:00:00	2026-09-29 14:00:00
156	24	10	2026-09-29 06:00:00	2026-09-29 18:00:00
157	1	1	2026-09-29 14:00:00	2026-09-29 22:00:00
158	25	10	2026-09-29 14:00:00	2026-09-29 22:00:00
159	3	1	2026-09-30 06:00:00	2026-09-30 14:00:00
160	15	4	2026-09-30 06:00:00	2026-09-30 14:00:00
161	14	4	2026-10-01 06:00:00	2026-10-01 14:00:00
162	2	1	2026-10-02 06:00:00	2026-10-02 18:00:00
163	11	1	2026-10-02 14:00:00	2026-10-03 02:00:00
164	22	10	2026-10-02 14:00:00	2026-10-02 22:00:00
165	3	1	2026-10-02 22:00:00	2026-10-03 06:00:00
166	15	4	2026-10-02 22:00:00	2026-10-03 10:00:00
167	31	13	2026-10-03 14:00:00	2026-10-03 22:00:00
168	22	10	2026-10-04 06:00:00	2026-10-04 14:00:00
169	11	1	2026-10-04 14:00:00	2026-10-05 02:00:00
170	25	10	2026-10-05 06:00:00	2026-10-05 18:00:00
171	14	4	2026-10-05 14:00:00	2026-10-05 22:00:00
172	16	7	2026-10-05 22:00:00	2026-10-06 06:00:00
173	24	10	2026-10-05 22:00:00	2026-10-06 06:00:00
174	12	4	2026-10-06 14:00:00	2026-10-06 22:00:00
175	22	10	2026-10-06 22:00:00	2026-10-07 10:00:00
176	25	10	2026-10-07 06:00:00	2026-10-07 14:00:00
177	14	4	2026-10-07 14:00:00	2026-10-08 02:00:00
178	16	7	2026-10-07 14:00:00	2026-10-08 02:00:00
179	18	7	2026-10-07 14:00:00	2026-10-08 02:00:00
180	18	7	2026-10-09 06:00:00	2026-10-09 18:00:00
181	24	10	2026-10-09 06:00:00	2026-10-09 18:00:00
182	31	13	2026-10-09 22:00:00	2026-10-10 06:00:00
183	22	10	2026-10-10 06:00:00	2026-10-10 14:00:00
184	3	1	2026-10-10 14:00:00	2026-10-10 22:00:00
185	15	4	2026-10-10 14:00:00	2026-10-10 22:00:00
186	25	10	2026-10-11 06:00:00	2026-10-11 14:00:00
187	31	13	2026-10-11 06:00:00	2026-10-11 14:00:00
188	5	4	2026-10-11 22:00:00	2026-10-12 06:00:00
189	18	7	2026-10-11 22:00:00	2026-10-12 06:00:00
190	15	4	2026-10-12 06:00:00	2026-10-12 14:00:00
191	28	13	2026-10-12 06:00:00	2026-10-12 18:00:00
192	2	1	2026-10-12 14:00:00	2026-10-12 22:00:00
193	11	1	2026-10-12 14:00:00	2026-10-12 22:00:00
194	22	10	2026-10-12 22:00:00	2026-10-13 10:00:00
195	31	13	2026-10-13 06:00:00	2026-10-13 14:00:00
196	16	7	2026-10-13 22:00:00	2026-10-14 10:00:00
197	20	7	2026-10-13 22:00:00	2026-10-14 06:00:00
198	1	1	2026-10-15 06:00:00	2026-10-15 14:00:00
199	5	4	2026-10-15 06:00:00	2026-10-15 14:00:00
200	14	4	2026-10-15 06:00:00	2026-10-15 14:00:00
201	20	7	2026-10-15 14:00:00	2026-10-15 22:00:00
202	25	10	2026-10-15 22:00:00	2026-10-16 10:00:00
203	11	1	2026-10-16 06:00:00	2026-10-16 14:00:00
204	15	4	2026-10-16 14:00:00	2026-10-16 22:00:00
205	22	10	2026-10-16 22:00:00	2026-10-17 06:00:00
206	20	7	2026-10-17 06:00:00	2026-10-17 14:00:00
207	24	10	2026-10-17 06:00:00	2026-10-17 18:00:00
208	25	10	2026-10-17 06:00:00	2026-10-17 14:00:00
209	16	7	2026-10-17 14:00:00	2026-10-17 22:00:00
210	28	13	2026-10-18 14:00:00	2026-10-18 22:00:00
211	30	13	2026-10-18 22:00:00	2026-10-19 10:00:00
212	5	4	2026-10-19 14:00:00	2026-10-20 02:00:00
213	20	7	2026-10-19 22:00:00	2026-10-20 06:00:00
214	28	13	2026-10-20 14:00:00	2026-10-20 22:00:00
215	2	1	2026-10-20 22:00:00	2026-10-21 06:00:00
216	15	4	2026-10-20 22:00:00	2026-10-21 06:00:00
217	1	1	2026-10-21 06:00:00	2026-10-21 14:00:00
218	14	4	2026-10-21 22:00:00	2026-10-22 06:00:00
219	18	7	2026-10-21 22:00:00	2026-10-22 06:00:00
220	11	1	2026-10-22 06:00:00	2026-10-22 14:00:00
221	22	10	2026-10-22 06:00:00	2026-10-22 18:00:00
222	28	13	2026-10-22 06:00:00	2026-10-22 14:00:00
223	2	1	2026-10-22 22:00:00	2026-10-23 06:00:00
224	30	13	2026-10-22 22:00:00	2026-10-23 06:00:00
225	14	4	2026-10-23 06:00:00	2026-10-23 14:00:00
226	1	1	2026-10-23 14:00:00	2026-10-23 22:00:00
227	31	13	2026-10-23 14:00:00	2026-10-23 22:00:00
228	28	13	2026-10-24 06:00:00	2026-10-24 14:00:00
229	30	13	2026-10-24 06:00:00	2026-10-24 14:00:00
230	3	1	2026-10-24 14:00:00	2026-10-24 22:00:00
\.


--
-- Data for Name: unidad_hospital; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.unidad_hospital (id_unidad_hospital, id_hospital, tipo_unidad) FROM stdin;
1	1	Emergencias
2	1	Cirugia
3	1	Hospitalizacion
4	2	Emergencias
5	2	Cirugia
6	2	Hospitalizacion
7	3	Emergencias
8	3	Cirugia
9	3	Hospitalizacion
10	4	Emergencias
11	4	Cirugia
12	4	Hospitalizacion
13	5	Emergencias
14	5	Cirugia
15	5	Hospitalizacion
\.


--
-- Name: cirujano_id_cirujano_seq; Type: SEQUENCE SET; Schema: propuesta_cirugia; Owner: -
--

SELECT pg_catalog.setval('propuesta_cirugia.cirujano_id_cirujano_seq', 3, true);


--
-- Name: especialidad_id_especialidad_seq; Type: SEQUENCE SET; Schema: propuesta_cirugia; Owner: -
--

SELECT pg_catalog.setval('propuesta_cirugia.especialidad_id_especialidad_seq', 2, true);


--
-- Name: insumo_id_insumo_seq; Type: SEQUENCE SET; Schema: propuesta_cirugia; Owner: -
--

SELECT pg_catalog.setval('propuesta_cirugia.insumo_id_insumo_seq', 4, true);


--
-- Name: paciente_id_paciente_seq; Type: SEQUENCE SET; Schema: propuesta_cirugia; Owner: -
--

SELECT pg_catalog.setval('propuesta_cirugia.paciente_id_paciente_seq', 6, true);


--
-- Name: auditoria_medico_id_auditoria_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.auditoria_medico_id_auditoria_seq', 10, true);


--
-- Name: calificacion_enfermero_id_calificacion_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.calificacion_enfermero_id_calificacion_seq', 23, true);


--
-- Name: calificacion_hospital_id_calificacion_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.calificacion_hospital_id_calificacion_seq', 26, true);


--
-- Name: calificacion_medico_id_calificacion_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.calificacion_medico_id_calificacion_seq', 172, true);


--
-- Name: calificacion_personal_encargado_id_calificacion_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.calificacion_personal_encargado_id_calificacion_seq', 23, true);


--
-- Name: camilla_id_camilla_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.camilla_id_camilla_seq', 6, true);


--
-- Name: chequeo_preanestesico_id_chequeo_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.chequeo_preanestesico_id_chequeo_seq', 19, true);


--
-- Name: cirugia_id_cirugia_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.cirugia_id_cirugia_seq', 19, true);


--
-- Name: cita_programada_id_cita_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.cita_programada_id_cita_seq', 44, true);


--
-- Name: consentimiento_informado_id_consentimiento_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.consentimiento_informado_id_consentimiento_seq', 19, true);


--
-- Name: consulta_paciente_id_consulta_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.consulta_paciente_id_consulta_seq', 34, true);


--
-- Name: cuota_id_cuota_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.cuota_id_cuota_seq', 150, true);


--
-- Name: departamento_id_departamento_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.departamento_id_departamento_seq', 5, true);


--
-- Name: diagnostico_secundario_id_diagnostico_secundario_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.diagnostico_secundario_id_diagnostico_secundario_seq', 7, true);


--
-- Name: egreso_id_egreso_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.egreso_id_egreso_seq', 135, true);


--
-- Name: enfermero_id_enfermero_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.enfermero_id_enfermero_seq', 23, true);


--
-- Name: equipo_id_equipo_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.equipo_id_equipo_seq', 8, true);


--
-- Name: especialidad_id_especialidad_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.especialidad_id_especialidad_seq', 28, true);


--
-- Name: factura_id_factura_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.factura_id_factura_seq', 74, true);


--
-- Name: hospital_id_hospital_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.hospital_id_hospital_seq', 3, true);


--
-- Name: hospitalizacion_detalle_id_hospitalizacion_detalle_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.hospitalizacion_detalle_id_hospitalizacion_detalle_seq', 30, true);


--
-- Name: ingreso_id_ingreso_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.ingreso_id_ingreso_seq', 140, true);


--
-- Name: instrumento_id_instrumento_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.instrumento_id_instrumento_seq', 10, true);


--
-- Name: insumo_id_insumo_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.insumo_id_insumo_seq', 10, true);


--
-- Name: medicamento_recetado_id_medicamento_recetado_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.medicamento_recetado_id_medicamento_recetado_seq', 58, true);


--
-- Name: medico_id_medico_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.medico_id_medico_seq', 34, true);


--
-- Name: municipio_id_municipio_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.municipio_id_municipio_seq', 10, true);


--
-- Name: paciente_id_paciente_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.paciente_id_paciente_seq', 30, true);


--
-- Name: personal_encargado_id_encargado_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.personal_encargado_id_encargado_seq', 15, true);


--
-- Name: personal_id_personal_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.personal_id_personal_seq', 76, true);


--
-- Name: quirofano_id_quirofano_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.quirofano_id_quirofano_seq', 3, true);


--
-- Name: receta_medica_id_receta_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.receta_medica_id_receta_seq', 26, true);


--
-- Name: registro_procedimiento_cirugia_id_registro_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.registro_procedimiento_cirugia_id_registro_seq', 129, true);


--
-- Name: responsable_paciente_id_responsable_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.responsable_paciente_id_responsable_seq', 8, true);


--
-- Name: servicio_hospitalizacion_id_servicio_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.servicio_hospitalizacion_id_servicio_seq', 8, true);


--
-- Name: solicitud_cirugia_id_solicitud_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.solicitud_cirugia_id_solicitud_seq', 26, true);


--
-- Name: traslado_id_traslado_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.traslado_id_traslado_seq', 27, true);


--
-- Name: turno_laboral_id_turno_laboral_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.turno_laboral_id_turno_laboral_seq', 242, true);


--
-- Name: unidad_hospital_id_unidad_hospital_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.unidad_hospital_id_unidad_hospital_seq', 9, true);


--
-- Name: cirugia_insumo cirugia_insumo_pkey; Type: CONSTRAINT; Schema: propuesta_cirugia; Owner: -
--

ALTER TABLE ONLY propuesta_cirugia.cirugia_insumo
    ADD CONSTRAINT cirugia_insumo_pkey PRIMARY KEY (id_cirugia, id_insumo);


--
-- Name: cirugia cirugia_pkey; Type: CONSTRAINT; Schema: propuesta_cirugia; Owner: -
--

ALTER TABLE ONLY propuesta_cirugia.cirugia
    ADD CONSTRAINT cirugia_pkey PRIMARY KEY (id_cirugia);


--
-- Name: cirujano cirujano_nombre_key; Type: CONSTRAINT; Schema: propuesta_cirugia; Owner: -
--

ALTER TABLE ONLY propuesta_cirugia.cirujano
    ADD CONSTRAINT cirujano_nombre_key UNIQUE (nombre);


--
-- Name: cirujano cirujano_pkey; Type: CONSTRAINT; Schema: propuesta_cirugia; Owner: -
--

ALTER TABLE ONLY propuesta_cirugia.cirujano
    ADD CONSTRAINT cirujano_pkey PRIMARY KEY (id_cirujano);


--
-- Name: diagnostico diagnostico_pkey; Type: CONSTRAINT; Schema: propuesta_cirugia; Owner: -
--

ALTER TABLE ONLY propuesta_cirugia.diagnostico
    ADD CONSTRAINT diagnostico_pkey PRIMARY KEY (codigo);


--
-- Name: especialidad especialidad_nombre_key; Type: CONSTRAINT; Schema: propuesta_cirugia; Owner: -
--

ALTER TABLE ONLY propuesta_cirugia.especialidad
    ADD CONSTRAINT especialidad_nombre_key UNIQUE (nombre);


--
-- Name: especialidad especialidad_pkey; Type: CONSTRAINT; Schema: propuesta_cirugia; Owner: -
--

ALTER TABLE ONLY propuesta_cirugia.especialidad
    ADD CONSTRAINT especialidad_pkey PRIMARY KEY (id_especialidad);


--
-- Name: insumo insumo_nombre_key; Type: CONSTRAINT; Schema: propuesta_cirugia; Owner: -
--

ALTER TABLE ONLY propuesta_cirugia.insumo
    ADD CONSTRAINT insumo_nombre_key UNIQUE (nombre);


--
-- Name: insumo insumo_pkey; Type: CONSTRAINT; Schema: propuesta_cirugia; Owner: -
--

ALTER TABLE ONLY propuesta_cirugia.insumo
    ADD CONSTRAINT insumo_pkey PRIMARY KEY (id_insumo);


--
-- Name: paciente paciente_nombre_key; Type: CONSTRAINT; Schema: propuesta_cirugia; Owner: -
--

ALTER TABLE ONLY propuesta_cirugia.paciente
    ADD CONSTRAINT paciente_nombre_key UNIQUE (nombre);


--
-- Name: paciente paciente_pkey; Type: CONSTRAINT; Schema: propuesta_cirugia; Owner: -
--

ALTER TABLE ONLY propuesta_cirugia.paciente
    ADD CONSTRAINT paciente_pkey PRIMARY KEY (id_paciente);


--
-- Name: reporte_cirugia_original reporte_cirugia_original_pkey; Type: CONSTRAINT; Schema: propuesta_cirugia; Owner: -
--

ALTER TABLE ONLY propuesta_cirugia.reporte_cirugia_original
    ADD CONSTRAINT reporte_cirugia_original_pkey PRIMARY KEY (id_cirugia);


--
-- Name: auditoria_medico auditoria_medico_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.auditoria_medico
    ADD CONSTRAINT auditoria_medico_pkey PRIMARY KEY (id_auditoria);


--
-- Name: calificacion_enfermero calificacion_enfermero_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.calificacion_enfermero
    ADD CONSTRAINT calificacion_enfermero_pkey PRIMARY KEY (id_calificacion);


--
-- Name: calificacion_hospital calificacion_hospital_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.calificacion_hospital
    ADD CONSTRAINT calificacion_hospital_pkey PRIMARY KEY (id_calificacion);


--
-- Name: calificacion_medico calificacion_medico_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.calificacion_medico
    ADD CONSTRAINT calificacion_medico_pkey PRIMARY KEY (id_calificacion);


--
-- Name: calificacion_personal_encargado calificacion_personal_encargado_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.calificacion_personal_encargado
    ADD CONSTRAINT calificacion_personal_encargado_pkey PRIMARY KEY (id_calificacion);


--
-- Name: camilla camilla_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.camilla
    ADD CONSTRAINT camilla_pkey PRIMARY KEY (id_camilla);


--
-- Name: chequeo_preanestesico chequeo_preanestesico_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chequeo_preanestesico
    ADD CONSTRAINT chequeo_preanestesico_pkey PRIMARY KEY (id_chequeo);


--
-- Name: cirugia cirugia_id_solicitud_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cirugia
    ADD CONSTRAINT cirugia_id_solicitud_key UNIQUE (id_solicitud);


--
-- Name: cirugia cirugia_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cirugia
    ADD CONSTRAINT cirugia_pkey PRIMARY KEY (id_cirugia);


--
-- Name: cita_programada cita_programada_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cita_programada
    ADD CONSTRAINT cita_programada_pkey PRIMARY KEY (id_cita);


--
-- Name: consentimiento_informado consentimiento_informado_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.consentimiento_informado
    ADD CONSTRAINT consentimiento_informado_pkey PRIMARY KEY (id_consentimiento);


--
-- Name: consulta_paciente consulta_paciente_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.consulta_paciente
    ADD CONSTRAINT consulta_paciente_pkey PRIMARY KEY (id_consulta);


--
-- Name: cuota cuota_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cuota
    ADD CONSTRAINT cuota_pkey PRIMARY KEY (id_cuota);


--
-- Name: departamento departamento_nombre_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.departamento
    ADD CONSTRAINT departamento_nombre_key UNIQUE (nombre);


--
-- Name: departamento departamento_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.departamento
    ADD CONSTRAINT departamento_pkey PRIMARY KEY (id_departamento);


--
-- Name: diagnostico_secundario diagnostico_secundario_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.diagnostico_secundario
    ADD CONSTRAINT diagnostico_secundario_pkey PRIMARY KEY (id_diagnostico_secundario);


--
-- Name: egreso egreso_id_ingreso_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.egreso
    ADD CONSTRAINT egreso_id_ingreso_key UNIQUE (id_ingreso);


--
-- Name: egreso egreso_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.egreso
    ADD CONSTRAINT egreso_pkey PRIMARY KEY (id_egreso);


--
-- Name: enfermero enfermero_dpi_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.enfermero
    ADD CONSTRAINT enfermero_dpi_key UNIQUE (dpi);


--
-- Name: enfermero enfermero_numero_colegiado_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.enfermero
    ADD CONSTRAINT enfermero_numero_colegiado_key UNIQUE (numero_colegiado);


--
-- Name: enfermero enfermero_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.enfermero
    ADD CONSTRAINT enfermero_pkey PRIMARY KEY (id_enfermero);


--
-- Name: equipo equipo_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.equipo
    ADD CONSTRAINT equipo_pkey PRIMARY KEY (id_equipo);


--
-- Name: especialidad especialidad_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.especialidad
    ADD CONSTRAINT especialidad_pkey PRIMARY KEY (id_especialidad);


--
-- Name: factura factura_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.factura
    ADD CONSTRAINT factura_pkey PRIMARY KEY (id_factura);


--
-- Name: hospital hospital_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.hospital
    ADD CONSTRAINT hospital_pkey PRIMARY KEY (id_hospital);


--
-- Name: hospitalizacion_detalle hospitalizacion_detalle_id_ingreso_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.hospitalizacion_detalle
    ADD CONSTRAINT hospitalizacion_detalle_id_ingreso_key UNIQUE (id_ingreso);


--
-- Name: hospitalizacion_detalle hospitalizacion_detalle_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.hospitalizacion_detalle
    ADD CONSTRAINT hospitalizacion_detalle_pkey PRIMARY KEY (id_hospitalizacion_detalle);


--
-- Name: ingreso ingreso_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ingreso
    ADD CONSTRAINT ingreso_pkey PRIMARY KEY (id_ingreso);


--
-- Name: instrumento instrumento_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.instrumento
    ADD CONSTRAINT instrumento_pkey PRIMARY KEY (id_instrumento);


--
-- Name: insumo insumo_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.insumo
    ADD CONSTRAINT insumo_pkey PRIMARY KEY (id_insumo);


--
-- Name: insumo_utilizado_cirugia insumo_utilizado_cirugia_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.insumo_utilizado_cirugia
    ADD CONSTRAINT insumo_utilizado_cirugia_pkey PRIMARY KEY (id_cirugia, id_insumo);


--
-- Name: medicamento_recetado medicamento_recetado_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.medicamento_recetado
    ADD CONSTRAINT medicamento_recetado_pkey PRIMARY KEY (id_medicamento_recetado);


--
-- Name: medico medico_dpi_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.medico
    ADD CONSTRAINT medico_dpi_key UNIQUE (dpi);


--
-- Name: medico medico_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.medico
    ADD CONSTRAINT medico_pkey PRIMARY KEY (id_medico);


--
-- Name: municipio municipio_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.municipio
    ADD CONSTRAINT municipio_pkey PRIMARY KEY (id_municipio);


--
-- Name: paciente paciente_no_expediente_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.paciente
    ADD CONSTRAINT paciente_no_expediente_key UNIQUE (no_expediente);


--
-- Name: paciente paciente_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.paciente
    ADD CONSTRAINT paciente_pkey PRIMARY KEY (id_paciente);


--
-- Name: personal personal_dpi_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.personal
    ADD CONSTRAINT personal_dpi_key UNIQUE (dpi);


--
-- Name: personal_encargado personal_encargado_dpi_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.personal_encargado
    ADD CONSTRAINT personal_encargado_dpi_key UNIQUE (dpi);


--
-- Name: personal_encargado personal_encargado_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.personal_encargado
    ADD CONSTRAINT personal_encargado_pkey PRIMARY KEY (id_encargado);


--
-- Name: personal personal_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.personal
    ADD CONSTRAINT personal_pkey PRIMARY KEY (id_personal);


--
-- Name: quirofano quirofano_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quirofano
    ADD CONSTRAINT quirofano_pkey PRIMARY KEY (id_quirofano);


--
-- Name: receta_medica receta_medica_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.receta_medica
    ADD CONSTRAINT receta_medica_pkey PRIMARY KEY (id_receta);


--
-- Name: registro_procedimiento_cirugia registro_procedimiento_cirugia_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.registro_procedimiento_cirugia
    ADD CONSTRAINT registro_procedimiento_cirugia_pkey PRIMARY KEY (id_registro);


--
-- Name: requerimiento_equipo requerimiento_equipo_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.requerimiento_equipo
    ADD CONSTRAINT requerimiento_equipo_pkey PRIMARY KEY (id_solicitud, id_equipo);


--
-- Name: requerimiento_instrumento requerimiento_instrumento_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.requerimiento_instrumento
    ADD CONSTRAINT requerimiento_instrumento_pkey PRIMARY KEY (id_solicitud, id_instrumento);


--
-- Name: requerimiento_insumo requerimiento_insumo_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.requerimiento_insumo
    ADD CONSTRAINT requerimiento_insumo_pkey PRIMARY KEY (id_solicitud, id_insumo);


--
-- Name: responsable_paciente responsable_paciente_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.responsable_paciente
    ADD CONSTRAINT responsable_paciente_pkey PRIMARY KEY (id_responsable);


--
-- Name: servicio_hospitalizacion servicio_hospitalizacion_nombre_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.servicio_hospitalizacion
    ADD CONSTRAINT servicio_hospitalizacion_nombre_key UNIQUE (nombre);


--
-- Name: servicio_hospitalizacion servicio_hospitalizacion_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.servicio_hospitalizacion
    ADD CONSTRAINT servicio_hospitalizacion_pkey PRIMARY KEY (id_servicio);


--
-- Name: solicitud_cirugia solicitud_cirugia_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.solicitud_cirugia
    ADD CONSTRAINT solicitud_cirugia_pkey PRIMARY KEY (id_solicitud);


--
-- Name: traslado traslado_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.traslado
    ADD CONSTRAINT traslado_pkey PRIMARY KEY (id_traslado);


--
-- Name: turno_laboral turno_laboral_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.turno_laboral
    ADD CONSTRAINT turno_laboral_pkey PRIMARY KEY (id_turno_laboral);


--
-- Name: unidad_hospital unidad_hospital_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.unidad_hospital
    ADD CONSTRAINT unidad_hospital_pkey PRIMARY KEY (id_unidad_hospital);


--
-- Name: camilla uq_camilla_unidad_numero; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.camilla
    ADD CONSTRAINT uq_camilla_unidad_numero UNIQUE (id_unidad_hospital, numero);


--
-- Name: cuota uq_cuota_factura_numero; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cuota
    ADD CONSTRAINT uq_cuota_factura_numero UNIQUE (id_factura, numero_cuota);


--
-- Name: personal_encargado uq_encargado_id_personal; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.personal_encargado
    ADD CONSTRAINT uq_encargado_id_personal UNIQUE (id_personal);


--
-- Name: enfermero uq_enfermero_id_personal; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.enfermero
    ADD CONSTRAINT uq_enfermero_id_personal UNIQUE (id_personal);


--
-- Name: medico uq_medico_hospital_medico; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.medico
    ADD CONSTRAINT uq_medico_hospital_medico UNIQUE (id_hospital, id_medico);


--
-- Name: medico uq_medico_id_personal; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.medico
    ADD CONSTRAINT uq_medico_id_personal UNIQUE (id_personal);


--
-- Name: municipio uq_municipio_nombre_departamento; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.municipio
    ADD CONSTRAINT uq_municipio_nombre_departamento UNIQUE (id_departamento, nombre);


--
-- Name: personal uq_personal_id_tipo; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.personal
    ADD CONSTRAINT uq_personal_id_tipo UNIQUE (id_personal, tipo_personal);


--
-- Name: quirofano uq_quirofano_hospital_numero; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quirofano
    ADD CONSTRAINT uq_quirofano_hospital_numero UNIQUE (id_hospital, numero);


--
-- Name: turno_laboral uq_turno_medico_inicio; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.turno_laboral
    ADD CONSTRAINT uq_turno_medico_inicio UNIQUE (id_medico, fecha_hora_inicio);


--
-- Name: unidad_hospital uq_unidadhosp_hospital_tipo; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.unidad_hospital
    ADD CONSTRAINT uq_unidadhosp_hospital_tipo UNIQUE (id_hospital, tipo_unidad);


--
-- Name: idx_auditoria_medico_historial; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_auditoria_medico_historial ON public.auditoria_medico USING btree (id_medico, fecha_hora DESC);


--
-- Name: idx_medico_supervisor; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_medico_supervisor ON public.medico USING btree (id_supervisor);


--
-- Name: idx_turno_unidad; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_turno_unidad ON public.turno_laboral USING btree (id_unidad_hospital);


--
-- Name: uq_medico_un_director_por_hospital; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_medico_un_director_por_hospital ON public.medico USING btree (id_hospital) WHERE ((cargo)::text = 'Director Medico'::text);


--
-- Name: auditoria_medico trg_auditoria_sin_truncate; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_auditoria_sin_truncate BEFORE TRUNCATE ON public.auditoria_medico FOR EACH STATEMENT EXECUTE FUNCTION public.fn_auditoria_solo_insercion();


--
-- Name: auditoria_medico trg_auditoria_solo_insercion; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_auditoria_solo_insercion BEFORE DELETE OR UPDATE ON public.auditoria_medico FOR EACH ROW EXECUTE FUNCTION public.fn_auditoria_solo_insercion();


--
-- Name: personal_encargado trg_encargado_heredar_personal; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_encargado_heredar_personal BEFORE INSERT ON public.personal_encargado FOR EACH ROW EXECUTE FUNCTION public.fn_subtipo_heredar_personal();


--
-- Name: enfermero trg_enfermero_heredar_personal; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_enfermero_heredar_personal BEFORE INSERT ON public.enfermero FOR EACH ROW EXECUTE FUNCTION public.fn_subtipo_heredar_personal();


--
-- Name: medico trg_medico_auditoria; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_medico_auditoria AFTER UPDATE OF salario, id_especialidad, nivel_acceso ON public.medico FOR EACH ROW WHEN (((old.salario IS DISTINCT FROM new.salario) OR (old.id_especialidad IS DISTINCT FROM new.id_especialidad) OR ((old.nivel_acceso)::text IS DISTINCT FROM (new.nivel_acceso)::text))) EXECUTE FUNCTION public.fn_medico_auditar_cambios();


--
-- Name: medico trg_medico_evitar_ciclo; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_medico_evitar_ciclo BEFORE INSERT OR UPDATE OF id_supervisor ON public.medico FOR EACH ROW EXECUTE FUNCTION public.fn_medico_evitar_ciclo();


--
-- Name: medico trg_medico_heredar_personal; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_medico_heredar_personal BEFORE INSERT ON public.medico FOR EACH ROW EXECUTE FUNCTION public.fn_subtipo_heredar_personal();


--
-- Name: personal trg_personal_propagar_datos; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_personal_propagar_datos AFTER UPDATE OF nombre, dpi, telefono ON public.personal FOR EACH ROW WHEN ((((old.nombre)::text IS DISTINCT FROM (new.nombre)::text) OR ((old.dpi)::text IS DISTINCT FROM (new.dpi)::text) OR ((old.telefono)::text IS DISTINCT FROM (new.telefono)::text))) EXECUTE FUNCTION public.fn_personal_propagar_datos();


--
-- Name: turno_laboral trg_turno_validar; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_turno_validar BEFORE INSERT OR UPDATE ON public.turno_laboral FOR EACH ROW EXECUTE FUNCTION public.fn_turno_validar();


--
-- Name: cirugia fk_prop_cirugia_cirujano; Type: FK CONSTRAINT; Schema: propuesta_cirugia; Owner: -
--

ALTER TABLE ONLY propuesta_cirugia.cirugia
    ADD CONSTRAINT fk_prop_cirugia_cirujano FOREIGN KEY (id_cirujano) REFERENCES propuesta_cirugia.cirujano(id_cirujano) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: cirugia fk_prop_cirugia_diagnostico; Type: FK CONSTRAINT; Schema: propuesta_cirugia; Owner: -
--

ALTER TABLE ONLY propuesta_cirugia.cirugia
    ADD CONSTRAINT fk_prop_cirugia_diagnostico FOREIGN KEY (codigo_diagnostico) REFERENCES propuesta_cirugia.diagnostico(codigo) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: cirugia fk_prop_cirugia_paciente; Type: FK CONSTRAINT; Schema: propuesta_cirugia; Owner: -
--

ALTER TABLE ONLY propuesta_cirugia.cirugia
    ADD CONSTRAINT fk_prop_cirugia_paciente FOREIGN KEY (id_paciente) REFERENCES propuesta_cirugia.paciente(id_paciente) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: cirugia_insumo fk_prop_cirugiainsumo_cirugia; Type: FK CONSTRAINT; Schema: propuesta_cirugia; Owner: -
--

ALTER TABLE ONLY propuesta_cirugia.cirugia_insumo
    ADD CONSTRAINT fk_prop_cirugiainsumo_cirugia FOREIGN KEY (id_cirugia) REFERENCES propuesta_cirugia.cirugia(id_cirugia) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: cirugia_insumo fk_prop_cirugiainsumo_insumo; Type: FK CONSTRAINT; Schema: propuesta_cirugia; Owner: -
--

ALTER TABLE ONLY propuesta_cirugia.cirugia_insumo
    ADD CONSTRAINT fk_prop_cirugiainsumo_insumo FOREIGN KEY (id_insumo) REFERENCES propuesta_cirugia.insumo(id_insumo) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: cirujano fk_prop_cirujano_especialidad; Type: FK CONSTRAINT; Schema: propuesta_cirugia; Owner: -
--

ALTER TABLE ONLY propuesta_cirugia.cirujano
    ADD CONSTRAINT fk_prop_cirujano_especialidad FOREIGN KEY (id_especialidad) REFERENCES propuesta_cirugia.especialidad(id_especialidad) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: auditoria_medico fk_auditoria_medico; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.auditoria_medico
    ADD CONSTRAINT fk_auditoria_medico FOREIGN KEY (id_medico) REFERENCES public.medico(id_medico) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: calificacion_personal_encargado fk_califenc_encargado; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.calificacion_personal_encargado
    ADD CONSTRAINT fk_califenc_encargado FOREIGN KEY (id_encargado) REFERENCES public.personal_encargado(id_encargado) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: calificacion_personal_encargado fk_califenc_paciente; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.calificacion_personal_encargado
    ADD CONSTRAINT fk_califenc_paciente FOREIGN KEY (id_paciente) REFERENCES public.paciente(id_paciente) ON UPDATE CASCADE ON DELETE SET NULL;


--
-- Name: calificacion_enfermero fk_califenf_enfermero; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.calificacion_enfermero
    ADD CONSTRAINT fk_califenf_enfermero FOREIGN KEY (id_enfermero) REFERENCES public.enfermero(id_enfermero) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: calificacion_enfermero fk_califenf_paciente; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.calificacion_enfermero
    ADD CONSTRAINT fk_califenf_paciente FOREIGN KEY (id_paciente) REFERENCES public.paciente(id_paciente) ON UPDATE CASCADE ON DELETE SET NULL;


--
-- Name: calificacion_hospital fk_califhosp_hospital; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.calificacion_hospital
    ADD CONSTRAINT fk_califhosp_hospital FOREIGN KEY (id_hospital) REFERENCES public.hospital(id_hospital) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: calificacion_hospital fk_califhosp_paciente; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.calificacion_hospital
    ADD CONSTRAINT fk_califhosp_paciente FOREIGN KEY (id_paciente) REFERENCES public.paciente(id_paciente) ON UPDATE CASCADE ON DELETE SET NULL;


--
-- Name: calificacion_medico fk_califmed_medico; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.calificacion_medico
    ADD CONSTRAINT fk_califmed_medico FOREIGN KEY (id_medico) REFERENCES public.medico(id_medico) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: calificacion_medico fk_califmed_paciente; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.calificacion_medico
    ADD CONSTRAINT fk_califmed_paciente FOREIGN KEY (id_paciente) REFERENCES public.paciente(id_paciente) ON UPDATE CASCADE ON DELETE SET NULL;


--
-- Name: camilla fk_camilla_unidad; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.camilla
    ADD CONSTRAINT fk_camilla_unidad FOREIGN KEY (id_unidad_hospital) REFERENCES public.unidad_hospital(id_unidad_hospital) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: chequeo_preanestesico fk_chequeo_anestesista; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chequeo_preanestesico
    ADD CONSTRAINT fk_chequeo_anestesista FOREIGN KEY (id_anestesista) REFERENCES public.medico(id_medico) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: chequeo_preanestesico fk_chequeo_medico_clasifica; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chequeo_preanestesico
    ADD CONSTRAINT fk_chequeo_medico_clasifica FOREIGN KEY (id_medico_clasifica) REFERENCES public.medico(id_medico) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: chequeo_preanestesico fk_chequeo_solicitud; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chequeo_preanestesico
    ADD CONSTRAINT fk_chequeo_solicitud FOREIGN KEY (id_solicitud) REFERENCES public.solicitud_cirugia(id_solicitud) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: cirugia fk_cirugia_enfermero; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cirugia
    ADD CONSTRAINT fk_cirugia_enfermero FOREIGN KEY (id_enfermero_encargado) REFERENCES public.enfermero(id_enfermero) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: cirugia fk_cirugia_ingreso; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cirugia
    ADD CONSTRAINT fk_cirugia_ingreso FOREIGN KEY (id_ingreso) REFERENCES public.ingreso(id_ingreso) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: cirugia fk_cirugia_quirofano; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cirugia
    ADD CONSTRAINT fk_cirugia_quirofano FOREIGN KEY (id_quirofano) REFERENCES public.quirofano(id_quirofano) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: cirugia fk_cirugia_solicitud; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cirugia
    ADD CONSTRAINT fk_cirugia_solicitud FOREIGN KEY (id_solicitud) REFERENCES public.solicitud_cirugia(id_solicitud) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: cita_programada fk_cita_medico; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cita_programada
    ADD CONSTRAINT fk_cita_medico FOREIGN KEY (id_medico) REFERENCES public.medico(id_medico) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: cita_programada fk_cita_paciente; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cita_programada
    ADD CONSTRAINT fk_cita_paciente FOREIGN KEY (id_paciente) REFERENCES public.paciente(id_paciente) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: consentimiento_informado fk_consentimiento_medico; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.consentimiento_informado
    ADD CONSTRAINT fk_consentimiento_medico FOREIGN KEY (id_medico) REFERENCES public.medico(id_medico) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: consentimiento_informado fk_consentimiento_solicitud; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.consentimiento_informado
    ADD CONSTRAINT fk_consentimiento_solicitud FOREIGN KEY (id_solicitud) REFERENCES public.solicitud_cirugia(id_solicitud) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: consulta_paciente fk_consulta_cita; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.consulta_paciente
    ADD CONSTRAINT fk_consulta_cita FOREIGN KEY (id_cita) REFERENCES public.cita_programada(id_cita) ON UPDATE CASCADE ON DELETE SET NULL;


--
-- Name: consulta_paciente fk_consulta_medico; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.consulta_paciente
    ADD CONSTRAINT fk_consulta_medico FOREIGN KEY (id_medico) REFERENCES public.medico(id_medico) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: consulta_paciente fk_consulta_paciente; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.consulta_paciente
    ADD CONSTRAINT fk_consulta_paciente FOREIGN KEY (id_paciente) REFERENCES public.paciente(id_paciente) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: cuota fk_cuota_factura; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cuota
    ADD CONSTRAINT fk_cuota_factura FOREIGN KEY (id_factura) REFERENCES public.factura(id_factura) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: diagnostico_secundario fk_diagsec_egreso; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.diagnostico_secundario
    ADD CONSTRAINT fk_diagsec_egreso FOREIGN KEY (id_egreso) REFERENCES public.egreso(id_egreso) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: egreso fk_egreso_ingreso; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.egreso
    ADD CONSTRAINT fk_egreso_ingreso FOREIGN KEY (id_ingreso) REFERENCES public.ingreso(id_ingreso) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: egreso fk_egreso_medico; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.egreso
    ADD CONSTRAINT fk_egreso_medico FOREIGN KEY (id_medico) REFERENCES public.medico(id_medico) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: egreso fk_egreso_traslado; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.egreso
    ADD CONSTRAINT fk_egreso_traslado FOREIGN KEY (id_traslado) REFERENCES public.traslado(id_traslado) ON UPDATE CASCADE ON DELETE SET NULL;


--
-- Name: personal_encargado fk_encargado_hospital; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.personal_encargado
    ADD CONSTRAINT fk_encargado_hospital FOREIGN KEY (id_hospital) REFERENCES public.hospital(id_hospital) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: personal_encargado fk_encargado_personal; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.personal_encargado
    ADD CONSTRAINT fk_encargado_personal FOREIGN KEY (id_personal, tipo_personal) REFERENCES public.personal(id_personal, tipo_personal) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: enfermero fk_enfermero_hospital; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.enfermero
    ADD CONSTRAINT fk_enfermero_hospital FOREIGN KEY (id_hospital) REFERENCES public.hospital(id_hospital) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: enfermero fk_enfermero_personal; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.enfermero
    ADD CONSTRAINT fk_enfermero_personal FOREIGN KEY (id_personal, tipo_personal) REFERENCES public.personal(id_personal, tipo_personal) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: factura fk_factura_consulta; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.factura
    ADD CONSTRAINT fk_factura_consulta FOREIGN KEY (id_consulta) REFERENCES public.consulta_paciente(id_consulta) ON UPDATE CASCADE ON DELETE SET NULL;


--
-- Name: factura fk_factura_hospital; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.factura
    ADD CONSTRAINT fk_factura_hospital FOREIGN KEY (id_hospital) REFERENCES public.hospital(id_hospital) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: factura fk_factura_ingreso; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.factura
    ADD CONSTRAINT fk_factura_ingreso FOREIGN KEY (id_ingreso) REFERENCES public.ingreso(id_ingreso) ON UPDATE CASCADE ON DELETE SET NULL;


--
-- Name: factura fk_factura_paciente; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.factura
    ADD CONSTRAINT fk_factura_paciente FOREIGN KEY (id_paciente) REFERENCES public.paciente(id_paciente) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: hospitalizacion_detalle fk_hospdet_camilla; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.hospitalizacion_detalle
    ADD CONSTRAINT fk_hospdet_camilla FOREIGN KEY (id_camilla) REFERENCES public.camilla(id_camilla) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: hospitalizacion_detalle fk_hospdet_ingreso; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.hospitalizacion_detalle
    ADD CONSTRAINT fk_hospdet_ingreso FOREIGN KEY (id_ingreso) REFERENCES public.ingreso(id_ingreso) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: hospitalizacion_detalle fk_hospdet_servicio; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.hospitalizacion_detalle
    ADD CONSTRAINT fk_hospdet_servicio FOREIGN KEY (id_servicio) REFERENCES public.servicio_hospitalizacion(id_servicio) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: hospital fk_hospital_municipio; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.hospital
    ADD CONSTRAINT fk_hospital_municipio FOREIGN KEY (id_municipio) REFERENCES public.municipio(id_municipio) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: ingreso fk_ingreso_camilla; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ingreso
    ADD CONSTRAINT fk_ingreso_camilla FOREIGN KEY (id_camilla) REFERENCES public.camilla(id_camilla) ON UPDATE CASCADE ON DELETE SET NULL;


--
-- Name: ingreso fk_ingreso_medico; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ingreso
    ADD CONSTRAINT fk_ingreso_medico FOREIGN KEY (id_medico) REFERENCES public.medico(id_medico) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: ingreso fk_ingreso_paciente; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ingreso
    ADD CONSTRAINT fk_ingreso_paciente FOREIGN KEY (id_paciente) REFERENCES public.paciente(id_paciente) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: ingreso fk_ingreso_responsable; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ingreso
    ADD CONSTRAINT fk_ingreso_responsable FOREIGN KEY (id_responsable) REFERENCES public.responsable_paciente(id_responsable) ON UPDATE CASCADE ON DELETE SET NULL;


--
-- Name: ingreso fk_ingreso_unidad; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ingreso
    ADD CONSTRAINT fk_ingreso_unidad FOREIGN KEY (id_unidad_hospital) REFERENCES public.unidad_hospital(id_unidad_hospital) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: insumo_utilizado_cirugia fk_insumoused_cirugia; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.insumo_utilizado_cirugia
    ADD CONSTRAINT fk_insumoused_cirugia FOREIGN KEY (id_cirugia) REFERENCES public.cirugia(id_cirugia) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: insumo_utilizado_cirugia fk_insumoused_insumo; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.insumo_utilizado_cirugia
    ADD CONSTRAINT fk_insumoused_insumo FOREIGN KEY (id_insumo) REFERENCES public.insumo(id_insumo) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: medicamento_recetado fk_medicamento_receta; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.medicamento_recetado
    ADD CONSTRAINT fk_medicamento_receta FOREIGN KEY (id_receta) REFERENCES public.receta_medica(id_receta) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: medico fk_medico_especialidad; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.medico
    ADD CONSTRAINT fk_medico_especialidad FOREIGN KEY (id_especialidad) REFERENCES public.especialidad(id_especialidad) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: medico fk_medico_hospital; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.medico
    ADD CONSTRAINT fk_medico_hospital FOREIGN KEY (id_hospital) REFERENCES public.hospital(id_hospital) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: medico fk_medico_municipio; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.medico
    ADD CONSTRAINT fk_medico_municipio FOREIGN KEY (id_municipio) REFERENCES public.municipio(id_municipio) ON UPDATE CASCADE ON DELETE SET NULL;


--
-- Name: medico fk_medico_personal; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.medico
    ADD CONSTRAINT fk_medico_personal FOREIGN KEY (id_personal, tipo_personal) REFERENCES public.personal(id_personal, tipo_personal) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: medico fk_medico_supervisor; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.medico
    ADD CONSTRAINT fk_medico_supervisor FOREIGN KEY (id_hospital, id_supervisor) REFERENCES public.medico(id_hospital, id_medico) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: municipio fk_municipio_departamento; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.municipio
    ADD CONSTRAINT fk_municipio_departamento FOREIGN KEY (id_departamento) REFERENCES public.departamento(id_departamento) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: paciente fk_paciente_municipio; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.paciente
    ADD CONSTRAINT fk_paciente_municipio FOREIGN KEY (id_municipio) REFERENCES public.municipio(id_municipio) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: quirofano fk_quirofano_hospital; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quirofano
    ADD CONSTRAINT fk_quirofano_hospital FOREIGN KEY (id_hospital) REFERENCES public.hospital(id_hospital) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: receta_medica fk_receta_consulta; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.receta_medica
    ADD CONSTRAINT fk_receta_consulta FOREIGN KEY (id_consulta) REFERENCES public.consulta_paciente(id_consulta) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: receta_medica fk_receta_hospital; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.receta_medica
    ADD CONSTRAINT fk_receta_hospital FOREIGN KEY (id_hospital) REFERENCES public.hospital(id_hospital) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: registro_procedimiento_cirugia fk_registro_cirugia; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.registro_procedimiento_cirugia
    ADD CONSTRAINT fk_registro_cirugia FOREIGN KEY (id_cirugia) REFERENCES public.cirugia(id_cirugia) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: registro_procedimiento_cirugia fk_registro_enfermero; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.registro_procedimiento_cirugia
    ADD CONSTRAINT fk_registro_enfermero FOREIGN KEY (id_enfermero) REFERENCES public.enfermero(id_enfermero) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: requerimiento_equipo fk_reqequipo_equipo; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.requerimiento_equipo
    ADD CONSTRAINT fk_reqequipo_equipo FOREIGN KEY (id_equipo) REFERENCES public.equipo(id_equipo) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: requerimiento_equipo fk_reqequipo_solicitud; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.requerimiento_equipo
    ADD CONSTRAINT fk_reqequipo_solicitud FOREIGN KEY (id_solicitud) REFERENCES public.solicitud_cirugia(id_solicitud) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: requerimiento_instrumento fk_reqinstr_instrumento; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.requerimiento_instrumento
    ADD CONSTRAINT fk_reqinstr_instrumento FOREIGN KEY (id_instrumento) REFERENCES public.instrumento(id_instrumento) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: requerimiento_instrumento fk_reqinstr_solicitud; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.requerimiento_instrumento
    ADD CONSTRAINT fk_reqinstr_solicitud FOREIGN KEY (id_solicitud) REFERENCES public.solicitud_cirugia(id_solicitud) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: requerimiento_insumo fk_reqinsumo_insumo; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.requerimiento_insumo
    ADD CONSTRAINT fk_reqinsumo_insumo FOREIGN KEY (id_insumo) REFERENCES public.insumo(id_insumo) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: requerimiento_insumo fk_reqinsumo_solicitud; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.requerimiento_insumo
    ADD CONSTRAINT fk_reqinsumo_solicitud FOREIGN KEY (id_solicitud) REFERENCES public.solicitud_cirugia(id_solicitud) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: responsable_paciente fk_responsable_municipio; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.responsable_paciente
    ADD CONSTRAINT fk_responsable_municipio FOREIGN KEY (id_municipio) REFERENCES public.municipio(id_municipio) ON UPDATE CASCADE ON DELETE SET NULL;


--
-- Name: responsable_paciente fk_responsable_paciente; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.responsable_paciente
    ADD CONSTRAINT fk_responsable_paciente FOREIGN KEY (id_paciente) REFERENCES public.paciente(id_paciente) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: solicitud_cirugia fk_solicitud_cirujano; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.solicitud_cirugia
    ADD CONSTRAINT fk_solicitud_cirujano FOREIGN KEY (id_cirujano) REFERENCES public.medico(id_medico) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: solicitud_cirugia fk_solicitud_hospital; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.solicitud_cirugia
    ADD CONSTRAINT fk_solicitud_hospital FOREIGN KEY (id_hospital) REFERENCES public.hospital(id_hospital) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: solicitud_cirugia fk_solicitud_paciente; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.solicitud_cirugia
    ADD CONSTRAINT fk_solicitud_paciente FOREIGN KEY (id_paciente) REFERENCES public.paciente(id_paciente) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: solicitud_cirugia fk_solicitud_quirofano; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.solicitud_cirugia
    ADD CONSTRAINT fk_solicitud_quirofano FOREIGN KEY (id_quirofano) REFERENCES public.quirofano(id_quirofano) ON UPDATE CASCADE ON DELETE SET NULL;


--
-- Name: traslado fk_traslado_medico; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.traslado
    ADD CONSTRAINT fk_traslado_medico FOREIGN KEY (id_medico_indica) REFERENCES public.medico(id_medico) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: traslado fk_traslado_paciente; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.traslado
    ADD CONSTRAINT fk_traslado_paciente FOREIGN KEY (id_paciente) REFERENCES public.paciente(id_paciente) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: traslado fk_traslado_unidad_destino; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.traslado
    ADD CONSTRAINT fk_traslado_unidad_destino FOREIGN KEY (id_unidad_destino) REFERENCES public.unidad_hospital(id_unidad_hospital) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: traslado fk_traslado_unidad_origen; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.traslado
    ADD CONSTRAINT fk_traslado_unidad_origen FOREIGN KEY (id_unidad_origen) REFERENCES public.unidad_hospital(id_unidad_hospital) ON UPDATE CASCADE ON DELETE SET NULL;


--
-- Name: turno_laboral fk_turno_medico; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.turno_laboral
    ADD CONSTRAINT fk_turno_medico FOREIGN KEY (id_medico) REFERENCES public.medico(id_medico) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: turno_laboral fk_turno_unidad; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.turno_laboral
    ADD CONSTRAINT fk_turno_unidad FOREIGN KEY (id_unidad_hospital) REFERENCES public.unidad_hospital(id_unidad_hospital) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: unidad_hospital fk_unidadhosp_hospital; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.unidad_hospital
    ADD CONSTRAINT fk_unidadhosp_hospital FOREIGN KEY (id_hospital) REFERENCES public.hospital(id_hospital) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- PostgreSQL database dump complete
--

\unrestrict mFQzdX24KoRwudewieI70bAthbneonRuDFVHb8v8eiW0o0m50ieEsvzLvGkezq4

