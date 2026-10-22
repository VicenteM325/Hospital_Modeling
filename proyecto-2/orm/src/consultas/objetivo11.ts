// OBJETIVO 11: ingresos monetarios totales (facturado) de cada hospital en un lapso de tiempo.
// Misma consulta que sql/consultas/obj_11_ingresos_totales_por_hospital.sql.
import { HospitalSchema } from '../db/entidades';
import type { Objetivo } from './tipos';

export const objetivo11: Objetivo = {
  numero: 11,
  titulo: 'Ingresos totales de cada hospital',
  usa: ['desde-hasta'],
  columnas: ['id_hospital', 'hospital', 'facturas', 'total_facturado'],
  sql: `
SELECT h.id_hospital, h.nombre AS hospital, COUNT(f.id_factura) AS facturas, COALESCE(SUM(f.monto), 0) AS total_facturado
FROM hospital h
LEFT JOIN factura f ON f.id_hospital = h.id_hospital AND f.fecha BETWEEN $1 AND $2
GROUP BY h.id_hospital, h.nombre
ORDER BY total_facturado DESC, h.nombre`,
  valoresSql: (p) => [p.desde, p.hasta],

  // El lapso va en la condicion del LEFT JOIN para que los hospitales sin facturas aparezcan con 0
  orm: (ds, p) =>
    ds.getRepository(HospitalSchema).createQueryBuilder('h')
      .leftJoin('h.facturas', 'f', 'f.fecha BETWEEN :desde AND :hasta', { desde: p.desde, hasta: p.hasta })
      .select('h.id_hospital', 'id_hospital')
      .addSelect('h.nombre', 'hospital')
      .addSelect('COUNT(f.id_factura)', 'facturas')
      .addSelect('COALESCE(SUM(f.monto), 0)', 'total_facturado')
      .groupBy('h.id_hospital').addGroupBy('h.nombre')
      .orderBy('total_facturado', 'DESC')
      .addOrderBy('h.nombre', 'ASC')
      .getRawMany(),
};
