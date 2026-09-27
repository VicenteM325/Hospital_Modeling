-- =========================================================================
-- DML 05: Hospitalizacion, Facturacion y Calificaciones
-- =========================================================================

INSERT INTO servicio_hospitalizacion (id_servicio, nombre) VALUES
    (1, 'Hematologia'),
    (2, 'Medicina interna'),
    (3, 'Neumologia'),
    (4, 'Oncologia'),
    (5, 'Ortopedia'),
    (6, 'Pediatria'),
    (7, 'Unidad de cuidados intermedios'),
    (8, 'Unidad de cuidado critico de adultos');
SELECT setval('servicio_hospitalizacion_id_servicio_seq', 8);

-- Recuperacion post-quirurgica de Jose Manuel (ingreso 3, unidad de Hospitalizacion)
INSERT INTO hospitalizacion_detalle (id_hospitalizacion_detalle, id_ingreso, id_servicio, id_camilla, costo_dia, dias) VALUES
    (1, 3, 7, 3, 350.00, 2);

-- Hospitalizacion activa de Rosa Elvira por neumonia (ingreso 5, aun sin egreso)
INSERT INTO hospitalizacion_detalle (id_hospitalizacion_detalle, id_ingreso, id_servicio, id_camilla, costo_dia, dias) VALUES
    (2, 5, 3, 4, 300.00, NULL);
SELECT setval('hospitalizacion_detalle_id_hospitalizacion_detalle_seq', 2);

INSERT INTO factura (id_factura, id_hospital, id_paciente, fecha, descripcion, monto, id_consulta, id_ingreso) VALUES
    (1, 1, 1, '2026-09-10', 'Consulta externa de Medicina General - primera consulta', 150.00, 1, NULL),
    (2, 1, 2, '2026-09-22', 'Atencion de emergencia, cirugia de apendicectomia y hospitalizacion asociada', 12500.00, NULL, 1),
    (3, 2, 3, '2026-09-25', 'Atencion de emergencia por crisis asmatica', 800.00, NULL, 4);
SELECT setval('factura_id_factura_seq', 3);

INSERT INTO cuota (id_cuota, id_factura, numero_cuota, monto, fecha_pago) VALUES
    (1, 1, 1, 150.00, '2026-09-10'),
    (2, 2, 1, 4166.67, '2026-09-22'),
    (3, 2, 2, 4166.67, '2026-10-22'),
    (4, 2, 3, 4166.66, NULL),
    (5, 3, 1, 800.00, '2026-09-25');
SELECT setval('cuota_id_cuota_seq', 5);

INSERT INTO calificacion_hospital (id_calificacion, id_hospital, puntaje, fecha, id_paciente, comentario) VALUES
    (1, 1, 5, '2026-09-23', 2, 'Excelente atencion durante la cirugia de emergencia');
SELECT setval('calificacion_hospital_id_calificacion_seq', 1);

INSERT INTO calificacion_medico (id_calificacion, id_medico, puntaje, fecha, id_paciente, comentario) VALUES
    (1, 6, 5, '2026-09-23', 2, 'El cirujano explico todo el procedimiento con claridad');
SELECT setval('calificacion_medico_id_calificacion_seq', 1);

INSERT INTO calificacion_enfermero (id_calificacion, id_enfermero, puntaje, fecha, id_paciente, comentario) VALUES
    (1, 1, 4, '2026-09-23', 2, 'Muy atenta durante la recuperacion postoperatoria');
SELECT setval('calificacion_enfermero_id_calificacion_seq', 1);

INSERT INTO calificacion_personal_encargado (id_calificacion, id_encargado, puntaje, fecha, id_paciente, comentario) VALUES
    (1, 1, 4, '2026-09-10', 1, 'Buena atencion en la recepcion del hospital');
SELECT setval('calificacion_personal_encargado_id_calificacion_seq', 1);
