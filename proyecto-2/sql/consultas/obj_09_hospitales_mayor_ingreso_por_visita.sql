-- OBJETIVO 9 (Bloque A): los 3 hospitales con mayores ingresos monetarios por visita.
-- Visitas = ingresos a unidades + consultas + citas no canceladas del hospital en el lapso (cada contacto
-- que menciona el enunciado se cuenta por separado). Ingreso monetario = suma de facturas del lapso.
-- Ingreso por visita = ingreso monetario / visitas: mayor valor = mas ingreso con menos afluencia.
-- Parametros psql: :fecha_inicio y :fecha_fin (inclusive).
\if :{?fecha_inicio} \else \set fecha_inicio '2026-08-01' \endif
\if :{?fecha_fin} \else \set fecha_fin '2026-10-24' \endif

WITH ingresos_monetarios AS (
    SELECT id_hospital, SUM(monto) AS total
    FROM factura
    WHERE fecha BETWEEN :'fecha_inicio'::date AND :'fecha_fin'::date
    GROUP BY id_hospital
), visitas AS (
    SELECT u.id_hospital, COUNT(*) AS n
    FROM ingreso i JOIN unidad_hospital u USING (id_unidad_hospital)
    WHERE i.fecha_hora::date BETWEEN :'fecha_inicio'::date AND :'fecha_fin'::date
    GROUP BY u.id_hospital
    UNION ALL
    SELECT m.id_hospital, COUNT(*)
    FROM consulta_paciente c JOIN medico m USING (id_medico)
    WHERE c.fecha BETWEEN :'fecha_inicio'::date AND :'fecha_fin'::date
    GROUP BY m.id_hospital
    UNION ALL
    SELECT m.id_hospital, COUNT(*)
    FROM cita_programada c JOIN medico m USING (id_medico)
    WHERE c.estado <> 'Cancelada' AND c.fecha BETWEEN :'fecha_inicio'::date AND :'fecha_fin'::date
    GROUP BY m.id_hospital
), total_visitas AS (
    SELECT id_hospital, SUM(n) AS visitas FROM visitas GROUP BY id_hospital
)
SELECT h.id_hospital,
       h.nombre AS hospital,
       i.total AS ingresos_monetarios,
       v.visitas,
       ROUND(i.total / v.visitas, 2) AS ingreso_por_visita
FROM hospital h
JOIN ingresos_monetarios i USING (id_hospital)
JOIN total_visitas v USING (id_hospital)
ORDER BY ingreso_por_visita DESC, h.nombre
LIMIT 3;
