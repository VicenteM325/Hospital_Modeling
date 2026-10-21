-- OBJETIVO 17 (Bloque C): ranking de medicos de consulta externa con menor nota (objetivo 2) que muestra,
-- en un mismo reporte, la posicion de cada medico dentro de su hospital Y en toda la cadena de hospitales.
-- Se listan los 5 peor calificados de cada hospital con ambas posiciones (pos_cadena <= 5 son los 5 del objetivo 2).
-- Forma elegida (A): FUNCIONES DE VENTANA (ROW_NUMBER con y sin PARTITION BY) sobre una sola pasada de la base.
-- El orden es total (nota, mas consultas, id) para que la posicion sea unica y las otras formas den lo mismo.
-- Las formas alternativas (B: subconsulta correlacionada, C: autojoin) y la comparacion de rendimiento con
-- EXPLAIN ANALYZE segun crece el numero de registros estan en sql/consultas/17_benchmark/.

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
