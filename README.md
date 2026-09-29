# Hospital_Modeling-
Data Base for Hospital with modules: Outpatient Care, Emergency, Surgery, and Inpatient Care.

## Estructura del repositorio

### `modelo/`
Modelos entidad-relación diseñados en draw.io (archivos `.drawio.xml`) junto con su exportación en imagen (`.png`).
- `hospital_bd_Start.xml`: modelo inicial de partida.
- `Nucleo_Completo/`: modelo del núcleo (departamentos, municipios, hospitales, pacientes, personal médico) y el modelo completo con todos los módulos integrados.
- `modulo_consulta_externa/`: modelo del módulo de consulta externa.
- `modulo_ingreso_egreso_traslado/`: modelo del flujo de ingreso, egreso y traslado de pacientes (Emergencias).
- `modulo_cirugia/`: modelo del módulo de cirugía.
- `modelo_hospitalizacion_facturacion/`: modelo de hospitalización, facturación y calificaciones.

### `sql/`
Scripts SQL numerados en el orden en que deben ejecutarse.
- `ddl/`: definición de la estructura (creación de tablas, llaves y restricciones), un script por módulo: núcleo, consulta externa, ingreso/egreso/traslado, cirugía y hospitalización/facturación/calificaciones.
- `dml/`: datos ficticios de prueba para cada módulo, incluyendo el flujo completo Emergencias-Cirugía-Hospitalización, un caso de alta directa y un caso activo sin egreso.
- `dcl/`: roles y privilegios (rol de solo lectura y rol administrador).

### `backup/`
Respaldo completo (estructura y datos) de la base de datos en `hospital_bd_backup.sql`.

### `documentacion/`
Documentación del proyecto (informe en PDF).
