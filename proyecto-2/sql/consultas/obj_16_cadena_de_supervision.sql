-- OBJETIVO 16 (Bloque C): cadena de supervision de un medico hasta el director medico de su hospital.
-- CTE recursiva: parte del medico indicado (nivel 0) y sube un jefe a la vez por medico.id_supervisor.
-- Termina sola cuando ya no hay supervisor, asi que no importa cuantos niveles existan ni hace falta
-- conocerlos de antemano. La jerarquia no tiene ciclos (lo impide trg_medico_evitar_ciclo), por eso UNION ALL basta.
-- Parametro psql: :id_medico (por defecto 11, que tiene 4 niveles hasta el director).
\if :{?id_medico} \else \set id_medico 11 \endif

WITH RECURSIVE cadena AS (
    SELECT 0 AS nivel, m.id_medico, m.id_supervisor
    FROM medico m
    WHERE m.id_medico = :'id_medico'::int
    UNION ALL
    SELECT c.nivel + 1, s.id_medico, s.id_supervisor
    FROM cadena c
    JOIN medico s ON s.id_medico = c.id_supervisor
)
SELECT c.nivel,
       m.id_medico,
       m.nombre AS medico,
       m.cargo,
       h.nombre AS hospital,
       CASE WHEN c.nivel = 0 THEN 'medico consultado'
            WHEN m.cargo = 'Director Medico' THEN 'director medico (fin de la cadena)'
            ELSE 'supervisor' END AS rol_en_la_cadena
FROM cadena c
JOIN medico m USING (id_medico)
JOIN hospital h ON h.id_hospital = m.id_hospital
ORDER BY c.nivel;
