-- OBJETIVO 7 (Bloque A): los 3 hospitales con mayores ingresos monetarios en Hospitalizacion,
-- con menor numero de camillas asignadas y menor costo de servicio (modelos para los demas).
-- Ingreso de una estadia = costo_dia * dias (solo estadias ya terminadas, con dias registrados),
-- segun la fecha de ingreso dentro del lapso. Camillas asignadas = camillas distintas usadas.
-- Los 3 criterios pesan igual: RANK() por criterio y gana la menor suma de posiciones.
-- Parametros psql: :fecha_inicio y :fecha_fin (inclusive).
\if :{?fecha_inicio} \else \set fecha_inicio '2026-08-01' \endif
\if :{?fecha_fin} \else \set fecha_fin '2026-10-24' \endif

WITH medidas AS (
    SELECT u.id_hospital,
           COUNT(*) AS estadias,
           SUM(d.costo_dia * d.dias) AS ingresos_hospitalizacion,
           COUNT(DISTINCT d.id_camilla) AS camillas_asignadas,
           ROUND(AVG(d.costo_dia), 2) AS costo_dia_promedio
    FROM hospitalizacion_detalle d
    JOIN ingreso i USING (id_ingreso)
    JOIN unidad_hospital u USING (id_unidad_hospital)
    WHERE d.dias IS NOT NULL
      AND i.fecha_hora::date BETWEEN :'fecha_inicio'::date AND :'fecha_fin'::date
    GROUP BY u.id_hospital
), posiciones AS (
    SELECT *,
           RANK() OVER (ORDER BY ingresos_hospitalizacion DESC) AS pos_ingresos,
           RANK() OVER (ORDER BY camillas_asignadas ASC) AS pos_camillas,
           RANK() OVER (ORDER BY costo_dia_promedio ASC) AS pos_costo
    FROM medidas
)
SELECT h.id_hospital,
       h.nombre AS hospital,
       p.estadias, p.ingresos_hospitalizacion, p.camillas_asignadas, p.costo_dia_promedio,
       p.pos_ingresos + p.pos_camillas + p.pos_costo AS puntaje
FROM posiciones p
JOIN hospital h USING (id_hospital)
ORDER BY puntaje, p.ingresos_hospitalizacion DESC, h.nombre
LIMIT 3;
