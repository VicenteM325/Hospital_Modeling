-- OBJETIVO 5 (Bloque A): los 3 cirujanos mas eficientes.
-- Eficiente = pedir la menor cantidad de insumos, instrumentos y equipos descritos en sus agendamientos
-- quirurgicos (cada campo por separado) y tener el mayor numero de agendamientos aprobados, dentro del
-- lapso indicado (se toma la fecha de la solicitud).
-- Las cantidades se comparan como PROMEDIO POR CIRUGIA APROBADA (la suma se muestra aparte): si se
-- compararan las sumas, quien mas opera pediria mas material y quedaria penalizado dos veces, porque el
-- mismo enunciado le pide tambien tener mas agendamientos aprobados.
-- Cada uno de los 4 criterios pesa igual: RANK() por criterio y gana la menor suma de posiciones.
-- Parametros psql: :fecha_inicio y :fecha_fin (inclusive).
\if :{?fecha_inicio} \else \set fecha_inicio '2026-08-01' \endif
\if :{?fecha_fin} \else \set fecha_fin '2026-10-24' \endif

WITH aprobadas AS (
    SELECT id_solicitud, id_cirujano
    FROM solicitud_cirugia
    WHERE estado = 'Aprobada'
      AND fecha_hora_solicitud::date BETWEEN :'fecha_inicio'::date AND :'fecha_fin'::date
), insumos AS (
    SELECT a.id_cirujano, SUM(r.cantidad) AS total FROM aprobadas a JOIN requerimiento_insumo r USING (id_solicitud) GROUP BY a.id_cirujano
), instrumentos AS (
    SELECT a.id_cirujano, SUM(r.cantidad) AS total FROM aprobadas a JOIN requerimiento_instrumento r USING (id_solicitud) GROUP BY a.id_cirujano
), equipos AS (
    SELECT a.id_cirujano, SUM(r.cantidad) AS total FROM aprobadas a JOIN requerimiento_equipo r USING (id_solicitud) GROUP BY a.id_cirujano
), medidas AS (
    SELECT a.id_cirujano,
           COUNT(*) AS cirugias_aprobadas,
           COALESCE(MAX(i.total), 0) AS insumos,
           COALESCE(MAX(n.total), 0) AS instrumentos,
           COALESCE(MAX(e.total), 0) AS equipos,
           ROUND(COALESCE(MAX(i.total), 0)::numeric / COUNT(*), 1) AS insumos_por_cirugia,
           ROUND(COALESCE(MAX(n.total), 0)::numeric / COUNT(*), 1) AS instrumentos_por_cirugia,
           ROUND(COALESCE(MAX(e.total), 0)::numeric / COUNT(*), 1) AS equipos_por_cirugia
    FROM aprobadas a
    LEFT JOIN insumos i USING (id_cirujano)
    LEFT JOIN instrumentos n USING (id_cirujano)
    LEFT JOIN equipos e USING (id_cirujano)
    GROUP BY a.id_cirujano
), posiciones AS (
    SELECT *,
           RANK() OVER (ORDER BY insumos_por_cirugia ASC) AS pos_insumos,
           RANK() OVER (ORDER BY instrumentos_por_cirugia ASC) AS pos_instrumentos,
           RANK() OVER (ORDER BY equipos_por_cirugia ASC) AS pos_equipos,
           RANK() OVER (ORDER BY cirugias_aprobadas DESC) AS pos_aprobadas
    FROM medidas
)
SELECT m.id_medico,
       m.nombre AS cirujano,
       h.nombre AS hospital,
       p.cirugias_aprobadas, p.insumos, p.instrumentos, p.equipos,
       p.insumos_por_cirugia, p.instrumentos_por_cirugia, p.equipos_por_cirugia,
       p.pos_insumos + p.pos_instrumentos + p.pos_equipos + p.pos_aprobadas AS puntaje
FROM posiciones p
JOIN medico m ON m.id_medico = p.id_cirujano
JOIN hospital h ON h.id_hospital = m.id_hospital
ORDER BY puntaje, p.cirugias_aprobadas DESC, m.id_medico
LIMIT 3;
