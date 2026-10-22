// Entidades de TypeORM definidas con EntitySchema (sin decoradores): evita los problemas de metadata de
// decoradores al empaquetar con Next.js y deja el mapeo tabla <-> propiedad a la vista.
// Solo se mapean las tablas y columnas que usan los objetivos 2, 8 y 11. Las propiedades se llaman igual
// que las columnas de PostgreSQL, asi el QueryBuilder se lee igual que el SQL.
import { EntitySchema } from 'typeorm';

export interface Hospital { id_hospital: number; nombre: string; facturas?: Factura[] }
export interface Especialidad { id_especialidad: number; nombre: string }
export interface Medico {
  id_medico: number;
  nombre: string;
  hospital?: Hospital;
  especialidad?: Especialidad;
  calificaciones?: CalificacionMedico[];
  consultas?: ConsultaPaciente[];
}
export interface CalificacionMedico { id_calificacion: number; puntaje: number; medico?: Medico }
export interface ConsultaPaciente { id_consulta: number; medico?: Medico }
export interface Factura { id_factura: number; fecha: string; monto: string; hospital?: Hospital; cuotas?: Cuota[] }
export interface Cuota { id_cuota: number; monto: string; fecha_pago: string | null; metodo_pago: string; factura?: Factura }

export const HospitalSchema = new EntitySchema<Hospital>({
  name: 'Hospital',
  tableName: 'hospital',
  columns: { id_hospital: { type: Number, primary: true }, nombre: { type: String } },
  relations: { facturas: { type: 'one-to-many', target: 'Factura', inverseSide: 'hospital' } },
});

export const EspecialidadSchema = new EntitySchema<Especialidad>({
  name: 'Especialidad',
  tableName: 'especialidad',
  columns: { id_especialidad: { type: Number, primary: true }, nombre: { type: String } },
});

export const MedicoSchema = new EntitySchema<Medico>({
  name: 'Medico',
  tableName: 'medico',
  columns: { id_medico: { type: Number, primary: true }, nombre: { type: String } },
  relations: {
    hospital: { type: 'many-to-one', target: 'Hospital', joinColumn: { name: 'id_hospital' } },
    especialidad: { type: 'many-to-one', target: 'Especialidad', joinColumn: { name: 'id_especialidad' } },
    calificaciones: { type: 'one-to-many', target: 'CalificacionMedico', inverseSide: 'medico' },
    consultas: { type: 'one-to-many', target: 'ConsultaPaciente', inverseSide: 'medico' },
  },
});

export const CalificacionMedicoSchema = new EntitySchema<CalificacionMedico>({
  name: 'CalificacionMedico',
  tableName: 'calificacion_medico',
  columns: { id_calificacion: { type: Number, primary: true }, puntaje: { type: Number } },
  relations: { medico: { type: 'many-to-one', target: 'Medico', joinColumn: { name: 'id_medico' } } },
});

export const ConsultaPacienteSchema = new EntitySchema<ConsultaPaciente>({
  name: 'ConsultaPaciente',
  tableName: 'consulta_paciente',
  columns: { id_consulta: { type: Number, primary: true } },
  relations: { medico: { type: 'many-to-one', target: 'Medico', joinColumn: { name: 'id_medico' } } },
});

export const FacturaSchema = new EntitySchema<Factura>({
  name: 'Factura',
  tableName: 'factura',
  columns: {
    id_factura: { type: Number, primary: true },
    fecha: { type: 'date' },
    monto: { type: 'numeric' },
  },
  relations: {
    hospital: { type: 'many-to-one', target: 'Hospital', joinColumn: { name: 'id_hospital' } },
    cuotas: { type: 'one-to-many', target: 'Cuota', inverseSide: 'factura' },
  },
});

export const CuotaSchema = new EntitySchema<Cuota>({
  name: 'Cuota',
  tableName: 'cuota',
  columns: {
    id_cuota: { type: Number, primary: true },
    monto: { type: 'numeric' },
    fecha_pago: { type: 'date', nullable: true },
    metodo_pago: { type: String },
  },
  relations: { factura: { type: 'many-to-one', target: 'Factura', joinColumn: { name: 'id_factura' } } },
});

export const esquemas = [
  HospitalSchema, EspecialidadSchema, MedicoSchema, CalificacionMedicoSchema, ConsultaPacienteSchema, FacturaSchema, CuotaSchema,
];
