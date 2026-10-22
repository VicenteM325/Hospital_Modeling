// OBJETIVO 8: total de pagos por metodo (efectivo, tarjeta de credito, tarjeta de debito) en cada hospital.
// Es el total por hospital (suma de todas sus unidades): coincide con las filas 'TODAS LAS UNIDADES'
// de sql/consultas/obj_08_pagos_por_metodo_y_hospital.sql.
import { CuotaSchema } from '../db/entidades';
import type { Objetivo } from './tipos';

const METODOS = { efectivo: 'Efectivo', credito: 'Tarjeta de credito', debito: 'Tarjeta de debito' };

export const objetivo08: Objetivo = {
  numero: 8,
  titulo: 'Pagos por metodo en cada hospital',
  usa: ['desde-hasta'],
  columnas: ['hospital', 'efectivo', 'tarjeta_credito', 'tarjeta_debito', 'total_pagado'],
  sql: `
SELECT h.nombre AS hospital,
       COALESCE(SUM(c.monto) FILTER (WHERE c.metodo_pago = $3), 0) AS efectivo,
       COALESCE(SUM(c.monto) FILTER (WHERE c.metodo_pago = $4), 0) AS tarjeta_credito,
       COALESCE(SUM(c.monto) FILTER (WHERE c.metodo_pago = $5), 0) AS tarjeta_debito,
       SUM(c.monto) AS total_pagado
FROM cuota c
JOIN factura f USING (id_factura)
JOIN hospital h ON h.id_hospital = f.id_hospital
WHERE c.fecha_pago BETWEEN $1 AND $2
GROUP BY h.nombre
ORDER BY h.nombre`,
  valoresSql: (p) => [p.desde, p.hasta, METODOS.efectivo, METODOS.credito, METODOS.debito],

  orm: (ds, p) =>
    ds.getRepository(CuotaSchema).createQueryBuilder('c')
      .innerJoin('c.factura', 'f')
      .innerJoin('f.hospital', 'h')
      .select('h.nombre', 'hospital')
      .addSelect('COALESCE(SUM(c.monto) FILTER (WHERE c.metodo_pago = :efectivo), 0)', 'efectivo')
      .addSelect('COALESCE(SUM(c.monto) FILTER (WHERE c.metodo_pago = :credito), 0)', 'tarjeta_credito')
      .addSelect('COALESCE(SUM(c.monto) FILTER (WHERE c.metodo_pago = :debito), 0)', 'tarjeta_debito')
      .addSelect('SUM(c.monto)', 'total_pagado')
      .where('c.fecha_pago BETWEEN :desde AND :hasta')
      .setParameters({ desde: p.desde, hasta: p.hasta, ...METODOS })   // parametros enlazados, nunca concatenados
      .groupBy('h.nombre')
      .orderBy('h.nombre', 'ASC')
      .getRawMany(),
};
