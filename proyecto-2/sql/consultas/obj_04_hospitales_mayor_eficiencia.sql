-- OBJETIVO 4 (Bloque A): los 3 hospitales mas eficientes en Emergencias.
-- Eficiente = tener siempre camillas disponibles cuando llega el paciente. Se mide, en la unidad de
-- Emergencias y en el lapso indicado, con:
--   * rotacion = egresos / ingresos (la unidad libera camas al ritmo en que ingresa pacientes);
--   * % de ingresos con camilla asignada al llegar (id_camilla no nulo);
--   * promedio de turnos de espera para ser atendido (ingreso.turno_espera, menor es mejor).
-- Cada criterio pesa igual: se ordena con RANK() y gana la menor suma de posiciones (puntaje).
-- Parametros psql: :fecha_inicio y :fecha_fin (inclusive).
\if :{?fecha_inicio} \else \set fecha_inicio '2026-08-01' \endif
\if :{?fecha_fin} \else \set fecha_fin '2026-10-24' \endif

WITH medidas AS (
    SELECT u.id_hospital,
           COUNT(*) AS ingresos,
           COUNT(g.id_egreso) AS egresos,
           ROUND(100.0 * COUNT(g.id_egreso) / COUNT(*), 1) AS rotacion_pct,
           ROUND(100.0 * COUNT(i.id_camilla) / COUNT(*), 1) AS con_camilla_pct,
           ROUND(AVG(i.turno_espera), 2) AS espera_promedio
    FROM ingreso i
    JOIN unidad_hospital u USING (id_unidad_hospital)
    LEFT JOIN egreso g ON g.id_ingreso = i.id_ingreso
    WHERE u.tipo_unidad = 'Emergencias'
      AND i.fecha_hora::date BETWEEN :'fecha_inicio'::date AND :'fecha_fin'::date
    GROUP BY u.id_hospital
), posiciones AS (
    SELECT *,
           RANK() OVER (ORDER BY rotacion_pct DESC) AS pos_rotacion,
           RANK() OVER (ORDER BY con_camilla_pct DESC) AS pos_camilla,
           RANK() OVER (ORDER BY espera_promedio ASC) AS pos_espera
    FROM medidas
)
SELECT h.id_hospital,
       h.nombre AS hospital,
       p.ingresos, p.egresos, p.rotacion_pct, p.con_camilla_pct, p.espera_promedio,
       p.pos_rotacion + p.pos_camilla + p.pos_espera AS puntaje
FROM posiciones p
JOIN hospital h USING (id_hospital)
ORDER BY puntaje, p.espera_promedio, h.nombre
LIMIT 3;
