-- OBJETIVO 6 (Bloque A): los 3 tipos de cirugia con mayores ingresos monetarios entre todos los hospitales.
-- Solo cuentan las cirugias sin complicaciones:
--   * intraoperatorio: todos los procedimientos y chequeos con resultado 'Exito' o 'Aceptable';
--   * evolucion (postoperatorio): todos sus registros con resultado 'Exito' o 'Aceptable'.
-- bool_and(...) FILTER devuelve NULL si la cirugia no tiene registros de esa etapa, y entonces el
-- HAVING la descarta: una cirugia sin registro de evolucion (por ejemplo, una defuncion) no se acepta.
-- Ingreso monetario = cirugia.costo; tipo de cirugia = solicitud_cirugia.tipo_procedimiento.
-- Parametros psql: :fecha_inicio y :fecha_fin (inclusive, sobre el inicio de la cirugia).
\if :{?fecha_inicio} \else \set fecha_inicio '2026-08-01' \endif
\if :{?fecha_fin} \else \set fecha_fin '2026-10-24' \endif

WITH sin_complicaciones AS (
    SELECT id_cirugia
    FROM registro_procedimiento_cirugia
    GROUP BY id_cirugia
    HAVING bool_and(resultado IN ('Exito', 'Aceptable')) FILTER (WHERE etapa = 'Intraoperatorio')
       AND bool_and(resultado IN ('Exito', 'Aceptable')) FILTER (WHERE etapa = 'Postoperatorio')
)
SELECT s.tipo_procedimiento AS tipo_cirugia,
       COUNT(*) AS cirugias,
       SUM(c.costo) AS ingresos_monetarios,
       ROUND(AVG(c.costo), 2) AS costo_promedio
FROM cirugia c
JOIN sin_complicaciones USING (id_cirugia)
JOIN solicitud_cirugia s USING (id_solicitud)
WHERE c.fecha_hora_inicio::date BETWEEN :'fecha_inicio'::date AND :'fecha_fin'::date
GROUP BY s.tipo_procedimiento
ORDER BY ingresos_monetarios DESC, s.tipo_procedimiento
LIMIT 3;
