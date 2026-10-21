-- Datos SINTETICOS para medir el objetivo 17 con volumenes crecientes.
-- NO se carga en la base de entrega: lo usa ejecutar_benchmark_obj17.sh sobre una copia desechable
-- (hospital_bd_p2_bench). Agrega :n medicos de consulta externa repartidos en los 5 hospitales, cada uno
-- con 5 calificaciones (con una calidad propia, para que haya variedad de notas) y de 1 a 4 consultas.
-- Uso: psql -d hospital_bd_p2_bench -v n=5000 -f datos_sinteticos.sql
SELECT setseed(0.42);

INSERT INTO personal (tipo_personal, nombre, dpi, fecha_contratacion)
SELECT 'Medico', 'Medico sintetico ' || g, '9' || lpad(g::text, 12, '0'), DATE '2020-01-01'
FROM generate_series(1, :n) g;

INSERT INTO medico (id_personal, id_especialidad, tipo_medico, id_hospital)
SELECT p.id_personal, 7, 'Externo', 1 + (substr(p.dpi, 2)::int % 5)
FROM personal p
WHERE p.nombre LIKE 'Medico sintetico %';

WITH calidad AS MATERIALIZED (            -- una calidad entre 1.5 y 5 por medico sintetico
    SELECT m.id_medico, 1.5 + 3.5 * random() AS q
    FROM medico m JOIN personal p USING (id_personal)
    WHERE p.nombre LIKE 'Medico sintetico %'
)
INSERT INTO calificacion_medico (id_medico, puntaje, fecha)
SELECT c.id_medico, LEAST(5, GREATEST(1, ROUND(c.q + (random() - 0.5) * 2)))::int, DATE '2026-09-01'
FROM calidad c CROSS JOIN generate_series(1, 5);

INSERT INTO consulta_paciente (id_paciente, id_medico, fecha, tipo_consulta)
SELECT 1 + (m.id_medico % 30), m.id_medico, DATE '2026-09-01', 'Primera'
FROM medico m JOIN personal p USING (id_personal)
CROSS JOIN LATERAL generate_series(1, 1 + (m.id_medico % 4))
WHERE p.nombre LIKE 'Medico sintetico %';

ANALYZE;
