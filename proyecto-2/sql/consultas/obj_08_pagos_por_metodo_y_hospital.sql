-- OBJETIVO 8 (Bloque A): total de pagos realizados con efectivo, tarjeta de credito y tarjeta de debito
-- en cada hospital, como la sumatoria de lo pagado en cada una de sus unidades.
-- Un pago es una cuota con fecha_pago dentro del lapso. La unidad se obtiene de la factura: si viene de
-- una consulta es Consulta Externa; si viene de un ingreso, es la unidad de ese ingreso.
-- ROLLUP agrega por hospital la fila 'TODAS LAS UNIDADES' (suma de sus unidades) y al final el total de la cadena.
-- Parametros psql: :fecha_inicio y :fecha_fin (inclusive).
\if :{?fecha_inicio} \else \set fecha_inicio '2026-08-01' \endif
\if :{?fecha_fin} \else \set fecha_fin '2026-10-24' \endif

WITH pagos AS (
    SELECT f.id_hospital,
           COALESCE(u.tipo_unidad, 'Consulta Externa') AS unidad,
           c.metodo_pago,
           c.monto
    FROM cuota c
    JOIN factura f USING (id_factura)
    LEFT JOIN ingreso i ON i.id_ingreso = f.id_ingreso
    LEFT JOIN unidad_hospital u ON u.id_unidad_hospital = i.id_unidad_hospital
    WHERE c.fecha_pago BETWEEN :'fecha_inicio'::date AND :'fecha_fin'::date
)
SELECT CASE WHEN GROUPING(h.nombre) = 1 THEN 'TOTAL CADENA' ELSE h.nombre END AS hospital,
       CASE WHEN GROUPING(p.unidad) = 1 THEN 'TODAS LAS UNIDADES' ELSE p.unidad END AS unidad,
       COALESCE(SUM(p.monto) FILTER (WHERE p.metodo_pago = 'Efectivo'), 0) AS efectivo,
       COALESCE(SUM(p.monto) FILTER (WHERE p.metodo_pago = 'Tarjeta de credito'), 0) AS tarjeta_credito,
       COALESCE(SUM(p.monto) FILTER (WHERE p.metodo_pago = 'Tarjeta de debito'), 0) AS tarjeta_debito,
       SUM(p.monto) AS total_pagado
FROM pagos p
JOIN hospital h USING (id_hospital)
GROUP BY ROLLUP (h.nombre, p.unidad)
ORDER BY GROUPING(h.nombre), h.nombre, GROUPING(p.unidad), p.unidad;
