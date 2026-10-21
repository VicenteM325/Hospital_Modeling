-- OBJETIVO 10 (Bloque A): fecha con mayor cantidad de decesos por hospital y unidad medica donde se
-- registro la mayoria ese dia. Deceso = ficha de egreso con codigo_egreso = 'Muerto'; el hospital y la
-- unidad salen del ingreso que esa ficha cierra. Si dos fechas empatan en el maximo se muestran ambas.
-- (Sin parametros de fecha: el enunciado pide la fecha con mas decesos de todo el historial.)

WITH decesos AS (
    SELECT u.id_hospital, u.tipo_unidad, g.fecha_hora::date AS fecha
    FROM egreso g
    JOIN ingreso i USING (id_ingreso)
    JOIN unidad_hospital u USING (id_unidad_hospital)
    WHERE g.codigo_egreso = 'Muerto'
), por_fecha AS (
    SELECT id_hospital, fecha, COUNT(*) AS decesos,
           RANK() OVER (PARTITION BY id_hospital ORDER BY COUNT(*) DESC) AS pos
    FROM decesos
    GROUP BY id_hospital, fecha
), por_unidad AS (
    SELECT id_hospital, fecha, tipo_unidad, COUNT(*) AS decesos_unidad,
           RANK() OVER (PARTITION BY id_hospital, fecha ORDER BY COUNT(*) DESC) AS pos
    FROM decesos
    GROUP BY id_hospital, fecha, tipo_unidad
)
SELECT h.nombre AS hospital,
       f.fecha,
       f.decesos,
       u.tipo_unidad AS unidad_medica,
       u.decesos_unidad AS decesos_en_la_unidad
FROM por_fecha f
JOIN hospital h USING (id_hospital)
JOIN por_unidad u ON u.id_hospital = f.id_hospital AND u.fecha = f.fecha AND u.pos = 1
WHERE f.pos = 1
ORDER BY h.nombre, f.fecha;
