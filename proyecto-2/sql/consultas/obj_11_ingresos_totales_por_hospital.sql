-- OBJETIVO 11 (Bloque A): ingresos monetarios totales de cada hospital en un lapso de tiempo.
-- Ingreso = monto de las facturas emitidas en el lapso (por fecha de factura). Los hospitales sin facturas
-- aparecen con 0 gracias al LEFT JOIN.
-- Parametros psql: :fecha_inicio y :fecha_fin (inclusive).
\if :{?fecha_inicio} \else \set fecha_inicio '2026-08-01' \endif
\if :{?fecha_fin} \else \set fecha_fin '2026-10-24' \endif

SELECT h.id_hospital,
       h.nombre AS hospital,
       COUNT(f.id_factura) AS facturas,
       COALESCE(SUM(f.monto), 0) AS total_facturado
FROM hospital h
LEFT JOIN factura f
       ON f.id_hospital = h.id_hospital
      AND f.fecha BETWEEN :'fecha_inicio'::date AND :'fecha_fin'::date
GROUP BY h.id_hospital, h.nombre
ORDER BY total_facturado DESC, h.nombre;
