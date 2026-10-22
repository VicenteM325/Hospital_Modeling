import { obtenerDataSource } from '../db/conexion';
import { objetivo02 } from './objetivo02';
import { objetivo08 } from './objetivo08';
import { objetivo11 } from './objetivo11';
import type { Fila, Objetivo, Parametros } from './tipos';

export const objetivos: Objetivo[] = [objetivo02, objetivo08, objetivo11];

/** Deja las filas con las mismas columnas, en el mismo orden y como texto, para poder compararlas. */
function normalizar(filas: Record<string, unknown>[], columnas: string[]): Fila[] {
  return filas.map((f) => Object.fromEntries(columnas.map((c) => [c, f[c] == null ? null : String(f[c])])));
}

export interface Comparacion {
  objetivo: number;
  titulo: string;
  parametros: Parametros;
  columnas: string[];
  sql: { texto: string; filas: Fila[] };
  orm: { filas: Fila[] };
  iguales: boolean;
}

/** Ejecuta el objetivo con SQL parametrizado y con TypeORM, y dice si producen el mismo resultado. */
export async function compararObjetivo(numero: number, parametros: Parametros): Promise<Comparacion> {
  const objetivo = objetivos.find((o) => o.numero === numero);
  if (!objetivo) throw new Error(`El objetivo ${numero} no esta implementado con ORM (disponibles: ${objetivos.map((o) => o.numero).join(', ')})`);
  const ds = await obtenerDataSource();
  const filasSql = normalizar(await ds.query(objetivo.sql, objetivo.valoresSql(parametros)), objetivo.columnas);
  const filasOrm = normalizar(await objetivo.orm(ds, parametros), objetivo.columnas);
  return {
    objetivo: objetivo.numero,
    titulo: objetivo.titulo,
    parametros,
    columnas: objetivo.columnas,
    sql: { texto: objetivo.sql.trim(), filas: filasSql },
    orm: { filas: filasOrm },
    iguales: JSON.stringify(filasSql) === JSON.stringify(filasOrm),
  };
}
