-- OBJETIVO 17 - VARIANTE A: funciones de ventana. Es la misma consulta de ../obj_17_ranking_global_y_por_hospital.sql.
-- Ordena la base una vez por hospital y una vez en toda la cadena: costo O(n log n).

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
           ROW_NUMBER() OVER (PARTITION BY b.id_hospital ORDER BY b.calificacion_promedio, b.numero_consultas DESC, b.id_medico) AS pos_hospital,
           ROW_NUMBER() OVER (ORDER BY b.calificacion_promedio, b.numero_consultas DESC, b.id_medico) AS pos_cadena
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
