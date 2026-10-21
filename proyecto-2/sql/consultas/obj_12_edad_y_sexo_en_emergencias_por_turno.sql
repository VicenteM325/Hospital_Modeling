-- OBJETIVO 12 (Bloque A): promedio de edad y distribucion por sexo de los pacientes registrados al ingresar
-- a Emergencias de cada hospital, agrupados por turno.
-- La edad es la que tenia el paciente en la fecha del ingreso. El turno sale de la hora del ingreso con la
-- misma funcion turno_de_hora que usa turno_laboral (Matutino 06-14, Vespertino 14-22, Nocturno 22-06).
-- Parametros psql: :fecha_inicio y :fecha_fin (inclusive).
\if :{?fecha_inicio} \else \set fecha_inicio '2026-08-01' \endif
\if :{?fecha_fin} \else \set fecha_fin '2026-10-24' \endif

SELECT h.nombre AS hospital,
       turno_de_hora(i.fecha_hora) AS turno,
       COUNT(*) AS ingresos,
       ROUND(AVG(DATE_PART('year', AGE(i.fecha_hora, p.fecha_nacimiento)))::numeric, 1) AS edad_promedio,
       COUNT(*) FILTER (WHERE p.sexo = 'F') AS mujeres,
       COUNT(*) FILTER (WHERE p.sexo = 'M') AS hombres,
       ROUND(100.0 * COUNT(*) FILTER (WHERE p.sexo = 'F') / COUNT(*), 1) AS porcentaje_mujeres
FROM ingreso i
JOIN unidad_hospital u USING (id_unidad_hospital)
JOIN hospital h ON h.id_hospital = u.id_hospital
JOIN paciente p USING (id_paciente)
WHERE u.tipo_unidad = 'Emergencias'
  AND i.fecha_hora::date BETWEEN :'fecha_inicio'::date AND :'fecha_fin'::date
GROUP BY h.nombre, turno_de_hora(i.fecha_hora)
ORDER BY h.nombre, CASE turno_de_hora(i.fecha_hora) WHEN 'Matutino' THEN 1 WHEN 'Vespertino' THEN 2 ELSE 3 END;
