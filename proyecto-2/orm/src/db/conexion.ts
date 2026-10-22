// Una sola conexion por proceso. Se guarda en globalThis para que el modo desarrollo de Next.js
// (que recarga los modulos) no abra una conexion nueva en cada cambio.
import { DataSource } from 'typeorm';
import { esquemas } from './entidades';

const globalConConexion = globalThis as unknown as { __dataSourceHospital?: Promise<DataSource> };

export function obtenerDataSource(): Promise<DataSource> {
  globalConConexion.__dataSourceHospital ??= new DataSource({
    type: 'postgres',
    host: process.env.PGHOST ?? 'localhost',
    port: Number(process.env.PGPORT ?? 5432),
    username: process.env.PGUSER ?? 'usr_auditoria',   // rol de solo lectura: las consultas no pueden modificar datos
    password: process.env.PGPASSWORD,
    database: process.env.PGDATABASE ?? 'hospital_bd_p2',
    entities: esquemas,
    synchronize: false,        // NUNCA se deja que el ORM cree ni altere tablas: el esquema lo definen los scripts DDL
    migrationsRun: false,
    logging: process.env.TYPEORM_LOG === '1' ? ['query', 'error'] : false,
  }).initialize();
  return globalConConexion.__dataSourceHospital;
}
