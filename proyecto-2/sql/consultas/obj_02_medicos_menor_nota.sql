-- OBJETIVO 2 (Bloque A): los 5 medicos de consulta externa con menor nota (escala 1 a 5).
-- Nota = calificacion promedio del medico; se muestra con el numero de consultas y el servicio
-- (especialidad). Solo cuentan medicos que han dado consultas en Consulta Externa.
-- Desempate: mas consultas primero y, si persiste, menor id (asi el resultado es siempre el mismo).

WITH nota AS (
    SELECT id_medico, ROUND(AVG(puntaje), 2) AS calificacion_promedio, COUNT(*) AS numero_calificaciones
    FROM calificacion_medico
    GROUP BY id_medico
), consultas AS (
    SELECT id_medico, COUNT(*) AS numero_consultas
    FROM consulta_paciente
    GROUP BY id_medico
)
SELECT m.id_medico,
       m.nombre AS medico,
       e.nombre AS servicio,
       h.nombre AS hospital,
       n.calificacion_promedio,
       n.numero_calificaciones,
       c.numero_consultas
FROM medico m
JOIN nota n USING (id_medico)
JOIN consultas c USING (id_medico)
JOIN especialidad e ON e.id_especialidad = m.id_especialidad
JOIN hospital h ON h.id_hospital = m.id_hospital
ORDER BY n.calificacion_promedio ASC, c.numero_consultas DESC, m.id_medico
LIMIT 5;
