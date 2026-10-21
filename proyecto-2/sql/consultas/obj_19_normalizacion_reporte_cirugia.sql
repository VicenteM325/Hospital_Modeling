-- OBJETIVO 19 (Bloque E): analisis y propuesta de normalizacion del Reporte_Cirugia.
-- Las sentencias CREATE TABLE de la propuesta estan en sql/ddl/03_propuesta_normalizacion_cirugia.sql
-- (esquema propuesta_cirugia). Estas consultas muestran los problemas del reporte y comprueban que la
-- descomposicion no pierde informacion.

-- (a) Redundancia: el cirujano y su especialidad se repiten en cada cirugia que hizo
SELECT nombre_cirujano, especialidad_cirujano, COUNT(*) AS filas_que_repiten_el_dato
FROM propuesta_cirugia.reporte_cirugia_original
GROUP BY nombre_cirujano, especialidad_cirujano
ORDER BY filas_que_repiten_el_dato DESC, nombre_cirujano;

-- (b) Grupo repetido: para saber en cuantas cirugias se uso un insumo hay que revisar las dos columnas
--     de insumo y, si en el futuro se usan 3 insumos, el esquema no alcanza.
SELECT 'reporte original (revisa insumo_1 e insumo_2)' AS forma, COUNT(*) AS cirugias_con_gasas
FROM propuesta_cirugia.reporte_cirugia_original
WHERE nombre_insumo_1 = 'Gasas esteriles' OR nombre_insumo_2 = 'Gasas esteriles'
UNION ALL
SELECT 'tablas normalizadas (un solo filtro)', COUNT(DISTINCT ci.id_cirugia)
FROM propuesta_cirugia.cirugia_insumo ci
JOIN propuesta_cirugia.insumo i USING (id_insumo)
WHERE i.nombre = 'Gasas esteriles';

-- (c) Sin perdida de informacion: las diferencias en ambos sentidos deben ser 0 filas
WITH original AS (        -- el reporte original, con los insumos "desdoblados" en una fila por insumo
    SELECT id_cirugia, nombre_insumo_1 AS insumo, cantidad_insumo_1 AS cantidad FROM propuesta_cirugia.reporte_cirugia_original WHERE nombre_insumo_1 IS NOT NULL
    UNION ALL
    SELECT id_cirugia, nombre_insumo_2, cantidad_insumo_2 FROM propuesta_cirugia.reporte_cirugia_original WHERE nombre_insumo_2 IS NOT NULL
), normalizado AS (
    SELECT ci.id_cirugia, i.nombre AS insumo, ci.cantidad
    FROM propuesta_cirugia.cirugia_insumo ci JOIN propuesta_cirugia.insumo i USING (id_insumo)
)
SELECT (SELECT COUNT(*) FROM (SELECT * FROM original EXCEPT SELECT * FROM normalizado) a) AS insumos_perdidos,
       (SELECT COUNT(*) FROM (SELECT * FROM normalizado EXCEPT SELECT * FROM original) b) AS insumos_inventados,
       (SELECT COUNT(*) FROM (
            SELECT id_cirugia, nombre_cirujano, especialidad_cirujano, nombre_paciente, codigo_diagnostico, descripcion_diagnostico, fecha
            FROM propuesta_cirugia.reporte_cirugia_original
            EXCEPT
            SELECT id_cirugia, nombre_cirujano, especialidad_cirujano, nombre_paciente, codigo_diagnostico, descripcion_diagnostico, fecha
            FROM propuesta_cirugia.v_reporte_cirugia) c) AS cirugias_distintas_en_la_vista;
