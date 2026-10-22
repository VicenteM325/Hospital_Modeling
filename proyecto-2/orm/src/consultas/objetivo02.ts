// OBJETIVO 2: los 5 medicos de consulta externa con menor nota, con su promedio y numero de consultas.
// Misma consulta que sql/consultas/obj_02_medicos_menor_nota.sql, con el limite como parametro.
import { MedicoSchema } from '../db/entidades';
import type { Objetivo } from './tipos';

export const objetivo02: Objetivo = {
  numero: 2,
  titulo: 'Medicos de consulta externa con menor nota',
  usa: ['limite'],
  columnas: ['id_medico', 'medico', 'servicio', 'hospital', 'calificacion_promedio', 'numero_calificaciones', 'numero_consultas'],
  sql: `
WITH nota AS (
    SELECT id_medico, ROUND(AVG(puntaje), 2) AS calificacion_promedio, COUNT(*) AS numero_calificaciones
    FROM calificacion_medico GROUP BY id_medico
), consultas AS (
    SELECT id_medico, COUNT(*) AS numero_consultas FROM consulta_paciente GROUP BY id_medico
)
SELECT m.id_medico, m.nombre AS medico, e.nombre AS servicio, h.nombre AS hospital,
       n.calificacion_promedio, n.numero_calificaciones, c.numero_consultas
FROM medico m
JOIN nota n USING (id_medico)
JOIN consultas c USING (id_medico)
JOIN especialidad e ON e.id_especialidad = m.id_especialidad
JOIN hospital h ON h.id_hospital = m.id_hospital
ORDER BY n.calificacion_promedio ASC, c.numero_consultas DESC, m.id_medico
LIMIT $1`,
  valoresSql: (p) => [p.limite],

  // Version ORM: las relaciones del esquema (especialidad, hospital, calificaciones, consultas) arman los JOIN.
  // Al unir calificaciones y consultas cada calificacion se repite igual numero de veces por medico, por eso
  // el promedio no cambia y los conteos usan COUNT(DISTINCT ...).
  orm: (ds, p) =>
    ds.getRepository(MedicoSchema).createQueryBuilder('m')
      .innerJoin('m.especialidad', 'e')
      .innerJoin('m.hospital', 'h')
      .innerJoin('m.calificaciones', 'cal')
      .innerJoin('m.consultas', 'con')
      .select('m.id_medico', 'id_medico')
      .addSelect('m.nombre', 'medico')
      .addSelect('e.nombre', 'servicio')
      .addSelect('h.nombre', 'hospital')
      .addSelect('ROUND(AVG(cal.puntaje), 2)', 'calificacion_promedio')
      .addSelect('COUNT(DISTINCT cal.id_calificacion)', 'numero_calificaciones')
      .addSelect('COUNT(DISTINCT con.id_consulta)', 'numero_consultas')
      .groupBy('m.id_medico').addGroupBy('m.nombre').addGroupBy('e.nombre').addGroupBy('h.nombre')
      .orderBy('calificacion_promedio', 'ASC')
      .addOrderBy('numero_consultas', 'DESC')
      .addOrderBy('m.id_medico', 'ASC')
      .limit(p.limite)   // entero ya validado en validarParametros()
      .getRawMany(),
};
