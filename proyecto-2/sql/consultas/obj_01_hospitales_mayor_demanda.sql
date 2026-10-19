-- OBJETIVO 1 (Bloque A): los 3 hospitales con mayor demanda en consulta externa.
-- Demanda = reservaciones (citas no canceladas) + consultas realizadas + proximas consultas
-- (proxima_cita indicada en las recetas), cada una sumada en el lapso de tiempo indicado.
-- Parametros psql: :fecha_inicio y :fecha_fin (inclusive). Por defecto, todo el periodo de pruebas.
\if :{?fecha_inicio} \else \set fecha_inicio '2026-08-01' \endif
\if :{?fecha_fin} \else \set fecha_fin '2026-10-24' \endif

WITH reservaciones AS (        -- las citas canceladas no se toman en cuenta; el hospital es el del medico
    SELECT m.id_hospital, COUNT(*) AS total
    FROM cita_programada c
    JOIN medico m USING (id_medico)
    WHERE c.estado <> 'Cancelada' AND c.fecha BETWEEN :'fecha_inicio'::date AND :'fecha_fin'::date
    GROUP BY m.id_hospital
), consultas AS (
    SELECT m.id_hospital, COUNT(*) AS total
    FROM consulta_paciente c
    JOIN medico m USING (id_medico)
    WHERE c.fecha BETWEEN :'fecha_inicio'::date AND :'fecha_fin'::date
    GROUP BY m.id_hospital
), proximas AS (               -- la receta ya guarda el hospital que la emitio
    SELECT r.id_hospital, COUNT(*) AS total
    FROM receta_medica r
    WHERE r.proxima_cita BETWEEN :'fecha_inicio'::date AND :'fecha_fin'::date
    GROUP BY r.id_hospital
)
SELECT h.id_hospital,
       h.nombre AS hospital,
       COALESCE(r.total, 0) AS reservaciones,
       COALESCE(c.total, 0) AS consultas,
       COALESCE(p.total, 0) AS proximas_consultas,
       COALESCE(r.total, 0) + COALESCE(c.total, 0) + COALESCE(p.total, 0) AS demanda_total
FROM hospital h
LEFT JOIN reservaciones r USING (id_hospital)
LEFT JOIN consultas c USING (id_hospital)
LEFT JOIN proximas p USING (id_hospital)
ORDER BY demanda_total DESC, h.nombre
LIMIT 3;
