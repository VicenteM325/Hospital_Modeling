// GET /api/objetivos/2?limite=5
// GET /api/objetivos/8?desde=2026-09-01&hasta=2026-09-30
// GET /api/objetivos/11?desde=2026-08-01&hasta=2026-10-24
// Devuelve el resultado con SQL parametrizado, el resultado con TypeORM y si son iguales.
import { NextResponse } from 'next/server';
import { compararObjetivo } from '../../../../consultas';
import { validarParametros } from '../../../../consultas/tipos';

export const runtime = 'nodejs';
export const dynamic = 'force-dynamic';

export async function GET(request: Request, contexto: { params: Promise<{ n: string }> }) {
  const { n } = await contexto.params;
  const q = new URL(request.url).searchParams;
  try {
    const parametros = validarParametros({ desde: q.get('desde'), hasta: q.get('hasta'), limite: q.get('limite') });
    return NextResponse.json(await compararObjetivo(Number(n), parametros));
  } catch (e) {
    return NextResponse.json({ error: (e as Error).message }, { status: 400 });
  }
}
