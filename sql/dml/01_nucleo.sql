-- DML 01: Nucleo - catalogos, hospitales y personas

INSERT INTO departamento (id_departamento, nombre) VALUES
    (1, 'Quetzaltenango'),
    (2, 'San Marcos'),
    (3, 'Huehuetenango'),
    (4, 'Retalhuleu'),
    (5, 'Totonicapan');
SELECT setval('departamento_id_departamento_seq', 5);

INSERT INTO municipio (id_municipio, id_departamento, nombre) VALUES
    (1, 1, 'Quetzaltenango'),
    (2, 1, 'Coatepeque'),
    (3, 2, 'San Marcos'),
    (4, 2, 'Malacatan'),
    (5, 3, 'Huehuetenango'),
    (6, 3, 'Jacaltenango'),
    (7, 4, 'Retalhuleu'),
    (8, 4, 'Champerico'),
    (9, 5, 'Totonicapan'),
    (10, 5, 'Momostenango');
SELECT setval('municipio_id_municipio_seq', 10);

-- Especialidades de Consulta Externa / Emergencias
INSERT INTO especialidad (id_especialidad, nombre, categoria) VALUES
    (1, 'Cardiologia', 'Consulta_Emergencia'),
    (2, 'Dermatologia', 'Consulta_Emergencia'),
    (3, 'Fisioterapia', 'Consulta_Emergencia'),
    (4, 'Ginecologia Oncologica', 'Consulta_Emergencia'),
    (5, 'Hematologia', 'Consulta_Emergencia'),
    (6, 'Medicina Fisica y Rehabilitacion', 'Consulta_Emergencia'),
    (7, 'Medicina General', 'Consulta_Emergencia'),
    (8, 'Nutricion y Dietetica', 'Consulta_Emergencia'),
    (9, 'Odontologia General', 'Consulta_Emergencia'),
    (10, 'Oftalmologia', 'Consulta_Emergencia'),
    (11, 'Psicologia', 'Consulta_Emergencia'),
    (12, 'Pediatria', 'Consulta_Emergencia'),
    (13, 'Urologia', 'Consulta_Emergencia'),
    (14, 'Terapia del Lenguaje', 'Consulta_Emergencia'),
-- Especialidades de Cirugia (14)
    (15, 'Cirugia Cardiovascular Adulto y Pediatrica', 'Cirugia'),
    (16, 'Cirugia de la Mano', 'Cirugia'),
    (17, 'Cirugia General', 'Cirugia'),
    (18, 'Videolaparoscopia Quirurgica', 'Cirugia'),
    (19, 'Cirugia Ginecologica', 'Cirugia'),
    (20, 'Cirugia Neurologica', 'Cirugia'),
    (21, 'Cirugia Oftalmologica', 'Cirugia'),
    (22, 'Cirugia Oncologica', 'Cirugia'),
    (23, 'Cirugia Ortopedica', 'Cirugia'),
    (24, 'Cirugia Otorrinolaringologica', 'Cirugia'),
    (25, 'Cirugia Pediatrica', 'Cirugia'),
    (26, 'Cirugia Plastica', 'Cirugia'),
    (27, 'Cirugia de Torax', 'Cirugia'),
    (28, 'Cirugia Urologica', 'Cirugia');
SELECT setval('especialidad_id_especialidad_seq', 28);

INSERT INTO hospital (id_hospital, nombre, direccion, id_municipio, telefono) VALUES
    (1, 'Hospital Regional de Occidente', '0 avenida 5-45, zona 1', 1, '77612345'),
    (2, 'Hospital Nacional de San Marcos', '4a calle 8-20, zona 3', 3, '77762210'),
    (3, 'Hospital Nacional de Huehuetenango', '2a avenida 3-15, zona 2', 5, '77641180');
SELECT setval('hospital_id_hospital_seq', 3);

INSERT INTO paciente (id_paciente, no_expediente, nombres, apellidos, sexo, fecha_nacimiento, id_municipio, area, dpi, telefono, no_seguro_social) VALUES
    (1, 'EXP-2026-0001', 'Maria', 'Xitumul Tzul', 'F', '1990-03-14', 1, 'Urbana', '1234567890101', '55123456', 'IGSS-880011'),
    (2, 'EXP-2026-0002', 'Jose Manuel', 'Garcia Lopez', 'M', '1975-11-02', 2, 'Rural', '2345678901202', '42198765', NULL),
    (3, 'EXP-2026-0003', 'Juana', 'Us Chocoj', 'F', '2003-07-22', 3, 'Rural', '3456789012303', '30456789', NULL),
    (4, 'EXP-2026-0004', 'Carlos Alberto', 'Morales Ramirez', 'M', '1988-05-30', 4, 'Urbana', '4567890123404', '51122334', 'IGSS-770234'),
    (5, 'EXP-2026-0005', 'Rosa Elvira', 'Tepaz Batz', 'F', '1965-01-09', 5, 'Urbana', '5678901234505', '77650099', 'IGSS-650098'),
    (6, 'EXP-2026-0006', 'Miguel Angel', 'De Leon Argueta', 'M', '1999-09-19', 6, 'Rural', '6789012345606', '48871122', NULL),
    (7, 'EXP-2026-0007', 'Ana Lucia', 'Marroquin Giron', 'F', '1980-12-25', 7, 'Urbana', '7890123456707', '33445566', 'IGSS-800456'),
    (8, 'EXP-2026-0008', 'Pedro', 'Cotzojay Ixcoy', 'M', '2010-02-14', 10, 'Rural', '8901234567808', '30112233', NULL);
SELECT setval('paciente_id_paciente_seq', 8);

INSERT INTO responsable_paciente (id_responsable, id_paciente, nombre, parentesco, dpi, telefono, id_municipio, area) VALUES
    (1, 8, 'Juana Ixcoy Batz', 'Madre', '9012345678909', '30112200', 10, 'Rural'),
    (2, 3, 'Domingo Us Sican', 'Padre', '0123456789010', '30456700', 3, 'Rural'),
    (3, 6, 'Elena Argueta Toc', 'Hermana', '1122334455667', '48870000', 6, 'Rural'),
    (4, 1, 'Fernando Xitumul Vail', 'Esposo', '2233445566778', '55123400', 1, 'Urbana');
SELECT setval('responsable_paciente_id_responsable_seq', 4);

INSERT INTO medico (id_medico, nombre, dpi, id_especialidad, tipo_medico, id_hospital, telefono, id_municipio, area) VALUES
    (1, 'Dr. Luis Fernando Sican Toc', '1111222233341', 7, 'Residente', 1, '77611001', 1, 'Urbana'),
    (2, 'Dra. Gabriela Marisol Cabrera Us', '2222333344452', 12, 'Residente', 1, '77611002', 1, 'Urbana'),
    (3, 'Dr. Edgar Rolando Velasquez Marroquin', '3333444455563', 1, 'Interno', 1, '77611003', NULL, NULL),
    (4, 'Dra. Silvia Patricia Xitumul Us', '4444555566674', 4, 'Residente', 2, '77762211', 3, 'Urbana'),
    (5, 'Dr. Mario Estuardo Chocoj Vail', '5555666677785', 7, 'Residente', 2, '77762212', 3, 'Urbana'),
    (6, 'Dr. Julio Cesar Argueta Giron', '6666777788896', 17, 'Residente', 1, '77611006', 1, 'Urbana'),
    (7, 'Dr. Byron Estuardo Giron Cotzojay', '7777888899907', 23, 'Externo', 1, '48870077', NULL, NULL),
    (8, 'Dr. Rigoberto Tepaz Chocoj', '8888999900018', 17, 'Interno', 1, '77611008', 1, 'Urbana'),
    (9, 'Dra. Claudia Beatriz Us Batz', '9999000011129', 7, 'Residente', 3, '77641181', 5, 'Urbana'),
    (10, 'Dra. Karla Beatriz Tzul Ixcoy', '0000111122230', 6, 'Residente', 1, '77611010', 1, 'Urbana');
SELECT setval('medico_id_medico_seq', 10);

INSERT INTO enfermero (id_enfermero, nombre, dpi, tipo_enfermero, id_hospital) VALUES
    (1, 'Marta Lidia Ixcoy Us', '1212121212121', 'Registrado', 1),
    (2, 'Jose Domingo Chocoj Tzul', '1313131313131', 'Practicante', 1),
    (3, 'Blanca Estela Vail Marroquin', '1414141414141', 'Registrado', 1),
    (4, 'Wilson Aroldo Giron Argueta', '1515151515151', 'Registrado', 2),
    (5, 'Petrona Us Cotzojay', '1616161616161', 'Practicante', 2),
    (6, 'Hugo Leonel Batz Sican', '1717171717171', 'Registrado', 3);
SELECT setval('enfermero_id_enfermero_seq', 6);

INSERT INTO personal_encargado (id_encargado, nombre, dpi, puesto, id_hospital, telefono) VALUES
    (1, 'Sofia Elizabeth Marroquin Toc', '2121212121212', 'Jefa de Recepcion', 1, '77611020'),
    (2, 'Ruben Alexander Us Giron', '2222222222223', 'Encargado de Admisiones', 1, '77611021'),
    (3, 'Deysi Marisol Chocoj Argueta', '2323232323232', 'Encargada de Facturacion', 2, '77762220'),
    (4, 'Anselmo Tzul Vail', '2424242424242', 'Coordinador de Turno', 3, '77641190');
SELECT setval('personal_encargado_id_encargado_seq', 4);
