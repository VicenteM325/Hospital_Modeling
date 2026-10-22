// Verifica que SQL parametrizado y TypeORM devuelven el MISMO resultado en los objetivos 2, 8 y 11,
// con distintos lapsos de tiempo, y que un valor malicioso se trata como dato (parametros enlazados).
// Uso: npm run comparar        (sale con codigo 1 si algo no coincide)
import { obtenerDataSource } from '../src/db/conexion';
import { compararObjetivo, objetivos } from '../src/consultas';
import { validarParametros } from '../src/consultas/tipos';

process.loadEnvFile?.('.env');   // Node 24: carga las variables PG* del archivo .env

const lapsos = [
  { nombre: 'todo el periodo', entrada: {} },
  { nombre: 'septiembre 2026', entrada: { desde: '2026-09-01', hasta: '2026-09-30' } },
  { nombre: 'octubre 2026, limite 3', entrada: { desde: '2026-10-01', hasta: '2026-10-24', limite: '3' } },
];

async function main() {
  let fallos = 0;
  for (const objetivo of objetivos) {
    for (const lapso of lapsos) {
      const r = await compararObjetivo(objetivo.numero, validarParametros(lapso.entrada));
      const estado = r.iguales ? 'IGUALES' : 'DIFERENTES';
      console.log(`Objetivo ${String(r.objetivo).padStart(2)} | ${lapso.nombre.padEnd(24)} | SQL: ${String(r.sql.filas.length).padStart(2)} filas | ORM: ${String(r.orm.filas.length).padStart(2)} filas | ${estado}`);
      if (!r.iguales) fallos++;
    }
  }

  // Prueba de inyeccion SQL: aunque se salte la validacion, el valor viaja como parametro y no como texto de la sentencia
  const ds = await obtenerDataSource();
  const malicioso = "2026-01-01'; DROP TABLE cuota; --";
  try {
    await ds.query(objetivos[2].sql, [malicioso, '2026-10-24']);
    console.log('Inyeccion: ERROR, el valor malicioso fue aceptado');
    fallos++;
  } catch (e) {
    console.log(`Inyeccion: el valor malicioso se rechazo como fecha invalida (${(e as { code?: string }).code}); la tabla cuota sigue intacta`);
  }
  const [{ n }] = await ds.query('SELECT COUNT(*)::int AS n FROM cuota');
  console.log(`Tabla cuota despues de la prueba: ${n} filas`);

  await ds.destroy();
  console.log(fallos === 0 ? '\nTodo coincide: SQL y ORM producen el mismo resultado.' : `\nHay ${fallos} diferencia(s).`);
  process.exit(fallos === 0 ? 0 : 1);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
