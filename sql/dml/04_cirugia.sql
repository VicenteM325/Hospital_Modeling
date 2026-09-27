-- DML 04: Cirugia
-- Cirugia 1: apendicectomia aprobada y realizada a Jose Manuel (paciente 2).
-- Solicitud 2: artroscopia RECHAZADA para Ana Lucia (paciente 7), demuestra
--              la "base de cirugias rechazadas".

INSERT INTO insumo (id_insumo, nombre, material, tipo, descripcion) VALUES
    (1, 'Gasas esteriles', 'Textil', 'Quirurgico', 'Paquete de gasas esteriles para cirugia'),
    (2, 'Suero fisiologico 0.9%', 'Liquido', 'Medico', 'Solucion salina para hidratacion e irrigacion'),
    (3, 'Sutura Vicryl 2-0', 'Sintetico', 'Quirurgico', 'Sutura absorbible'),
    (4, 'Guantes esteriles', 'Latex', 'Medico', 'Guantes quirurgicos esteriles'),
    (5, 'Anestesico local Lidocaina 2%', 'Liquido', 'Medico', 'Anestesico de uso local');
SELECT setval('insumo_id_insumo_seq', 5);

INSERT INTO instrumento (id_instrumento, nombre, tipo, funcion, descripcion) VALUES
    (1, 'Bisturi No. 4', 'Quirurgico', 'Corte', 'Mango de bisturi con hoja no. 4'),
    (2, 'Pinza Kelly', 'Quirurgico', 'Hemostatica', 'Pinza hemostatica curva'),
    (3, 'Separador de Farabeuf', 'Quirurgico', 'Retractor', 'Separador manual de tejidos'),
    (4, 'Porta-agujas Mayo-Hegar', 'Quirurgico', 'Accesorio', 'Para sutura manual'),
    (5, 'Tijera Metzenbaum', 'Quirurgico', 'Corte', 'Tijera de diseccion de tejido fino');
SELECT setval('instrumento_id_instrumento_seq', 5);

INSERT INTO equipo (id_equipo, nombre, tipo, funcion, descripcion) VALUES
    (1, 'Maquina de anestesia', 'Medico', 'Tratamiento', 'Equipo para administracion de anestesia general'),
    (2, 'Monitor de signos vitales', 'Medico', 'Diagnostico', 'Monitoreo continuo de signos vitales'),
    (3, 'Electrobisturi', 'Quirurgico', 'Tratamiento', 'Corte y coagulacion por electrocirugia'),
    (4, 'Lampara quirurgica', 'Quirurgico', 'Exploracion', 'Iluminacion del campo quirurgico');
SELECT setval('equipo_id_equipo_seq', 4);

INSERT INTO quirofano (id_quirofano, id_hospital, numero, estado) VALUES
    (1, 1, 1, 'Ocupado'),
    (2, 1, 2, 'Libre'),
    (3, 2, 1, 'Libre');
SELECT setval('quirofano_id_quirofano_seq', 3);

INSERT INTO solicitud_cirugia (id_solicitud, id_paciente, id_cirujano, caracter, tipo_procedimiento, fecha_hora_solicitud, estado, id_hospital, historia_clinica, tiempo_estimado, tipo_anestesia, motivo_rechazo, id_quirofano, fecha_hora_agendada) VALUES
    (1, 2, 6, 'Urgente', 'Apendicectomia convencional', '2026-09-20 15:10', 'Aprobada', 1, 'Paciente masculino, 51 anios, dolor en fosa iliaca derecha de 12 horas de evolucion', '01:30:00', 'General', NULL, 1, '2026-09-20 16:00'),
    (2, 7, 7, 'Programado', 'Artroscopia de rodilla', '2026-09-18 09:00', 'Rechazada', 1, 'Paciente femenina, 46 anios, gonalgia cronica', '02:00:00', 'Regional', 'Estudios preoperatorios incompletos: falta evaluacion cardiologica', NULL, NULL);
SELECT setval('solicitud_cirugia_id_solicitud_seq', 2);

INSERT INTO requerimiento_insumo (id_solicitud, id_insumo, cantidad) VALUES
    (1, 1, 10), (1, 2, 2), (1, 3, 1);

INSERT INTO requerimiento_instrumento (id_solicitud, id_instrumento, cantidad) VALUES
    (1, 1, 1), (1, 2, 2), (1, 5, 1);

INSERT INTO requerimiento_equipo (id_solicitud, id_equipo, cantidad) VALUES
    (1, 1, 1), (1, 3, 1);

INSERT INTO consentimiento_informado (id_consentimiento, id_solicitud, nombre_procedimiento, objetivo, id_medico, firma_paciente, fecha, caracteristicas, riesgos) VALUES
    (1, 1, 'Apendicectomia convencional', 'Extirpar el apendice inflamado para evitar complicaciones', 6, 'Jose Manuel Garcia Lopez', '2026-09-20', 'Cirugia abierta bajo anestesia general', 'Sangrado, infeccion, reaccion anestesica');
SELECT setval('consentimiento_informado_id_consentimiento_seq', 1);

INSERT INTO chequeo_preanestesico (id_chequeo, id_solicitud, clasificacion_asa, id_medico_clasifica, id_anestesista, plan_anestesia) VALUES
    (1, 1, 'II', 6, 8, 'Anestesia general balanceada');
SELECT setval('chequeo_preanestesico_id_chequeo_seq', 1);

INSERT INTO cirugia (id_cirugia, id_solicitud, id_ingreso, id_quirofano, id_enfermero_encargado, fecha_hora_inicio, fecha_hora_fin, costo) VALUES
    (1, 1, 2, 1, 1, '2026-09-20 16:15', '2026-09-20 17:45', 3500.00);
SELECT setval('cirugia_id_cirugia_seq', 1);

INSERT INTO insumo_utilizado_cirugia (id_cirugia, id_insumo, cantidad) VALUES
    (1, 1, 8), (1, 2, 2), (1, 3, 1);

INSERT INTO registro_procedimiento_cirugia (id_registro, id_cirugia, etapa, procedimiento, resultado, hora_registro, id_enfermero, descripcion) VALUES
    (1, 1, 'Preoperatorio', 'Entrada: brazalete de identificacion y ficha clinica', 'Aceptable', '2026-09-20 16:00', 1, 'Paciente confirma nombre y procedimiento a realizar'),
    (2, 1, 'Intraoperatorio', 'Chequeo en quirofano', 'Aceptable', '2026-09-20 16:15', 1, 'Equipo completo y camilla trasladada correctamente'),
    (3, 1, 'Intraoperatorio', 'Procedimientos de pausa quirurgica', 'Aceptable', '2026-09-20 16:20', 1, 'Confirmacion de paciente, equipo y esterilidad'),
    (4, 1, 'Intraoperatorio', 'Gestion de cuidados intraoperatoria: balance hidrico', 'Exito', '2026-09-20 17:00', 1, 'Balance hidrico dentro de parametros normales'),
    (5, 1, 'Intraoperatorio', 'Salida quirurgica: conteo de instrumental', 'Aceptable', '2026-09-20 17:40', 1, 'Conteo de instrumental satisfactorio, cierre de incision'),
    (6, 1, 'Postoperatorio', 'Ingreso a sala de recuperacion', 'Exito', '2026-09-20 17:50', 3, 'Sin complicaciones durante la cirugia'),
    (7, 1, 'Postoperatorio', 'Traslado seguro a Hospitalizacion', 'Exito', '2026-09-20 19:00', 3, 'Signos vitales normales, zona operatoria limpia');
SELECT setval('registro_procedimiento_cirugia_id_registro_seq', 7);
