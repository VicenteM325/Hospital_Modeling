-- Ampliacion del nucleo - hospitales, infraestructura, personal con jerarquia y pacientes
-- Datos FICTICIOS generados con proyecto-2/scripts/generar_datos_prueba.py (semilla fija).
-- Continua los IDs del Proyecto 1. Ejecutar como usr_admin_bd despues de las migraciones DDL.

SET ROLE rol_administrador;
BEGIN;

-- Dos hospitales nuevos para que los rankings de los objetivos tengan sentido (5 en total)
INSERT INTO hospital (id_hospital, nombre, direccion, id_municipio, telefono) VALUES
    (4, 'Hospital Nacional de Retalhuleu', '5a avenida 2-30, zona 1', 7, '77711400'),
    (5, 'Hospital Nacional de Totonicapan', '3a calle 4-15, zona 2', 9, '77661250');

-- Unidades medicas de los hospitales nuevos (ids 10-15)
INSERT INTO unidad_hospital (id_unidad_hospital, id_hospital, tipo_unidad) VALUES
    (10, 4, 'Emergencias'),
    (11, 4, 'Cirugia'),
    (12, 4, 'Hospitalizacion'),
    (13, 5, 'Emergencias'),
    (14, 5, 'Cirugia'),
    (15, 5, 'Hospitalizacion');

-- Camillas hasta completar 4 por unidad de Emergencias y de Hospitalizacion
INSERT INTO camilla (id_camilla, id_unidad_hospital, numero, estado) VALUES
    (7, 1, 3, 'Libre'),
    (8, 1, 4, 'Libre'),
    (9, 3, 3, 'Libre'),
    (10, 3, 4, 'Libre'),
    (11, 4, 2, 'Libre'),
    (12, 4, 3, 'Libre'),
    (13, 4, 4, 'Libre'),
    (14, 6, 2, 'Libre'),
    (15, 6, 3, 'Libre'),
    (16, 6, 4, 'Libre'),
    (17, 7, 1, 'Libre'),
    (18, 7, 2, 'Libre'),
    (19, 7, 3, 'Libre'),
    (20, 7, 4, 'Libre'),
    (21, 9, 1, 'Libre'),
    (22, 9, 2, 'Libre'),
    (23, 9, 3, 'Libre'),
    (24, 9, 4, 'Libre'),
    (25, 10, 1, 'Libre'),
    (26, 10, 2, 'Libre'),
    (27, 10, 3, 'Libre'),
    (28, 10, 4, 'Libre'),
    (29, 12, 1, 'Libre'),
    (30, 12, 2, 'Libre'),
    (31, 12, 3, 'Libre'),
    (32, 12, 4, 'Libre'),
    (33, 13, 1, 'Libre'),
    (34, 13, 2, 'Libre'),
    (35, 13, 3, 'Libre'),
    (36, 13, 4, 'Libre'),
    (37, 15, 1, 'Libre'),
    (38, 15, 2, 'Libre'),
    (39, 15, 3, 'Libre'),
    (40, 15, 4, 'Libre');

-- Quirofanos para los hospitales que no tenian (P1: ids 1-3)
INSERT INTO quirofano (id_quirofano, id_hospital, numero, estado) VALUES
    (4, 2, 2, 'Libre'),
    (5, 3, 1, 'Libre'),
    (6, 3, 2, 'Libre'),
    (7, 4, 1, 'Libre'),
    (8, 4, 2, 'Libre'),
    (9, 5, 1, 'Libre'),
    (10, 5, 2, 'Libre');

-- Jerarquia de los medicos del Proyecto 1: Director -> Jefes de Servicio -> medicos
UPDATE medico SET cargo = 'Jefe de Servicio', id_supervisor = 1 WHERE id_medico IN (2, 6);
UPDATE medico SET id_supervisor = 2 WHERE id_medico IN (3, 10);
UPDATE medico SET id_supervisor = 6 WHERE id_medico IN (7, 8);
UPDATE medico SET cargo = 'Jefe de Servicio', id_supervisor = 4 WHERE id_medico = 5;

-- Salario y nivel de acceso de los 10 medicos del Proyecto 1 (datos que audita el objetivo 20)
UPDATE medico SET salario = v.salario, nivel_acceso = v.acceso
FROM (VALUES
    (1, 18500, 'Administrador'),
    (2, 15300, 'Avanzado'),
    (3, 10100, 'Intermedio'),
    (4, 21900, 'Administrador'),
    (5, 16100, 'Avanzado'),
    (6, 16600, 'Avanzado'),
    (7, 11500, 'Basico'),
    (8, 11900, 'Intermedio'),
    (9, 18400, 'Administrador'),
    (10, 11600, 'Intermedio')
) AS v(id, salario, acceso) WHERE medico.id_medico = v.id;

-- Supertipo PERSONAL: 22 medicos, 9 enfermeros y 11 encargados nuevos (ids 21-62)
INSERT INTO personal (id_personal, tipo_personal, nombre, dpi, fecha_contratacion, telefono, direccion) VALUES
    (21, 'Medico', 'Dra. Gloria Julia Giron Morales', '3000000000021', '2024-02-01', '50000021', '4 calle 10-77, zona 4, Quetzaltenango'),
    (22, 'Medico', 'Dr. Luis Miguel Morales Velasquez', '3000000000022', '2014-04-05', '50000022', '5 avenida 11-84, zona 5, San Marcos'),
    (23, 'Medico', 'Dra. Sofia Marta Garcia Xitumul', '3000000000023', '2024-12-30', '50000023', '6 calle 12-11, zona 6, San Marcos'),
    (24, 'Medico', 'Dr. Andres Jorge Cabrera Ixcoy', '3000000000024', '2021-01-18', '50000024', '7 avenida 1-18, zona 1, San Marcos'),
    (25, 'Medico', 'Dra. Carmen Ana Alvarado Marroquin', '3000000000025', '2018-09-19', '50000025', '8 calle 2-25, zona 2, San Marcos'),
    (26, 'Medico', 'Dr. Hugo Oscar Us Lopez', '3000000000026', '2022-11-29', '50000026', '9 avenida 3-32, zona 3, Huehuetenango'),
    (27, 'Medico', 'Dra. Rosa Lucia Ixcoy Cabrera', '3000000000027', '2019-08-23', '50000027', '1 calle 4-39, zona 4, Huehuetenango'),
    (28, 'Medico', 'Dr. Mario Raul Vail Tzul', '3000000000028', '2021-10-19', '50000028', '2 avenida 5-46, zona 5, Huehuetenango'),
    (29, 'Medico', 'Dra. Maria Elena Giron Sican', '3000000000029', '2021-12-31', '50000029', '3 calle 6-53, zona 6, Huehuetenango'),
    (30, 'Medico', 'Dr. Juan Jose Morales Giron', '3000000000030', '2022-06-11', '50000030', '4 avenida 7-60, zona 1, Huehuetenango'),
    (31, 'Medico', 'Dra. Teresa Patricia Garcia Ramirez', '3000000000031', '2025-07-09', '50000031', '5 calle 8-67, zona 2, Retalhuleu'),
    (32, 'Medico', 'Dr. Pedro Carlos Cabrera Perez', '3000000000032', '2015-09-18', '50000032', '6 avenida 9-74, zona 3, Retalhuleu'),
    (33, 'Medico', 'Dra. Gloria Julia Alvarado Us', '3000000000033', '2021-08-20', '50000033', '7 calle 10-81, zona 4, Retalhuleu'),
    (34, 'Medico', 'Dr. Luis Miguel Us Toc', '3000000000034', '2016-01-05', '50000034', '8 avenida 11-88, zona 5, Retalhuleu'),
    (35, 'Medico', 'Dra. Sofia Marta Ixcoy Tepaz', '3000000000035', '2026-07-03', '50000035', '9 calle 12-15, zona 6, Retalhuleu'),
    (36, 'Medico', 'Dr. Andres Jorge Vail Garcia', '3000000000036', '2026-01-25', '50000036', '1 avenida 1-22, zona 1, Retalhuleu'),
    (37, 'Medico', 'Dra. Carmen Ana Giron Mendez', '3000000000037', '2020-07-21', '50000037', '2 calle 2-29, zona 2, Totonicapan'),
    (38, 'Medico', 'Dr. Hugo Oscar Morales Chocoj', '3000000000038', '2020-06-14', '50000038', '3 avenida 3-36, zona 3, Totonicapan'),
    (39, 'Medico', 'Dra. Rosa Lucia Garcia Vail', '3000000000039', '2024-04-05', '50000039', '4 calle 4-43, zona 4, Totonicapan'),
    (40, 'Medico', 'Dr. Mario Raul Cabrera Argueta', '3000000000040', '2017-02-28', '50000040', '5 avenida 5-50, zona 5, Totonicapan'),
    (41, 'Medico', 'Dra. Maria Elena Alvarado De Leon', '3000000000041', '2020-12-06', '50000041', '6 calle 6-57, zona 6, Totonicapan'),
    (42, 'Medico', 'Dr. Juan Jose Us Alvarado', '3000000000042', '2014-07-22', '50000042', '7 avenida 7-64, zona 1, Totonicapan'),
    (43, 'Enfermero', 'Gloria Julia Alvarado Us', '3000000000043', '2025-07-04', NULL, '8 calle 8-71, zona 2, Quetzaltenango'),
    (44, 'Enfermero', 'Ana Carmen Us Toc', '3000000000044', '2023-12-21', NULL, '9 avenida 9-78, zona 3, San Marcos'),
    (45, 'Enfermero', 'Jorge Andres Ixcoy Tepaz', '3000000000045', '2020-02-19', NULL, '1 calle 10-85, zona 4, San Marcos'),
    (46, 'Enfermero', 'Marta Sofia Vail Garcia', '3000000000046', '2020-01-29', NULL, '2 avenida 11-12, zona 5, Huehuetenango'),
    (47, 'Enfermero', 'Carmen Ana Giron Mendez', '3000000000047', '2021-03-03', NULL, '3 calle 12-19, zona 6, Huehuetenango'),
    (48, 'Enfermero', 'Hugo Oscar Morales Chocoj', '3000000000048', '2020-09-25', NULL, '4 avenida 1-26, zona 1, Retalhuleu'),
    (49, 'Enfermero', 'Rosa Lucia Garcia Vail', '3000000000049', '2017-01-06', NULL, '5 calle 2-33, zona 2, Retalhuleu'),
    (50, 'Enfermero', 'Patricia Teresa Cabrera Argueta', '3000000000050', '2020-06-21', NULL, '6 avenida 3-40, zona 3, Totonicapan'),
    (51, 'Enfermero', 'Jose Juan Alvarado De Leon', '3000000000051', '2025-12-28', NULL, '7 calle 4-47, zona 4, Totonicapan'),
    (52, 'Encargado', 'Carmen Ana Giron Mendez', '3000000000052', '2022-07-27', '50000052', '8 avenida 5-54, zona 5, Quetzaltenango'),
    (53, 'Encargado', 'Hugo Oscar Morales Chocoj', '3000000000053', '2022-03-21', '50000053', '9 calle 6-61, zona 6, San Marcos'),
    (54, 'Encargado', 'Rosa Lucia Garcia Vail', '3000000000054', '2021-08-03', '50000054', '1 avenida 7-68, zona 1, San Marcos'),
    (55, 'Encargado', 'Mario Raul Cabrera Argueta', '3000000000055', '2025-09-22', '50000055', '2 calle 8-75, zona 2, Huehuetenango'),
    (56, 'Encargado', 'Maria Elena Alvarado De Leon', '3000000000056', '2017-04-21', '50000056', '3 avenida 9-82, zona 3, Huehuetenango'),
    (57, 'Encargado', 'Juan Jose Us Alvarado', '3000000000057', '2020-10-08', '50000057', '4 calle 10-89, zona 4, Retalhuleu'),
    (58, 'Encargado', 'Teresa Patricia Ixcoy Batz', '3000000000058', '2021-09-05', '50000058', '5 avenida 11-16, zona 5, Retalhuleu'),
    (59, 'Encargado', 'Pedro Carlos Vail Cotzojay', '3000000000059', '2024-12-31', '50000059', '6 calle 12-23, zona 6, Retalhuleu'),
    (60, 'Encargado', 'Gloria Julia Giron Morales', '3000000000060', '2024-05-30', '50000060', '7 avenida 1-30, zona 1, Totonicapan'),
    (61, 'Encargado', 'Luis Miguel Morales Velasquez', '3000000000061', '2025-09-20', '50000061', '8 calle 2-37, zona 2, Totonicapan'),
    (62, 'Encargado', 'Sofia Marta Garcia Xitumul', '3000000000062', '2022-09-24', '50000062', '9 avenida 3-44, zona 3, Totonicapan');

SELECT setval(pg_get_serial_sequence('personal', 'id_personal'), (SELECT MAX(id_personal) FROM personal));

-- Subtipo MEDICO (ids 11-32). Un supervisor se inserta antes que sus subordinados
INSERT INTO medico (id_medico, id_personal, id_especialidad, tipo_medico, id_hospital, cargo, id_supervisor, salario, nivel_acceso, id_municipio, area) VALUES
    (11, 21, 1, 'Residente', 1, 'Medico', 3, 8900, 'Intermedio', 1, 'Urbana'),
    (12, 22, 12, 'Residente', 2, 'Jefe de Servicio', 4, 16500, 'Avanzado', 3, 'Urbana'),
    (13, 23, 17, 'Interno', 2, 'Jefe de Servicio', 4, 16500, 'Avanzado', 3, 'Urbana'),
    (14, 24, 7, 'Residente', 2, 'Medico', 12, 10300, 'Basico', 3, 'Urbana'),
    (15, 25, 1, 'Residente', 2, 'Medico', 12, 9700, 'Intermedio', 3, 'Urbana'),
    (16, 26, 12, 'Residente', 3, 'Jefe de Servicio', 9, 16300, 'Avanzado', 5, 'Urbana'),
    (17, 27, 17, 'Interno', 3, 'Jefe de Servicio', 9, 16200, 'Avanzado', 5, 'Urbana'),
    (18, 28, 7, 'Residente', 3, 'Medico', 16, 11400, 'Intermedio', 5, 'Urbana'),
    (19, 29, 23, 'Externo', 3, 'Medico', 17, 11000, 'Intermedio', 5, 'Urbana'),
    (20, 30, 1, 'Residente', 3, 'Medico', 16, 11200, 'Intermedio', 5, 'Urbana'),
    (21, 31, 7, 'Residente', 4, 'Director Medico', NULL, 21100, 'Administrador', 7, 'Urbana'),
    (22, 32, 12, 'Residente', 4, 'Jefe de Servicio', 21, 16000, 'Avanzado', 7, 'Urbana'),
    (23, 33, 17, 'Interno', 4, 'Jefe de Servicio', 21, 16400, 'Avanzado', 7, 'Urbana'),
    (24, 34, 7, 'Residente', 4, 'Medico', 22, 9800, 'Intermedio', 7, 'Urbana'),
    (25, 35, 1, 'Residente', 4, 'Medico', 22, 9000, 'Intermedio', 7, 'Urbana'),
    (26, 36, 18, 'Externo', 4, 'Medico', 23, 8000, 'Intermedio', 7, 'Urbana'),
    (27, 37, 7, 'Residente', 5, 'Director Medico', NULL, 20500, 'Administrador', 9, 'Urbana'),
    (28, 38, 12, 'Residente', 5, 'Jefe de Servicio', 27, 14300, 'Basico', 9, 'Urbana'),
    (29, 39, 17, 'Interno', 5, 'Jefe de Servicio', 27, 14500, 'Avanzado', 9, 'Urbana'),
    (30, 40, 7, 'Residente', 5, 'Medico', 28, 9200, 'Intermedio', 9, 'Urbana'),
    (31, 41, 1, 'Residente', 5, 'Medico', 28, 11300, 'Intermedio', 9, 'Urbana'),
    (32, 42, 23, 'Externo', 5, 'Medico', 29, 8400, 'Intermedio', 9, 'Urbana');

SELECT setval(pg_get_serial_sequence('medico', 'id_medico'), (SELECT MAX(id_medico) FROM medico));

-- Subtipo ENFERMERO (ids 7-15)
INSERT INTO enfermero (id_enfermero, id_personal, tipo_enfermero, id_hospital, numero_colegiado) VALUES
    (7, 43, 'Registrado', 1, 'ENF-3007'),
    (8, 44, 'Practicante', 2, NULL),
    (9, 45, 'Registrado', 2, 'ENF-3009'),
    (10, 46, 'Practicante', 3, NULL),
    (11, 47, 'Registrado', 3, 'ENF-3011'),
    (12, 48, 'Practicante', 4, NULL),
    (13, 49, 'Registrado', 4, 'ENF-3013'),
    (14, 50, 'Practicante', 5, NULL),
    (15, 51, 'Registrado', 5, 'ENF-3015');

SELECT setval(pg_get_serial_sequence('enfermero', 'id_enfermero'), (SELECT MAX(id_enfermero) FROM enfermero));

-- Subtipo PERSONAL_ENCARGADO (ids 5-15)
INSERT INTO personal_encargado (id_encargado, id_personal, puesto, id_hospital, telefono) VALUES
    (5, 52, 'Recepcion', 1, '50000052'),
    (6, 53, 'Admisiones', 2, '50000053'),
    (7, 54, 'Facturacion', 2, '50000054'),
    (8, 55, 'Archivo Clinico', 3, '50000055'),
    (9, 56, 'Trabajo Social', 3, '50000056'),
    (10, 57, 'Coordinador de Turno', 4, '50000057'),
    (11, 58, 'Recepcion', 4, '50000058'),
    (12, 59, 'Admisiones', 4, '50000059'),
    (13, 60, 'Facturacion', 5, '50000060'),
    (14, 61, 'Archivo Clinico', 5, '50000061'),
    (15, 62, 'Trabajo Social', 5, '50000062');

SELECT setval(pg_get_serial_sequence('personal_encargado', 'id_encargado'), (SELECT MAX(id_encargado) FROM personal_encargado));

-- El DDL asigno la fecha de corte 2026-01-01 al personal del Proyecto 1: se reemplaza por fechas ficticias y se agrega la direccion
UPDATE personal SET fecha_contratacion = v.fecha::date, direccion = v.direccion FROM (VALUES
    (1, '2023-01-05', '2 calle 2-17, zona 2, Quetzaltenango'),
    (2, '2020-12-05', '3 avenida 3-24, zona 3, Quetzaltenango'),
    (3, '2023-10-07', '4 calle 4-31, zona 4, Quetzaltenango'),
    (4, '2017-10-19', '5 avenida 5-38, zona 5, San Marcos'),
    (5, '2021-06-02', '6 calle 6-45, zona 6, San Marcos'),
    (6, '2024-08-25', '7 avenida 7-52, zona 1, Quetzaltenango'),
    (7, '2022-09-30', '8 calle 8-59, zona 2, Quetzaltenango'),
    (8, '2023-07-04', '9 avenida 9-66, zona 3, Quetzaltenango'),
    (9, '2023-08-14', '1 calle 10-73, zona 4, Huehuetenango'),
    (10, '2012-07-26', '2 avenida 11-80, zona 5, Quetzaltenango'),
    (11, '2024-11-27', '3 calle 12-87, zona 6, San Marcos'),
    (12, '2017-01-13', '4 avenida 1-14, zona 1, Huehuetenango'),
    (13, '2014-11-22', '5 calle 2-21, zona 2, Retalhuleu'),
    (14, '2013-02-04', '6 avenida 3-28, zona 3, Totonicapan'),
    (15, '2023-09-26', '7 calle 4-35, zona 4, Quetzaltenango'),
    (16, '2014-04-20', '8 avenida 5-42, zona 5, San Marcos'),
    (17, '2025-12-15', '9 calle 6-49, zona 6, Huehuetenango'),
    (18, '2021-08-18', '1 avenida 7-56, zona 1, Retalhuleu'),
    (19, '2022-07-17', '2 calle 8-63, zona 2, Totonicapan'),
    (20, '2015-03-12', '3 avenida 9-70, zona 3, Quetzaltenango')
) AS v(id, fecha, direccion) WHERE personal.id_personal = v.id;

-- 22 pacientes ficticios (ids 9-30): menores sin DPI, adultos de 1948 a 2001
INSERT INTO paciente (id_paciente, no_expediente, nombres, apellidos, sexo, fecha_nacimiento, id_municipio, area, dpi, telefono, no_seguro_social) VALUES
    (9, 'EXP-2026-0009', 'Teresa Patricia', 'Ixcoy Batz', 'F', '2019-10-16', 8, 'Rural', NULL, '30000009', 'IGSS-900153'),
    (10, 'EXP-2026-0010', 'Pedro Carlos', 'Vail Cotzojay', 'M', '1952-03-27', 1, 'Urbana', '4000000000010', '30000010', NULL),
    (11, 'EXP-2026-0011', 'Gloria Julia', 'Giron Morales', 'F', '1987-08-10', 4, 'Rural', '4000000000011', '30000011', NULL),
    (12, 'EXP-2026-0012', 'Luis Miguel', 'Morales Velasquez', 'M', '1994-01-21', 7, 'Rural', '4000000000012', '30000012', 'IGSS-900204'),
    (13, 'EXP-2026-0013', 'Sofia Marta', 'Garcia Xitumul', 'F', '2008-06-04', 10, 'Rural', NULL, '30000013', NULL),
    (14, 'EXP-2026-0014', 'Andres Jorge', 'Cabrera Ixcoy', 'M', '1976-11-15', 3, 'Urbana', '4000000000014', '30000014', NULL),
    (15, 'EXP-2026-0015', 'Carmen Ana', 'Alvarado Marroquin', 'F', '1961-04-26', 6, 'Rural', '4000000000015', '30000015', 'IGSS-900255'),
    (16, 'EXP-2026-0016', 'Hugo Oscar', 'Us Lopez', 'M', '2001-09-09', 9, 'Rural', '4000000000016', '30000016', NULL),
    (17, 'EXP-2026-0017', 'Rosa Lucia', 'Ixcoy Cabrera', 'F', '1983-02-20', 2, 'Rural', '4000000000017', '30000017', NULL),
    (18, 'EXP-2026-0018', 'Mario Raul', 'Vail Tzul', 'M', '1999-07-03', 5, 'Urbana', '4000000000018', '30000018', 'IGSS-900306'),
    (19, 'EXP-2026-0019', 'Maria Elena', 'Giron Sican', 'F', '2015-12-14', 8, 'Rural', NULL, '30000019', NULL),
    (20, 'EXP-2026-0020', 'Juan Jose', 'Morales Giron', 'M', '1948-05-25', 1, 'Rural', '4000000000020', '30000020', NULL),
    (21, 'EXP-2026-0021', 'Teresa Patricia', 'Garcia Ramirez', 'F', '1970-10-08', 4, 'Rural', '4000000000021', '30000021', 'IGSS-900357'),
    (22, 'EXP-2026-0022', 'Pedro Carlos', 'Cabrera Perez', 'M', '1991-03-19', 7, 'Urbana', '4000000000022', '30000022', NULL),
    (23, 'EXP-2026-0023', 'Gloria Julia', 'Alvarado Us', 'F', '1980-08-02', 10, 'Rural', '4000000000023', '30000023', NULL),
    (24, 'EXP-2026-0024', 'Luis Miguel', 'Us Toc', 'M', '2022-01-13', 3, 'Rural', NULL, '30000024', 'IGSS-900408'),
    (25, 'EXP-2026-0025', 'Sofia Marta', 'Ixcoy Tepaz', 'F', '1958-06-24', 6, 'Rural', '4000000000025', '30000025', NULL),
    (26, 'EXP-2026-0026', 'Andres Jorge', 'Vail Garcia', 'M', '1996-11-07', 9, 'Urbana', '4000000000026', '30000026', NULL),
    (27, 'EXP-2026-0027', 'Carmen Ana', 'Giron Mendez', 'F', '1973-04-18', 2, 'Rural', '4000000000027', '30000027', 'IGSS-900459'),
    (28, 'EXP-2026-0028', 'Hugo Oscar', 'Morales Chocoj', 'M', '2005-09-01', 5, 'Rural', '4000000000028', '30000028', NULL),
    (29, 'EXP-2026-0029', 'Rosa Lucia', 'Garcia Vail', 'F', '1985-02-12', 8, 'Rural', '4000000000029', '30000029', NULL),
    (30, 'EXP-2026-0030', 'Mario Raul', 'Cabrera Argueta', 'M', '1967-07-23', 1, 'Urbana', '4000000000030', '30000030', 'IGSS-900510');

SELECT setval(pg_get_serial_sequence('paciente', 'id_paciente'), (SELECT MAX(id_paciente) FROM paciente));

-- Responsables de los pacientes menores de edad (ids 5-8)
INSERT INTO responsable_paciente (id_responsable, id_paciente, nombre, parentesco, dpi, telefono, id_municipio, area) VALUES
    (5, 9, 'Carmen Ana Giron Mendez', 'Madre', '5000000000009', '30000009', 8, 'Rural'),
    (6, 13, 'Jose Juan Alvarado De Leon', 'Padre', '5000000000013', '30000013', 10, 'Rural'),
    (7, 19, 'Sofia Marta Garcia Xitumul', 'Madre', '5000000000019', '30000019', 8, 'Rural'),
    (8, 24, 'Mario Raul Vail Tzul', 'Padre', '5000000000024', '30000024', 3, 'Rural');

SELECT setval(pg_get_serial_sequence('responsable_paciente', 'id_responsable'), (SELECT MAX(id_responsable) FROM responsable_paciente));

COMMIT;
