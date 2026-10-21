-- OBJETIVO 14 (Bloque A): promedio del numero de cuotas de pago por unidad medica en cada hospital.
-- Primero se cuenta cuantas cuotas tiene cada factura y luego se promedia por hospital y unidad.
-- La unidad de la factura es Consulta Externa si viene de una consulta, o la unidad del ingreso si viene
-- de un ingreso. Lapso = fecha de la factura.
-- Parametros psql: :fecha_inicio y :fecha_fin (inclusive).
\if :{?fecha_inicio} \else \set fecha_inicio '2026-08-01' \endif
\if :{?fecha_fin} \else \set fecha_fin '2026-10-24' \endif

WITH cuotas_por_factura AS (
    SELECT f.id_factura,
           f.id_hospital,
           COALESCE(u.tipo_unidad, 'Consulta Externa') AS unidad,
           COUNT(c.id_cuota) AS cuotas
    FROM factura f
    LEFT JOIN cuota c USING (id_factura)
    LEFT JOIN ingreso i ON i.id_ingreso = f.id_ingreso
    LEFT JOIN unidad_hospital u ON u.id_unidad_hospital = i.id_unidad_hospital
    WHERE f.fecha BETWEEN :'fecha_inicio'::date AND :'fecha_fin'::date
    GROUP BY f.id_factura, f.id_hospital, u.tipo_unidad
)
SELECT h.nombre AS hospital,
       x.unidad,
       COUNT(*) AS facturas,
       ROUND(AVG(x.cuotas), 2) AS promedio_cuotas,
       MAX(x.cuotas) AS maximo_cuotas
FROM cuotas_por_factura x
JOIN hospital h ON h.id_hospital = x.id_hospital
GROUP BY h.nombre, x.unidad
ORDER BY h.nombre, x.unidad;
