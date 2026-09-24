-- =========================================================================
-- DML 02: Consulta Externa
-- =========================================================================

INSERT INTO cita_programada (id_cita, id_paciente, id_medico, fecha, hora, estado, consultorio) VALUES
    (1, 1, 1, '2026-09-10', '08:00', 'Realizada', 'Clinica 3'),
    (2, 4, 3, '2026-09-15', '09:30', 'Realizada', 'Clinica 5'),
    (3, 8, 2, '2026-09-30', '10:00', 'Programada', 'Clinica 2'),
    (4, 5, 1, '2026-09-12', '11:00', 'Cancelada', 'Clinica 3');
SELECT setval('cita_programada_id_cita_seq', 4);

INSERT INTO consulta_paciente (id_consulta, id_paciente, id_medico, fecha, tipo_consulta, referido_institucion, id_cita, diagnostico, notas) VALUES
    (1, 1, 1, '2026-09-10', 'Primera', FALSE, 1, 'Rinofaringitis aguda', 'Se indica reposo e hidratacion abundante'),
    (2, 4, 3, '2026-09-15', 'Reconsulta', FALSE, 2, 'Hipertension arterial controlada', 'Continuar tratamiento, proxima cita en un mes'),
    (3, 7, 4, '2026-09-18', 'Primera', TRUE, NULL, 'Control ginecologico de rutina', 'Paciente referida del Centro de Salud de Retalhuleu');
SELECT setval('consulta_paciente_id_consulta_seq', 3);

INSERT INTO receta_medica (id_receta, id_consulta, fecha, id_hospital, proxima_cita, numero_clinica) VALUES
    (1, 1, '2026-09-10', 1, '2026-10-10', '3'),
    (2, 2, '2026-09-15', 1, '2026-11-15', '5');
SELECT setval('receta_medica_id_receta_seq', 2);

INSERT INTO medicamento_recetado (id_medicamento_recetado, id_receta, nombre, dosis, duracion) VALUES
    (1, 1, 'Paracetamol', '500 mg cada 6 horas', '5 dias'),
    (2, 1, 'Loratadina', '10 mg cada dia', '5 dias'),
    (3, 2, 'Losartan', '50 mg cada dia', '30 dias');
SELECT setval('medicamento_recetado_id_medicamento_recetado_seq', 3);
