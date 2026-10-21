-- AUDITORIA 2: demostracion del mecanismo con cambios de prueba (objetivo 20)
-- Ejecutar conectado como usr_admin_bd (sin SET ROLE) para que usuario_bd registre a quien hace el cambio.
-- Los medicos 11, 14 y 24 (DML 06).

-- Estado antes de los cambios
SELECT m.id_medico, m.nombre, m.id_especialidad, m.salario, m.nivel_acceso
FROM medico m WHERE m.id_medico IN (11, 14, 24) ORDER BY m.id_medico;

-- Cambio de prueba 1: aumento de salario del 10 %
UPDATE medico SET salario = ROUND(salario * 1.10, -1) WHERE id_medico = 11;

-- Cambio de prueba 2: se sube el nivel de acceso
UPDATE medico SET nivel_acceso = 'Avanzado' WHERE id_medico = 14;

-- Cambio de prueba 3: cambia la especialidad y el salario en una sola sentencia (genera dos filas de auditoria)
UPDATE medico SET id_especialidad = 1, salario = 10500 WHERE id_medico = 24;

-- Estos cambios NO deben auditarse: un campo no sensible y un valor que queda igual
UPDATE medico SET area = 'Rural' WHERE id_medico = 24;
UPDATE medico SET salario = salario WHERE id_medico = 11;

-- Resultado registrado por el trigger (la especialidad se muestra con su nombre)
SELECT a.id_auditoria, a.fecha_hora, a.usuario_bd, m.nombre AS medico, a.campo, a.valor_anterior, a.valor_nuevo
FROM auditoria_medico a
JOIN medico m USING (id_medico)
ORDER BY a.id_auditoria;
