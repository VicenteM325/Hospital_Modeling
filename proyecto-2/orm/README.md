# ORM del Proyecto 2: Next.js + TypeORM

Los objetivos **2, 8 y 11** se resuelven de dos formas sobre la misma base `hospital_bd_p2` y se comprueba que
dan el mismo resultado:

1. **SQL parametrizado**: una sentencia con marcadores `$1, $2, ...` ejecutada con `DataSource.query(sql, valores)`.
   Los valores viajan aparte del texto de la sentencia; nunca se concatenan.
2. **ORM**: el `QueryBuilder` de TypeORM sobre entidades definidas con `EntitySchema`
   ([src/db/entidades.ts](src/db/entidades.ts)).

| Objetivo | Archivo | Parametros |
|---|---|---|
| 2 - medicos de consulta externa con menor nota | [src/consultas/objetivo02.ts](src/consultas/objetivo02.ts) | `limite` |
| 8 - pagos por metodo en cada hospital | [src/consultas/objetivo08.ts](src/consultas/objetivo08.ts) | `desde`, `hasta` |
| 11 - ingresos totales de cada hospital | [src/consultas/objetivo11.ts](src/consultas/objetivo11.ts) | `desde`, `hasta` |

## Seguridad
- La conexion usa `usr_auditoria`, el rol de **solo lectura** del Proyecto 1: aunque hubiera un error, el ORM no puede modificar datos.
- `synchronize: false`: el ORM nunca crea ni altera tablas; el esquema lo definen los scripts de `sql/ddl`.
- Los parametros de la URL se validan (`validarParametros`) y ademas se enlazan como parametros de la sentencia.
- `npm run comparar` incluye una prueba de inyeccion SQL: un valor como `2026-01-01'; DROP TABLE cuota; --` se rechaza como fecha invalida.

## Uso
Requiere Node 24 y la base creada con `proyecto-2/scripts/recrear_bd.sh`.

```bash
cd proyecto-2/orm
cp .env.example .env        # datos de conexion (el .env no se versiona)
npm install
npm run comparar            # compara SQL vs ORM con 3 lapsos distintos y prueba la inyeccion
npm run dev                 # interfaz en http://localhost:3000 y API en /api/objetivos/{2|8|11}
```

Ejemplos de la API: `GET /api/objetivos/2?limite=3` y `GET /api/objetivos/11?desde=2026-09-01&hasta=2026-09-30`
devuelven `{ sql, orm, iguales }`.

## Por que EntitySchema y no decoradores
Next.js empaqueta el codigo del servidor y los decoradores de TypeORM dependen de metadata de TypeScript que
ese empaquetado no siempre conserva. `EntitySchema` define las mismas entidades con objetos simples.
