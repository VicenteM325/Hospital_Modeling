-- DCL P2-02: permite a rol_administrador crear esquemas en la base (la propuesta de normalizacion del
-- objetivo 19 vive en el esquema propuesta_cirugia para no chocar con las tablas insumo y especialidad del modelo).
-- Ejecutar como superusuario, antes de sql/ddl/03_propuesta_normalizacion_cirugia.sql.
SELECT format('GRANT CREATE ON DATABASE %I TO rol_administrador', current_database()) \gexec
