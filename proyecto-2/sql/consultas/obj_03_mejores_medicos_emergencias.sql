-- OBJETIVO 3 (Bloque A): los 5 mejores medicos de Emergencias.
-- Criterios (en el lapso indicado): horas laboradas, turnos laborados y egresos con codigo 'Vivo'
-- y con consentimiento (egreso_sin_consentimiento = FALSE) dados en la unidad de Emergencias.
-- Como el enunciado no pondera los criterios, cada uno pesa igual: se ordena al medico en cada
-- criterio con RANK() y gana quien tenga la menor suma de posiciones (puntaje). Desempate: mas egresos, mas horas.
-- Parametros psql: :fecha_inicio y :fecha_fin (inclusive).
\if :{?fecha_inicio} \else \set fecha_inicio '2026-08-01' \endif
\if :{?fecha_fin} \else \set fecha_fin '2026-10-24' \endif

WITH emergencias AS (
    SELECT id_unidad_hospital, id_hospital FROM unidad_hospital WHERE tipo_unidad = 'Emergencias'
), turnos AS (
    SELECT t.id_medico, e.id_hospital,
           COUNT(*) AS turnos_laborados,
           SUM(EXTRACT(EPOCH FROM (t.fecha_hora_fin - t.fecha_hora_inicio)) / 3600) AS horas_laboradas
    FROM turno_laboral t
    JOIN emergencias e USING (id_unidad_hospital)
    WHERE t.fecha_hora_inicio::date BETWEEN :'fecha_inicio'::date AND :'fecha_fin'::date
    GROUP BY t.id_medico, e.id_hospital
), altas AS (
    SELECT g.id_medico, COUNT(*) AS egresos_vivos
    FROM egreso g
    JOIN ingreso i USING (id_ingreso)
    JOIN emergencias e ON e.id_unidad_hospital = i.id_unidad_hospital
    WHERE g.codigo_egreso = 'Vivo' AND NOT g.egreso_sin_consentimiento
      AND g.fecha_hora::date BETWEEN :'fecha_inicio'::date AND :'fecha_fin'::date
    GROUP BY g.id_medico
), medidas AS (
    SELECT t.id_medico, t.id_hospital, t.turnos_laborados, t.horas_laboradas, COALESCE(a.egresos_vivos, 0) AS egresos_vivos
    FROM turnos t
    LEFT JOIN altas a USING (id_medico)
), posiciones AS (
    SELECT *,
           RANK() OVER (ORDER BY horas_laboradas DESC) AS pos_horas,
           RANK() OVER (ORDER BY turnos_laborados DESC) AS pos_turnos,
           RANK() OVER (ORDER BY egresos_vivos DESC) AS pos_egresos
    FROM medidas
)
SELECT m.id_medico,
       m.nombre AS medico,
       h.nombre AS hospital,
       p.horas_laboradas::numeric(8, 1) AS horas_laboradas,
       p.turnos_laborados,
       p.egresos_vivos AS egresos_vivos_con_consentimiento,
       p.pos_horas + p.pos_turnos + p.pos_egresos AS puntaje
FROM posiciones p
JOIN medico m USING (id_medico)
JOIN hospital h ON h.id_hospital = p.id_hospital
ORDER BY puntaje, p.egresos_vivos DESC, p.horas_laboradas DESC, m.id_medico
LIMIT 5;
