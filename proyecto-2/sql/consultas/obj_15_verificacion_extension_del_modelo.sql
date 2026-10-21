-- OBJETIVO 15 (Bloque B): extension del modelo sin modificar de forma destructiva las tablas existentes.
-- El entregable es el DDL (sql/ddl/01_extension_personal.sql y 02_extension_complementaria.sql) y el diagrama
-- (modelo/). Estas consultas leen la base y comprueban que la extension quedo como se disenio.

-- (a) Supertipo y subtipos: cada persona de PERSONAL pertenece a exactamente un subtipo
SELECT p.tipo_personal,
       COUNT(*) AS personal,
       COUNT(*) FILTER (WHERE (m.id_medico IS NOT NULL)::int + (e.id_enfermero IS NOT NULL)::int + (c.id_encargado IS NOT NULL)::int = 1) AS con_un_solo_subtipo
FROM personal p
LEFT JOIN medico m ON m.id_personal = p.id_personal
LEFT JOIN enfermero e ON e.id_personal = p.id_personal
LEFT JOIN personal_encargado c ON c.id_personal = p.id_personal
GROUP BY p.tipo_personal
ORDER BY p.tipo_personal;

-- (b) Relacion recursiva: cadena de mando de cada hospital (un director y los niveles que le siguen)
WITH RECURSIVE nivel AS (
    SELECT id_medico, id_hospital, 1 AS profundidad FROM medico WHERE id_supervisor IS NULL
    UNION ALL
    SELECT m.id_medico, m.id_hospital, n.profundidad + 1 FROM medico m JOIN nivel n ON m.id_supervisor = n.id_medico
)
SELECT h.nombre AS hospital,
       COUNT(*) FILTER (WHERE m.cargo = 'Director Medico') AS directores,
       COUNT(*) FILTER (WHERE m.cargo = 'Jefe de Servicio') AS jefes_de_servicio,
       COUNT(*) FILTER (WHERE m.cargo = 'Medico') AS medicos,
       MAX(n.profundidad) AS niveles_de_la_cadena
FROM nivel n
JOIN medico m USING (id_medico)
JOIN hospital h ON h.id_hospital = n.id_hospital
GROUP BY h.nombre
ORDER BY h.nombre;

-- (c) Llaves foraneas nuevas con la accion referencial elegida para DELETE y UPDATE
SELECT c.conrelid::regclass AS tabla,
       c.conname AS llave_foranea,
       c.confrelid::regclass AS referencia,
       CASE c.confdeltype WHEN 'a' THEN 'NO ACTION' WHEN 'r' THEN 'RESTRICT' WHEN 'c' THEN 'CASCADE' WHEN 'n' THEN 'SET NULL' WHEN 'd' THEN 'SET DEFAULT' END AS on_delete,
       CASE c.confupdtype WHEN 'a' THEN 'NO ACTION' WHEN 'r' THEN 'RESTRICT' WHEN 'c' THEN 'CASCADE' WHEN 'n' THEN 'SET NULL' WHEN 'd' THEN 'SET DEFAULT' END AS on_update
FROM pg_constraint c
WHERE c.contype = 'f'
  AND c.conname IN ('fk_medico_personal', 'fk_enfermero_personal', 'fk_encargado_personal', 'fk_medico_supervisor',
                    'fk_turno_medico', 'fk_turno_unidad', 'fk_auditoria_medico')
ORDER BY c.conrelid::regclass::text, c.conname;

-- (d) Restricciones CHECK de las estructuras nuevas
SELECT c.conrelid::regclass AS tabla, c.conname AS restriccion, pg_get_constraintdef(c.oid) AS definicion
FROM pg_constraint c
WHERE c.contype = 'c'
  AND c.conname ~ '^chk_(personal_|medico_(tipo_personal|cargo|salario|nivel_acceso|no_autosupervisor|director_sin_supervisor)|enfermero_(tipo_personal|colegiado)|encargado_tipo_personal|turno_|ingreso_turno_espera|cuota_metodo_pago|auditoria_)'
ORDER BY c.conrelid::regclass::text, c.conname;

-- (e) La extension es aditiva: las 9 columnas del Proyecto 1 de MEDICO siguen existiendo
SELECT COUNT(*) AS columnas_del_proyecto_1_conservadas
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'medico'
  AND column_name IN ('id_medico', 'nombre', 'dpi', 'id_especialidad', 'tipo_medico', 'id_hospital', 'telefono', 'id_municipio', 'area');
