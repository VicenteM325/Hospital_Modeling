-- =========================================================================
-- DML 03: Ingreso / Egreso / Traslado
-- Flujo 1: Jose Manuel (paciente 2) ingresa por Emergencias con dolor
--          abdominal, se traslada a Cirugia (apendicectomia) y luego a
--          Hospitalizacion para recuperacion, hasta su alta.
-- Flujo 2: Juana (paciente 3) ingresa por Emergencias con crisis asmatica
--          y es dada de alta directamente desde esa unidad.
-- Flujo 3: Rosa Elvira (paciente 5) ingresa de forma directa a
--          Hospitalizacion (neumonia) y permanece activa (sin egreso aun).
-- =========================================================================

INSERT INTO unidad_hospital (id_unidad_hospital, id_hospital, tipo_unidad) VALUES
    (1, 1, 'Emergencias'),
    (2, 1, 'Cirugia'),
    (3, 1, 'Hospitalizacion'),
    (4, 2, 'Emergencias'),
    (5, 2, 'Cirugia'),
    (6, 2, 'Hospitalizacion'),
    (7, 3, 'Emergencias'),
    (8, 3, 'Cirugia'),
    (9, 3, 'Hospitalizacion');
SELECT setval('unidad_hospital_id_unidad_hospital_seq', 9);

INSERT INTO camilla (id_camilla, id_unidad_hospital, numero, estado) VALUES
    (1, 1, 1, 'Ocupada'),
    (2, 1, 2, 'Libre'),
    (3, 3, 1, 'Ocupada'),
    (4, 3, 2, 'Ocupada'),
    (5, 6, 1, 'Libre'),
    (6, 4, 1, 'Ocupada');
SELECT setval('camilla_id_camilla_seq', 6);

-- Flujo 1: ingreso inicial por Emergencias
INSERT INTO ingreso (id_ingreso, id_paciente, id_unidad_hospital, id_medico, fecha_hora, motivo_ingreso, id_responsable, id_camilla, diagnostico_presuntivo) VALUES
    (1, 2, 1, 1, '2026-09-20 14:30', 'Dolor abdominal agudo de 12 horas de evolucion', NULL, 1, 'Apendicitis aguda probable');

-- Traslado de Emergencias a Cirugia
INSERT INTO traslado (id_traslado, id_paciente, id_medico_indica, fecha_hora, id_unidad_destino, interno_destino, id_unidad_origen, interno_origen) VALUES
    (1, 2, 1, '2026-09-20 15:00', 2, TRUE, 1, TRUE);

-- Egreso que cierra el paso por Emergencias (motivo: traslado a Cirugia)
INSERT INTO egreso (id_egreso, id_ingreso, id_medico, fecha_hora, diagnostico_principal, motivo_egreso, codigo_egreso, egreso_sin_consentimiento, motivo_sin_consentimiento, id_traslado, dias_hospitalizado, referido_otro_hospital) VALUES
    (1, 1, 1, '2026-09-20 15:00', 'Apendicitis aguda, requiere manejo quirurgico', 'Traslado a Cirugia', 'Vivo', FALSE, NULL, 1, 0, NULL);

-- Nuevo ingreso al entrar a la unidad de Cirugia (ficha de ingreso propia de la unidad)
INSERT INTO ingreso (id_ingreso, id_paciente, id_unidad_hospital, id_medico, fecha_hora, motivo_ingreso, id_responsable, id_camilla, diagnostico_presuntivo) VALUES
    (2, 2, 2, 6, '2026-09-20 16:00', 'Intervencion quirurgica: apendicectomia', NULL, NULL, 'Apendicitis aguda');

-- Traslado de Cirugia a Hospitalizacion (sala de recuperacion)
INSERT INTO traslado (id_traslado, id_paciente, id_medico_indica, fecha_hora, id_unidad_destino, interno_destino, id_unidad_origen, interno_origen) VALUES
    (2, 2, 6, '2026-09-20 19:00', 3, TRUE, 2, TRUE);

-- Egreso que cierra el paso por Cirugia (motivo: traslado a Hospitalizacion)
INSERT INTO egreso (id_egreso, id_ingreso, id_medico, fecha_hora, diagnostico_principal, motivo_egreso, codigo_egreso, egreso_sin_consentimiento, motivo_sin_consentimiento, id_traslado, dias_hospitalizado, referido_otro_hospital) VALUES
    (2, 2, 6, '2026-09-20 19:00', 'Apendicitis aguda resuelta quirurgicamente', 'Traslado a Hospitalizacion para recuperacion postoperatoria', 'Vivo', FALSE, NULL, 2, NULL, NULL);

-- Nuevo ingreso al entrar a Hospitalizacion (continuacion del mismo caso)
INSERT INTO ingreso (id_ingreso, id_paciente, id_unidad_hospital, id_medico, fecha_hora, motivo_ingreso, id_responsable, id_camilla, diagnostico_presuntivo) VALUES
    (3, 2, 3, 1, '2026-09-20 19:15', 'Recuperacion postoperatoria de apendicectomia', NULL, 3, 'Postoperatorio de apendicectomia');

-- Egreso final: alta medica
INSERT INTO egreso (id_egreso, id_ingreso, id_medico, fecha_hora, diagnostico_principal, motivo_egreso, codigo_egreso, egreso_sin_consentimiento, motivo_sin_consentimiento, id_traslado, dias_hospitalizado, referido_otro_hospital) VALUES
    (3, 3, 1, '2026-09-22 10:00', 'Postoperatorio de apendicectomia sin complicaciones', 'Alta medica por mejoria', 'Vivo', FALSE, NULL, NULL, 2, NULL);

INSERT INTO diagnostico_secundario (id_diagnostico_secundario, id_egreso, descripcion) VALUES
    (1, 3, 'Deshidratacion leve resuelta con hidratacion intravenosa');

-- Flujo 2: emergencia que se resuelve sin traslado
INSERT INTO ingreso (id_ingreso, id_paciente, id_unidad_hospital, id_medico, fecha_hora, motivo_ingreso, id_responsable, id_camilla, diagnostico_presuntivo) VALUES
    (4, 3, 4, 5, '2026-09-24 22:00', 'Crisis asmatica', 2, 6, 'Crisis asmatica moderada');

INSERT INTO egreso (id_egreso, id_ingreso, id_medico, fecha_hora, diagnostico_principal, motivo_egreso, codigo_egreso, egreso_sin_consentimiento, motivo_sin_consentimiento, id_traslado, dias_hospitalizado, referido_otro_hospital) VALUES
    (4, 4, 5, '2026-09-25 01:30', 'Crisis asmatica resuelta', 'Alta por mejoria tras nebulizacion', 'Vivo', FALSE, NULL, NULL, 0, NULL);

-- Flujo 3: ingreso directo a Hospitalizacion, caso activo (sin egreso todavia)
INSERT INTO ingreso (id_ingreso, id_paciente, id_unidad_hospital, id_medico, fecha_hora, motivo_ingreso, id_responsable, id_camilla, diagnostico_presuntivo) VALUES
    (5, 5, 3, 1, '2026-09-23 09:00', 'Neumonia adquirida en la comunidad', NULL, 4, 'Neumonia bacteriana');

SELECT setval('traslado_id_traslado_seq', 2);
SELECT setval('ingreso_id_ingreso_seq', 5);
SELECT setval('egreso_id_egreso_seq', 4);
SELECT setval('diagnostico_secundario_id_diagnostico_secundario_seq', 1);
