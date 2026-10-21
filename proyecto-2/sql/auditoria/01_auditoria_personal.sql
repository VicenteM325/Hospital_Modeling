-- AUDITORIA P2-01: trazabilidad automatica de cambios sensibles del personal medico (Bloque F, objetivo 20)
-- Cada vez que cambia el salario, la especialidad o el nivel de acceso de un medico, un trigger de la propia
-- base guarda quien lo hizo, que campo cambio, el valor anterior, el nuevo y el momento exacto. No depende de
-- la aplicacion ni de que el usuario se acuerde de registrarlo.
-- Ejecutar como usr_admin_bd, despues de las migraciones DDL y de cargar los datos (asi los datos iniciales no generan filas de auditoria).

SET ROLE rol_administrador;
BEGIN;

CREATE TABLE auditoria_medico (
    id_auditoria    BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_medico       INTEGER NOT NULL
        CONSTRAINT fk_auditoria_medico REFERENCES medico(id_medico)
        ON DELETE RESTRICT ON UPDATE RESTRICT,
    campo           VARCHAR(20) NOT NULL
        CONSTRAINT chk_auditoria_campo CHECK (campo IN ('salario', 'id_especialidad', 'nivel_acceso')), -- valida que solo se audite uno de los campos sensibles
    valor_anterior  TEXT,
    valor_nuevo     TEXT,
    usuario_bd      VARCHAR(63) NOT NULL DEFAULT session_user,
    fecha_hora      TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp(),
    CONSTRAINT chk_auditoria_cambio_real CHECK (valor_anterior IS DISTINCT FROM valor_nuevo) -- valida que la fila describa un cambio real
);
COMMENT ON TABLE auditoria_medico IS 'Historial de solo insercion de los cambios de salario, especialidad y nivel de acceso de los medicos';
COMMENT ON COLUMN auditoria_medico.usuario_bd IS 'Usuario con el que se inicio la sesion que hizo el cambio (session_user)';
CREATE INDEX idx_auditoria_medico_historial ON auditoria_medico (id_medico, fecha_hora DESC);

-- Registra una fila por cada campo sensible que cambio en la sentencia UPDATE.
-- SECURITY DEFINER: el registro se escribe aunque quien actualiza no tenga permiso de INSERT sobre la bitacora.
CREATE FUNCTION fn_medico_auditar_cambios() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
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
COMMENT ON FUNCTION fn_medico_auditar_cambios() IS 'Escribe en auditoria_medico cada cambio de salario, especialidad o nivel de acceso';

CREATE TRIGGER trg_medico_auditoria
    AFTER UPDATE OF salario, id_especialidad, nivel_acceso ON medico
    FOR EACH ROW
    WHEN (OLD.salario IS DISTINCT FROM NEW.salario
          OR OLD.id_especialidad IS DISTINCT FROM NEW.id_especialidad
          OR OLD.nivel_acceso IS DISTINCT FROM NEW.nivel_acceso)
    EXECUTE FUNCTION fn_medico_auditar_cambios();

-- La bitacora no se puede alterar: se quitan los permisos de modificar y, ademas, un trigger bloquea
-- UPDATE, DELETE y TRUNCATE incluso a quien conserve el permiso (por ejemplo, un superusuario)
REVOKE UPDATE, DELETE, TRUNCATE ON auditoria_medico FROM rol_administrador;

CREATE FUNCTION fn_auditoria_solo_insercion() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    RAISE EXCEPTION 'auditoria_medico es de solo insercion: no se permite %', TG_OP;
END
$$;
COMMENT ON FUNCTION fn_auditoria_solo_insercion() IS 'Impide modificar o borrar la bitacora de auditoria';

CREATE TRIGGER trg_auditoria_solo_insercion BEFORE UPDATE OR DELETE ON auditoria_medico
    FOR EACH ROW EXECUTE FUNCTION fn_auditoria_solo_insercion();
CREATE TRIGGER trg_auditoria_sin_truncate BEFORE TRUNCATE ON auditoria_medico
    FOR EACH STATEMENT EXECUTE FUNCTION fn_auditoria_solo_insercion();

COMMIT;
