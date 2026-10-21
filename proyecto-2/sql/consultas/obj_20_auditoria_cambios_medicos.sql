-- OBJETIVO 20 (Bloque F): cambios sensibles registrados automaticamente por la base.
-- El mecanismo (tabla auditoria_medico + trigger trg_medico_auditoria) esta en sql/auditoria/01_auditoria_personal.sql
-- y la prueba con cambios reales en sql/auditoria/02_demostracion_auditoria.sql. Esta consulta muestra el historial
-- con quien lo hizo, que campo cambio, el valor anterior, el valor nuevo y el momento exacto; la especialidad
-- se traduce a su nombre para leerla mejor.

SELECT a.id_auditoria,
       a.fecha_hora,
       a.usuario_bd AS quien_lo_hizo,
       m.nombre AS medico,
       a.campo AS campo_modificado,
       CASE a.campo WHEN 'id_especialidad' THEN (SELECT nombre FROM especialidad WHERE id_especialidad = a.valor_anterior::int)
                    ELSE a.valor_anterior END AS valor_anterior,
       CASE a.campo WHEN 'id_especialidad' THEN (SELECT nombre FROM especialidad WHERE id_especialidad = a.valor_nuevo::int)
                    ELSE a.valor_nuevo END AS valor_nuevo
FROM auditoria_medico a
JOIN medico m USING (id_medico)
ORDER BY a.id_auditoria;
