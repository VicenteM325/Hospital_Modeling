-- OBJETIVO 18 (Bloque D): pacientes que recibieron atencion en TODAS las unidades medicas de un hospital
-- (Consulta Externa, Emergencias, Cirugia y Hospitalizacion) dentro de un lapso, para invitarlos al programa
-- de fidelidad. Es una division relacional: se juntan las atenciones de cada paciente por hospital y se
-- queda con quienes cubren las 4 unidades (HAVING COUNT(DISTINCT unidad) = 4).
-- Consulta Externa = consulta de un medico del hospital; las otras tres unidades = ingresos a esa unidad.
-- Parametros psql: :fecha_inicio y :fecha_fin (inclusive).
\if :{?fecha_inicio} \else \set fecha_inicio '2026-08-01' \endif
\if :{?fecha_fin} \else \set fecha_fin '2026-10-24' \endif

WITH atenciones AS (
    SELECT m.id_hospital, c.id_paciente, 'Consulta Externa' AS unidad, c.fecha AS fecha
    FROM consulta_paciente c
    JOIN medico m USING (id_medico)
    WHERE c.fecha BETWEEN :'fecha_inicio'::date AND :'fecha_fin'::date
    UNION ALL
    SELECT u.id_hospital, i.id_paciente, u.tipo_unidad, i.fecha_hora::date
    FROM ingreso i
    JOIN unidad_hospital u USING (id_unidad_hospital)
    WHERE i.fecha_hora::date BETWEEN :'fecha_inicio'::date AND :'fecha_fin'::date
)
SELECT h.nombre AS hospital,
       p.no_expediente,
       p.nombres || ' ' || p.apellidos AS paciente,
       COUNT(DISTINCT a.unidad) AS unidades_atendidas,
       MIN(a.fecha) AS primera_atencion,
       MAX(a.fecha) AS ultima_atencion
FROM atenciones a
JOIN paciente p USING (id_paciente)
JOIN hospital h ON h.id_hospital = a.id_hospital
GROUP BY h.nombre, p.id_paciente, p.no_expediente, p.nombres, p.apellidos
HAVING COUNT(DISTINCT a.unidad) = 4
ORDER BY h.nombre, p.no_expediente;
