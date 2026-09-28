
-- Politica:
--   rol_lectura        -> SOLO LECTURA (SELECT) sobre todo el esquema.
--                         Uso previsto: auditoria y consulta de reportes.
--   rol_administrador  -> Privilegios administrativos completos sobre el
--                         esquema (DDL/DML/DCL de aqui en adelante).
-- Orden de ejecucion: primero el DDL (sql/ddl), luego este
-- archivo, y despues el DML (sql/dml) o cualquier insercion futura, ya que
-- los privilegios por defecto (ALTER DEFAULT PRIVILEGES) tambien cubren
-- tablas que se creen mas adelante.

\set NOMBRE_BD hospital_bd

-- Endurecimiento: nadie tiene privilegios en el esquema por el simple hecho
-- de conectarse; todo acceso debe venir de un rol explicito.
REVOKE ALL ON SCHEMA public FROM PUBLIC;

-- -------------------------------------------------------------------------
-- 1. Roles de grupo (sin LOGIN): agrupan privilegios, no se usan para
--    conectarse directamente. Los usuarios reales se agregan como miembros.
CREATE ROLE rol_lectura NOLOGIN;
COMMENT ON ROLE rol_lectura IS 'Rol de grupo de solo lectura, para auditoria y consulta de reportes';

CREATE ROLE rol_administrador NOLOGIN;
COMMENT ON ROLE rol_administrador IS 'Rol de grupo con privilegios administrativos completos sobre el esquema';

-- -------------------------------------------------------------------------
-- 2. Privilegios de rol_lectura: solo SELECT, sobre tablas actuales y futuras
GRANT CONNECT ON DATABASE :NOMBRE_BD TO rol_lectura;
GRANT USAGE ON SCHEMA public TO rol_lectura;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO rol_lectura;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO rol_lectura;

-- -------------------------------------------------------------------------
-- 3. Privilegios de rol_administrador: control total, sobre objetos
--    actuales y futuros (tablas y secuencias)
GRANT CONNECT ON DATABASE :NOMBRE_BD TO rol_administrador;
GRANT USAGE, CREATE ON SCHEMA public TO rol_administrador;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO rol_administrador;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO rol_administrador;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL PRIVILEGES ON TABLES TO rol_administrador;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL PRIVILEGES ON SEQUENCES TO rol_administrador;

-- -------------------------------------------------------------------------
-- 4. Usuarios concretos (LOGIN) que heredan los privilegios de cada rol de
--    grupo. Contraseñas de prueba;
CREATE ROLE usr_auditoria LOGIN PASSWORD 'Auditoria_2026*' IN ROLE rol_lectura;
COMMENT ON ROLE usr_auditoria IS 'Usuario de solo lectura para auditoria/reportes de calidad de los hospitales';

CREATE ROLE usr_admin_bd LOGIN PASSWORD 'AdminBD_2026*' IN ROLE rol_administrador;
COMMENT ON ROLE usr_admin_bd IS 'Usuario con privilegios administrativos completos sobre el esquema hospitalario';
