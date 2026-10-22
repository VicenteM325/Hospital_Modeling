// Compara, para los objetivos 2, 8 y 11, el resultado de la consulta SQL parametrizada con el del ORM.
import { compararObjetivo, objetivos, type Comparacion } from '../consultas';
import { validarParametros } from '../consultas/tipos';

export const dynamic = 'force-dynamic';

function Tabla({ columnas, filas }: { columnas: string[]; filas: Record<string, string | number | null>[] }) {
  return (
    <table>
      <thead><tr>{columnas.map((c) => <th key={c}>{c}</th>)}</tr></thead>
      <tbody>
        {filas.map((f, i) => <tr key={i}>{columnas.map((c) => <td key={c}>{f[c]}</td>)}</tr>)}
      </tbody>
    </table>
  );
}

export default async function Pagina({ searchParams }: { searchParams: Promise<Record<string, string | undefined>> }) {
  const q = await searchParams;
  let parametros;
  let error: string | null = null;
  try {
    parametros = validarParametros({ desde: q.desde, hasta: q.hasta, limite: q.limite });
  } catch (e) {
    error = (e as Error).message;
    parametros = validarParametros({});
  }
  const resultados: Comparacion[] = [];
  for (const o of objetivos) resultados.push(await compararObjetivo(o.numero, parametros));

  return (
    <main>
      <h1>Hospitales de Occidente: SQL parametrizado vs ORM</h1>
      <p>Cada objetivo se ejecuta dos veces, con una sentencia SQL de parametros enlazados y con el QueryBuilder de TypeORM, y se compara el resultado.</p>
      <form method="get">
        <label>Desde <input type="date" name="desde" defaultValue={parametros.desde} /></label>
        <label>Hasta <input type="date" name="hasta" defaultValue={parametros.hasta} /></label>
        <label>Limite (objetivo 2) <input type="number" name="limite" min={1} max={50} defaultValue={parametros.limite} /></label>
        <button type="submit">Consultar</button>
      </form>
      {error && <p className="error">{error}</p>}
      {resultados.map((r) => (
        <section key={r.objetivo}>
          <h2>Objetivo {r.objetivo}: {r.titulo} <span className={r.iguales ? 'ok' : 'mal'}>{r.iguales ? 'SQL y ORM iguales' : 'DIFERENTES'}</span></h2>
          <details><summary>Sentencia SQL (parametros $1, $2, ...)</summary><pre>{r.sql.texto}</pre></details>
          <div className="dos">
            <div><h3>SQL ({r.sql.filas.length} filas)</h3><Tabla columnas={r.columnas} filas={r.sql.filas} /></div>
            <div><h3>ORM ({r.orm.filas.length} filas)</h3><Tabla columnas={r.columnas} filas={r.orm.filas} /></div>
          </div>
        </section>
      ))}
    </main>
  );
}
