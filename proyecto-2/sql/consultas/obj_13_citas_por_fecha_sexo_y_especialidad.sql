-- OBJETIVO 13 (Bloque A): reporte de citas de consulta externa de cada hospital, ordenado por fecha y
-- agrupado por sexo del paciente y especialidad del medico. Se excluyen las citas canceladas (no son
-- demanda). El hospital de la cita es el del medico. La ultima columna acumula la demanda de la
-- especialidad en cada hospital, para ver de un vistazo que areas tienen mayor demanda.
-- Parametros psql: :fecha_inicio y :fecha_fin (inclusive).
\if :{?fecha_inicio} \else \set fecha_inicio '2026-08-01' \endif
\if :{?fecha_fin} \else \set fecha_fin '2026-10-24' \endif

SELECT h.nombre AS hospital,
       c.fecha,
       p.sexo,
       e.nombre AS especialidad,
       COUNT(*) AS citas,
       SUM(COUNT(*)) OVER (PARTITION BY h.nombre, e.nombre) AS citas_de_la_especialidad_en_el_hospital
FROM cita_programada c
JOIN paciente p USING (id_paciente)
JOIN medico m USING (id_medico)
JOIN especialidad e ON e.id_especialidad = m.id_especialidad
JOIN hospital h ON h.id_hospital = m.id_hospital
WHERE c.estado <> 'Cancelada'
  AND c.fecha BETWEEN :'fecha_inicio'::date AND :'fecha_fin'::date
GROUP BY h.nombre, c.fecha, p.sexo, e.nombre
ORDER BY h.nombre, c.fecha, p.sexo, e.nombre;
