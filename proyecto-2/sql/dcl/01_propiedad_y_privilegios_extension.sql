-- DCL P2-01: propiedad y privilegios para ejecutar la extension del Proyecto 2 con rol_administrador
-- Ejecutar como superusuario, despues del DCL del Proyecto 1 (sql/dcl/01_roles_privilegios.sql).

-- 1. rol_administrador pasa a ser dueño de todas las tablas (las secuencias identity las acompanan)
DO $$
DECLARE
    t RECORD;
BEGIN
    FOR t IN SELECT tablename FROM pg_tables WHERE schemaname = 'public' AND tableowner <> 'rol_administrador' LOOP
        EXECUTE format('ALTER TABLE public.%I OWNER TO rol_administrador', t.tablename);
    END LOOP;
END
$$;

-- 2. Los objetos que cree rol_administrador (tablas nuevas de la extension) son legibles por rol_lectura
ALTER DEFAULT PRIVILEGES FOR ROLE rol_administrador IN SCHEMA public GRANT SELECT ON TABLES TO rol_lectura;

-- 3. Ambos roles pueden conectarse a la base que se esta configurando (el DCL del Proyecto 1 apunta a hospital_bd)
SELECT format('GRANT CONNECT ON DATABASE %I TO rol_lectura, rol_administrador', current_database()) \gexec

-- 4. Comprobacion: ninguna tabla debe quedar a nombre de otro rol
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tableowner <> 'rol_administrador') THEN
        RAISE EXCEPTION 'Quedan tablas que no pertenecen a rol_administrador';
    END IF;
END
$$;
