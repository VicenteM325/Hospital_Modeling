-- OBJETIVO 17 - VARIANTE C: autojoin con agregacion.
-- Une cada medico con todos los que lo superan y cuenta: COUNT(*) da la posicion en la cadena y
-- COUNT(*) FILTER (mismo hospital) la posicion en el hospital. Es un join sin igualdad (desigualdad de filas): costo O(n^2).

WITH nota AS (
    SELECT id_medico, ROUND(AVG(puntaje), 2) AS calificacion_promedio, COUNT(*) AS numero_calificaciones
    FROM calificacion_medico
    GROUP BY id_medico
), consultas AS (
    SELECT id_medico, COUNT(*) AS numero_consultas
    FROM consulta_paciente
    GROUP BY id_medico
), base AS (                      -- medicos de consulta externa con su nota promedio y numero de consultas
    SELECT m.id_medico, m.id_hospital, n.calificacion_promedio, n.numero_calificaciones, c.numero_consultas
    FROM medico m
    JOIN nota n USING (id_medico)
    JOIN consultas c USING (id_medico)
), posiciones AS (
    SELECT b.id_medico, b.id_hospital, b.calificacion_promedio, b.numero_calificaciones, b.numero_consultas,
           COUNT(x.id_medico) FILTER (WHERE x.id_hospital = b.id_hospital) + 1 AS pos_hospital,
           COUNT(x.id_medico) + 1 AS pos_cadena
    FROM base b
    LEFT JOIN base x ON (x.calificacion_promedio, -x.numero_consultas, x.id_medico) < (b.calificacion_promedio, -b.numero_consultas, b.id_medico)
    GROUP BY b.id_medico, b.id_hospital, b.calificacion_promedio, b.numero_calificaciones, b.numero_consultas
)
SELECT h.nombre AS hospital,
       p.pos_hospital,
       p.pos_cadena,
       m.id_medico,
       m.nombre AS medico,
       e.nombre AS servicio,
       p.calificacion_promedio,
       p.numero_consultas
FROM posiciones p
JOIN medico m USING (id_medico)
JOIN hospital h ON h.id_hospital = p.id_hospital
JOIN especialidad e ON e.id_especialidad = m.id_especialidad
WHERE p.pos_hospital <= 5
ORDER BY h.nombre, p.pos_hospital;
