-- Pruebas de las restricciones nuevas del Proyecto 2: cada caso intenta una operacion y comprueba
-- si la base la RECHAZA o la ACEPTA. Todo corre dentro de una transaccion que termina en ROLLBACK,
-- asi que no deja cambios. Si algun caso no se comporta como se espera, el script falla.
--
-- Uso: psql -U usr_admin_bd -d hospital_bd_p2 -v ON_ERROR_STOP=1 -f proyecto-2/scripts/pruebas_restricciones.sql
\set QUIET on
BEGIN;
SET ROLE rol_administrador;

CREATE TEMP TABLE resultado_pruebas (n SERIAL, prueba TEXT, esperado TEXT, obtenido TEXT, ok BOOLEAN);

-- Ejecuta una sentencia y registra si fue aceptada o rechazada (con el codigo y mensaje del error)
CREATE FUNCTION pg_temp.probar(p_prueba TEXT, p_esperado TEXT, p_sql TEXT) RETURNS VOID LANGUAGE plpgsql AS $$
DECLARE
    v_obtenido TEXT;
BEGIN
    BEGIN
        EXECUTE p_sql;
        v_obtenido := 'ACEPTADO';
    EXCEPTION WHEN OTHERS THEN
        v_obtenido := 'RECHAZADO [' || SQLSTATE || '] ' || left(SQLERRM, 80);
    END;
    INSERT INTO resultado_pruebas (prueba, esperado, obtenido, ok)
    VALUES (p_prueba, p_esperado, v_obtenido, v_obtenido LIKE p_esperado || '%');
END
$$;

-- ======================= Bloque B: supertipo PERSONAL y subtipos =======================
SELECT pg_temp.probar('personal: tipo fuera del discriminador', 'RECHAZADO',
    $$INSERT INTO personal (tipo_personal, nombre, dpi, fecha_contratacion) VALUES ('Conserje', 'Prueba Uno', '9000000000001', '2026-01-01')$$);
SELECT pg_temp.probar('personal: DPI con formato invalido', 'RECHAZADO',
    $$INSERT INTO personal (tipo_personal, nombre, dpi, fecha_contratacion) VALUES ('Medico', 'Prueba Dos', '12345', '2026-01-01')$$);
SELECT pg_temp.probar('personal: contratacion en el futuro', 'RECHAZADO',
    $$INSERT INTO personal (tipo_personal, nombre, dpi, fecha_contratacion) VALUES ('Medico', 'Prueba Tres', '9000000000003', CURRENT_DATE + 1)$$);
SELECT pg_temp.probar('personal: telefono con formato invalido', 'RECHAZADO',
    $$INSERT INTO personal (tipo_personal, nombre, dpi, fecha_contratacion, telefono) VALUES ('Medico', 'Prueba Cuatro', '9000000000004', '2026-01-01', '123')$$);
SELECT pg_temp.probar('personal: DPI repetido entre tipos de personal', 'RECHAZADO',
    $$INSERT INTO personal (tipo_personal, nombre, dpi, fecha_contratacion) SELECT 'Enfermero', 'Copia', dpi, '2026-01-01' FROM personal WHERE id_personal = 1$$);
SELECT pg_temp.probar('personal: alta valida de un enfermero', 'ACEPTADO',
    $$INSERT INTO personal (tipo_personal, nombre, dpi, fecha_contratacion) VALUES ('Enfermero', 'Enfermera Prueba', '9000000000005', '2026-02-01')$$);
SELECT pg_temp.probar('subtipo: enfermero enlazado a personal de tipo Medico', 'RECHAZADO',
    $$INSERT INTO enfermero (id_personal, tipo_enfermero, id_hospital) VALUES (1, 'Registrado', 1)$$);
SELECT pg_temp.probar('subtipo: enfermero enlazado a su propio personal (copia nombre y dpi por trigger)', 'ACEPTADO',
    $$INSERT INTO enfermero (id_personal, tipo_enfermero, id_hospital) SELECT id_personal, 'Registrado', 1 FROM personal WHERE dpi = '9000000000005'$$);
SELECT pg_temp.probar('subtipo: segundo enfermero con el mismo personal (relacion 1:1)', 'RECHAZADO',
    $$INSERT INTO enfermero (id_personal, tipo_enfermero, id_hospital) SELECT id_personal, 'Practicante', 1 FROM personal WHERE dpi = '9000000000005'$$);
SELECT pg_temp.probar('subtipo: enfermero con personal inexistente', 'RECHAZADO',
    $$INSERT INTO enfermero (id_personal, tipo_enfermero, id_hospital) VALUES (99999, 'Registrado', 1)$$);
SELECT pg_temp.probar('enfermero: numero de colegiado con formato invalido', 'RECHAZADO',
    $$UPDATE enfermero SET numero_colegiado = 'ab' WHERE id_enfermero = 1$$);
SELECT pg_temp.probar('personal: borrar supertipo con subtipo existente', 'RECHAZADO',
    $$DELETE FROM personal WHERE id_personal = 1$$);

-- ======================= Bloque B: atributos y jerarquia de MEDICO =====================
SELECT pg_temp.probar('medico: cargo invalido', 'RECHAZADO', $$UPDATE medico SET cargo = 'Gerente' WHERE id_medico = 2$$);
SELECT pg_temp.probar('medico: salario negativo', 'RECHAZADO', $$UPDATE medico SET salario = -1 WHERE id_medico = 2$$);
SELECT pg_temp.probar('medico: nivel de acceso invalido', 'RECHAZADO', $$UPDATE medico SET nivel_acceso = 'Root' WHERE id_medico = 2$$);
SELECT pg_temp.probar('medico: es su propio supervisor (lo detiene el trigger anti-ciclos)', 'RECHAZADO', $$UPDATE medico SET id_supervisor = 2 WHERE id_medico = 2$$);
-- con el trigger anti-ciclos desactivado se comprueba que el CHECK por si solo tambien lo impide
ALTER TABLE medico DISABLE TRIGGER trg_medico_evitar_ciclo;
SELECT pg_temp.probar('medico: es su propio supervisor (CHECK chk_medico_no_autosupervisor)', 'RECHAZADO', $$UPDATE medico SET id_supervisor = 2 WHERE id_medico = 2$$);
ALTER TABLE medico ENABLE TRIGGER trg_medico_evitar_ciclo;
-- medico sin jefe asignado (permitido) que se usa para intentar colgarle al director
SELECT pg_temp.probar('medico: alta de personal y medico sin supervisor asignado', 'ACEPTADO',
    $$INSERT INTO personal (tipo_personal, nombre, dpi, fecha_contratacion) VALUES ('Medico', 'Medico Sin Jefe', '9000000000006', '2026-03-01');
      INSERT INTO medico (id_personal, id_especialidad, tipo_medico, id_hospital) SELECT id_personal, 7, 'Externo', 1 FROM personal WHERE dpi = '9000000000006'$$);
SELECT pg_temp.probar('medico: el director medico tiene supervisor (CHECK chk_medico_director_sin_supervisor)', 'RECHAZADO',
    $$UPDATE medico SET id_supervisor = (SELECT m.id_medico FROM medico m JOIN personal p USING (id_personal) WHERE p.dpi = '9000000000006') WHERE id_medico = 1$$);
SELECT pg_temp.probar('medico: segundo director en el mismo hospital', 'RECHAZADO',
    $$UPDATE medico SET cargo = 'Director Medico', id_supervisor = NULL WHERE id_medico = 2$$);
SELECT pg_temp.probar('medico: supervisor de otro hospital', 'RECHAZADO', $$UPDATE medico SET id_supervisor = 4 WHERE id_medico = 2$$);
SELECT pg_temp.probar('medico: supervisor inexistente', 'RECHAZADO', $$UPDATE medico SET id_supervisor = 99999 WHERE id_medico = 2$$);
SELECT pg_temp.probar('medico: cadena valida de 3 niveles (3 reporta a 2, 2 reporta a 1)', 'ACEPTADO',
    $$UPDATE medico SET cargo = 'Jefe de Servicio' WHERE id_medico = 2; UPDATE medico SET id_supervisor = 2 WHERE id_medico = 3$$);
SELECT pg_temp.probar('medico: ciclo en la jerarquia (2 pasa a reportar a 3)', 'RECHAZADO', $$UPDATE medico SET id_supervisor = 3 WHERE id_medico = 2$$);
SELECT pg_temp.probar('medico: borrar a un jefe con subordinados', 'RECHAZADO', $$DELETE FROM medico WHERE id_medico = 2$$);
SELECT pg_temp.probar('medico: mover a otro hospital a un jefe con subordinados (RESTRICT en UPDATE)', 'RECHAZADO',
    $$UPDATE medico SET id_supervisor = NULL WHERE id_medico = 2; UPDATE medico SET id_hospital = 2 WHERE id_medico = 2$$);

-- ======================= Espejo de columnas del Proyecto 1 =============================
SELECT pg_temp.probar('espejo: cambiar el nombre en personal', 'ACEPTADO', $$UPDATE personal SET nombre = 'Dr. Nombre Corregido' WHERE id_personal = 2$$);
INSERT INTO resultado_pruebas (prueba, esperado, obtenido, ok)
SELECT 'espejo: medico.nombre refleja el cambio de personal', 'ACEPTADO',
       CASE WHEN nombre = 'Dr. Nombre Corregido' THEN 'ACEPTADO' ELSE 'DIVERGE' END, nombre = 'Dr. Nombre Corregido'
FROM medico WHERE id_medico = 2;

-- ======================= Migracion complementaria: turnos, espera y metodo de pago =====
SELECT pg_temp.probar('turno_laboral: turno valido de un medico en una unidad de su hospital', 'ACEPTADO',
    $$INSERT INTO turno_laboral (id_medico, id_unidad_hospital, fecha_hora_inicio, fecha_hora_fin) VALUES (3, 1, '2026-09-01 06:00', '2026-09-01 14:00')$$);
SELECT pg_temp.probar('turno_laboral: el turno se calcula solo a partir de la hora de inicio', 'ACEPTADO',
    $$SELECT 1 / (SELECT count(*) FROM turno_laboral WHERE id_medico = 3 AND turno = 'Matutino')$$);
SELECT pg_temp.probar('turno_laboral: no se puede escribir el turno a mano', 'RECHAZADO',
    $$INSERT INTO turno_laboral (id_medico, id_unidad_hospital, fecha_hora_inicio, fecha_hora_fin, turno) VALUES (3, 1, '2026-09-02 06:00', '2026-09-02 14:00', 'Nocturno')$$);
SELECT pg_temp.probar('turno_laboral: fin anterior al inicio', 'RECHAZADO',
    $$INSERT INTO turno_laboral (id_medico, id_unidad_hospital, fecha_hora_inicio, fecha_hora_fin) VALUES (3, 1, '2026-09-03 14:00', '2026-09-03 06:00')$$);
SELECT pg_temp.probar('turno_laboral: turno de mas de 24 horas', 'RECHAZADO',
    $$INSERT INTO turno_laboral (id_medico, id_unidad_hospital, fecha_hora_inicio, fecha_hora_fin) VALUES (3, 1, '2026-09-04 06:00', '2026-09-05 07:00')$$);
SELECT pg_temp.probar('turno_laboral: unidad de otro hospital', 'RECHAZADO',
    $$INSERT INTO turno_laboral (id_medico, id_unidad_hospital, fecha_hora_inicio, fecha_hora_fin) VALUES (3, 4, '2026-09-06 06:00', '2026-09-06 14:00')$$);
SELECT pg_temp.probar('turno_laboral: turno traslapado con otro del mismo medico', 'RECHAZADO',
    $$INSERT INTO turno_laboral (id_medico, id_unidad_hospital, fecha_hora_inicio, fecha_hora_fin) VALUES (3, 1, '2026-09-01 13:00', '2026-09-01 20:00')$$);
SELECT pg_temp.probar('turno_laboral: turno consecutivo sin traslape', 'ACEPTADO',
    $$INSERT INTO turno_laboral (id_medico, id_unidad_hospital, fecha_hora_inicio, fecha_hora_fin) VALUES (3, 1, '2026-09-01 14:00', '2026-09-01 22:00')$$);
SELECT pg_temp.probar('turno_laboral: borrar un medico con turnos registrados', 'RECHAZADO', $$DELETE FROM medico WHERE id_medico = 3$$);
SELECT pg_temp.probar('turno_de_hora: 22:00 es Nocturno', 'ACEPTADO',
    $$SELECT 1 / (turno_de_hora('2026-09-01 22:00') = 'Nocturno')::int$$);
SELECT pg_temp.probar('ingreso: turno_espera negativo', 'RECHAZADO', $$UPDATE ingreso SET turno_espera = -1 WHERE id_ingreso = 1$$);
SELECT pg_temp.probar('ingreso: turno_espera valido', 'ACEPTADO', $$UPDATE ingreso SET turno_espera = 3 WHERE id_ingreso = 1$$);
SELECT pg_temp.probar('cuota: metodo de pago fuera del catalogo', 'RECHAZADO', $$UPDATE cuota SET metodo_pago = 'Cheque' WHERE id_cuota = 1$$);
SELECT pg_temp.probar('cuota: metodo de pago valido', 'ACEPTADO', $$UPDATE cuota SET metodo_pago = 'Tarjeta de credito' WHERE id_cuota = 1$$);

-- ======================= Normalizacion del reporte de cirugias (esquema propuesta_cirugia) =====
SELECT pg_temp.probar('propuesta: cantidad de insumo no positiva', 'RECHAZADO',
    $$UPDATE propuesta_cirugia.cirugia_insumo SET cantidad = 0 WHERE id_cirugia = 1$$);
SELECT pg_temp.probar('propuesta: borrar un diagnostico que tiene cirugias (RESTRICT)', 'RECHAZADO',
    $$DELETE FROM propuesta_cirugia.diagnostico WHERE codigo = 'K35.8'$$);
SELECT pg_temp.probar('propuesta: cirugia con cirujano inexistente', 'RECHAZADO',
    $$UPDATE propuesta_cirugia.cirugia SET id_cirujano = 999 WHERE id_cirugia = 1$$);
SELECT pg_temp.probar('propuesta: borrar una cirugia elimina su detalle de insumos (CASCADE)', 'ACEPTADO',
    $$DELETE FROM propuesta_cirugia.cirugia WHERE id_cirugia = 1$$);
INSERT INTO resultado_pruebas (prueba, esperado, obtenido, ok)
SELECT 'propuesta: el detalle de la cirugia borrada ya no existe', 'ACEPTADO',
       CASE WHEN COUNT(*) = 0 THEN 'ACEPTADO' ELSE 'QUEDAN FILAS' END, COUNT(*) = 0
FROM propuesta_cirugia.cirugia_insumo WHERE id_cirugia = 1;

-- ======================= Auditoria de cambios sensibles (objetivo 20) =========================
SELECT pg_temp.probar('auditoria: cambiar el salario de un medico', 'ACEPTADO', $$UPDATE medico SET salario = salario + 500 WHERE id_medico = 3$$);
INSERT INTO resultado_pruebas (prueba, esperado, obtenido, ok)
SELECT 'auditoria: el cambio de salario quedo registrado', 'ACEPTADO',
       CASE WHEN COUNT(*) = 1 THEN 'ACEPTADO' ELSE 'FILAS: ' || COUNT(*) END, COUNT(*) = 1
FROM auditoria_medico WHERE id_medico = 3 AND campo = 'salario' AND (valor_nuevo::numeric - valor_anterior::numeric) = 500;
SELECT pg_temp.probar('auditoria: cambiar un campo no sensible (area) no genera fila', 'ACEPTADO', $$UPDATE medico SET area = 'Rural' WHERE id_medico = 3$$);
INSERT INTO resultado_pruebas (prueba, esperado, obtenido, ok)
SELECT 'auditoria: solo existe la fila del salario (ninguna por el area)', 'ACEPTADO',
       CASE WHEN COUNT(*) = 1 THEN 'ACEPTADO' ELSE 'FILAS: ' || COUNT(*) END, COUNT(*) = 1
FROM auditoria_medico WHERE id_medico = 3;
SELECT pg_temp.probar('auditoria: modificar una fila de la bitacora', 'RECHAZADO', $$UPDATE auditoria_medico SET valor_nuevo = '0' WHERE id_medico = 3$$);
SELECT pg_temp.probar('auditoria: borrar filas de la bitacora', 'RECHAZADO', $$DELETE FROM auditoria_medico$$);
SELECT pg_temp.probar('auditoria: vaciar la bitacora con TRUNCATE', 'RECHAZADO', $$TRUNCATE auditoria_medico$$);
SELECT pg_temp.probar('auditoria: campo que no es sensible', 'RECHAZADO',
    $$INSERT INTO auditoria_medico (id_medico, campo, valor_anterior, valor_nuevo) VALUES (3, 'area', 'Urbana', 'Rural')$$);
SELECT pg_temp.probar('auditoria: fila sin cambio real', 'RECHAZADO',
    $$INSERT INTO auditoria_medico (id_medico, campo, valor_anterior, valor_nuevo) VALUES (3, 'salario', '100', '100')$$);
SELECT pg_temp.probar('auditoria: borrar un medico con historial (RESTRICT)', 'RECHAZADO', $$DELETE FROM medico WHERE id_medico = 11$$);

-- ======================= Resultado =====================================================
\set QUIET off
SELECT n, CASE WHEN ok THEN 'OK ' ELSE 'FALLO' END AS estado, prueba, obtenido FROM resultado_pruebas ORDER BY n;
SELECT count(*) FILTER (WHERE ok) AS correctas, count(*) AS total FROM resultado_pruebas;

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM resultado_pruebas WHERE NOT ok) THEN
        RAISE EXCEPTION 'Hay pruebas que no se comportaron como se esperaba';
    END IF;
END
$$;
ROLLBACK;
