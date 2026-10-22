import type { DataSource } from 'typeorm';

export interface Parametros {
  desde: string;   // YYYY-MM-DD
  hasta: string;   // YYYY-MM-DD
  limite: number;
}

export type Fila = Record<string, string | number | null>;

export interface Objetivo {
  numero: number;
  titulo: string;
  usa: ('desde-hasta' | 'limite')[];   // parametros que acepta
  columnas: string[];                  // columnas del resultado, en orden (sirven para comparar SQL contra ORM)
  sql: string;                         // sentencia con marcadores $1, $2... (nunca se concatenan valores)
  valoresSql: (p: Parametros) => unknown[];
  orm: (ds: DataSource, p: Parametros) => Promise<Fila[]>;
}

const FECHA = /^\d{4}-\d{2}-\d{2}$/;

/** Valida y normaliza los parametros que llegan de la URL o de la linea de comandos. */
export function validarParametros(entrada: { desde?: string | null; hasta?: string | null; limite?: string | null }): Parametros {
  const desde = entrada.desde ?? '2026-08-01';
  const hasta = entrada.hasta ?? '2026-10-24';
  const limite = Number(entrada.limite ?? 5);
  for (const f of [desde, hasta]) {
    if (!FECHA.test(f) || Number.isNaN(Date.parse(f))) throw new Error(`Fecha invalida: ${f} (formato YYYY-MM-DD)`);
  }
  if (desde > hasta) throw new Error('La fecha inicial no puede ser posterior a la final');
  if (!Number.isInteger(limite) || limite < 1 || limite > 50) throw new Error('El limite debe ser un entero entre 1 y 50');
  return { desde, hasta, limite };
}
