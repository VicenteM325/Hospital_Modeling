-- OBJETIVO 17 - VARIANTE B: subconsulta correlacionada.
-- La posicion de un medico = 1 + cuantos medicos lo superan (tienen menor nota, o igual nota y mas consultas, o igual y menor id).
-- Para cada medico recorre toda la base dos veces (hospital y cadena): costo O(n^2).

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
    SELECT b.*,
           (SELECT COUNT(*) + 1 FROM base x WHERE x.id_hospital = b.id_hospital AND (x.calificacion_promedio, -x.numero_consultas, x.id_medico) < (b.calificacion_promedio, -b.numero_consultas, b.id_medico)) AS pos_hospital,
           (SELECT COUNT(*) + 1 FROM base x WHERE (x.calificacion_promedio, -x.numero_consultas, x.id_medico) < (b.calificacion_promedio, -b.numero_consultas, b.id_medico)) AS pos_cadena
    FROM base b
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
