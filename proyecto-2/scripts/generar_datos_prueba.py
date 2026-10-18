#!/usr/bin/env python3
"""Genera los scripts DML de ampliacion de datos del Proyecto 2 (sql/dml/06_*.sql, 07_*.sql, 08_*.sql).

Los datos son FICTICIOS (nombres, DPI, telefonos y direcciones inventados). El generador es
determinista (semilla fija): al ejecutarlo de nuevo produce exactamente los mismos archivos SQL,
que son los que se entregan. Usa IDs explicitos que continuan los del Proyecto 1, igual que el DML
original, y deja las secuencias al dia con setval.

Uso: python3 proyecto-2/scripts/generar_datos_prueba.py
"""
import random
from datetime import date, datetime, timedelta
from pathlib import Path

DML = Path(__file__).resolve().parents[1] / "sql" / "dml"
rnd = random.Random(2026)


# ---------------------------------------------------------------- utilidades SQL
def q(v):
    """Literal SQL de un valor de Python."""
    if v is None:
        return "NULL"
    if isinstance(v, bool):
        return "TRUE" if v else "FALSE"
    if isinstance(v, (int, float)):
        return str(v)
    if isinstance(v, datetime):
        return "'" + v.strftime("%Y-%m-%d %H:%M") + "'"
    if isinstance(v, date):
        return "'" + v.isoformat() + "'"
    return "'" + str(v).replace("'", "''") + "'"


def insertar(tabla, columnas, filas, comentario=None):
    out = [f"-- {comentario}"] if comentario else []
    out.append(f"INSERT INTO {tabla} ({', '.join(columnas)}) VALUES")
    out.append(",\n".join("    (" + ", ".join(q(v) for v in fila) + ")" for fila in filas) + ";")
    return "\n".join(out) + "\n"


def secuencia(tabla, columna):
    return f"SELECT setval(pg_get_serial_sequence('{tabla}', '{columna}'), (SELECT MAX({columna}) FROM {tabla}));\n"


def escoger(lista, i, paso=1, desfase=0):
    return lista[(i * paso + desfase) % len(lista)]


def fecha_aleatoria(desde, hasta):
    return desde + timedelta(days=rnd.randint(0, (hasta - desde).days))


# ---------------------------------------------------------- catalogos ficticios
NOMBRES_F = ["Maria", "Ana", "Rosa", "Lucia", "Carmen", "Elena", "Sofia", "Patricia", "Gloria", "Julia", "Teresa", "Marta"]
NOMBRES_M = ["Jose", "Luis", "Carlos", "Pedro", "Miguel", "Juan", "Jorge", "Mario", "Oscar", "Hugo", "Raul", "Andres"]
APELLIDOS = ["Xitumul", "Tzul", "Us", "Chocoj", "Batz", "Ixcoy", "Sican", "Toc", "Vail", "Cotzojay", "Marroquin", "Giron",
             "Tepaz", "Argueta", "Morales", "Lopez", "Ramirez", "Garcia", "De Leon", "Velasquez", "Cabrera", "Perez", "Mendez", "Alvarado"]
CALLES = ["avenida", "calle"]


def partes_nombre(i, sexo):
    """(nombres, apellidos) ficticios y repetibles para el indice i."""
    lista = NOMBRES_F if sexo == "F" else NOMBRES_M
    return (f"{escoger(lista, i, 5, 1)} {escoger(lista, i, 7, 4)}",
            f"{escoger(APELLIDOS, i, 3, 2)} {escoger(APELLIDOS, i, 5, 7)}")


def nombre_persona(i, sexo, titulo=None):
    base = " ".join(partes_nombre(i, sexo))
    return f"{titulo} {base}" if titulo else base


def direccion(i, municipio):
    return f"{1 + i % 9} {escoger(CALLES, i)} {1 + i % 12}-{10 + (i * 7) % 80}, zona {1 + i % 6}, {municipio}"


MUNICIPIOS = {1: "Quetzaltenango", 2: "Coatepeque", 3: "San Marcos", 4: "Malacatan", 5: "Huehuetenango",
              6: "Jacaltenango", 7: "Retalhuleu", 8: "Champerico", 9: "Totonicapan", 10: "Momostenango"}
MUNI_HOSPITAL = {1: 1, 2: 3, 3: 5, 4: 7, 5: 9}  # municipio sede de cada hospital

# ------------------------------------------------- hechos del Proyecto 1 que se reutilizan
# Medicos del Proyecto 1: id -> (hospital, especialidad). Ids 1-10, personal 1-10.
MEDICOS_P1 = {1: (1, 7), 2: (1, 12), 3: (1, 1), 4: (2, 4), 5: (2, 7), 6: (1, 17), 7: (1, 23), 8: (1, 17), 9: (3, 7), 10: (1, 6)}


# =============================================================================================
# ETAPA 1 - DML 06: infraestructura, personal y jerarquia, pacientes
# =============================================================================================
def etapa_nucleo(estado):
    s = ["-- DML P2-06: Ampliacion del nucleo - hospitales, infraestructura, personal con jerarquia y pacientes",
         "-- Datos FICTICIOS generados con proyecto-2/scripts/generar_datos_prueba.py (semilla fija).",
         "-- Continua los IDs del Proyecto 1. Ejecutar como usr_admin_bd despues de las migraciones DDL.\n",
         "SET ROLE rol_administrador;\nBEGIN;\n"]

    # ---- hospitales 4 y 5, unidades, camillas y quirofanos
    s.append(insertar("hospital", ["id_hospital", "nombre", "direccion", "id_municipio", "telefono"], [
        (4, "Hospital Nacional de Retalhuleu", "5a avenida 2-30, zona 1", 7, "77711400"),
        (5, "Hospital Nacional de Totonicapan", "3a calle 4-15, zona 2", 9, "77661250")],
        "Dos hospitales nuevos para que los rankings de los objetivos tengan sentido (5 en total)"))
    unidades = []
    for h, base in ((4, 10), (5, 13)):
        for k, tipo in enumerate(("Emergencias", "Cirugia", "Hospitalizacion")):
            unidades.append((base + k, h, tipo))
    s.append(insertar("unidad_hospital", ["id_unidad_hospital", "id_hospital", "tipo_unidad"], unidades,
                      "Unidades medicas de los hospitales nuevos (ids 10-15)"))
    # unidades: (hospital, tipo) -> id
    estado["unidad"] = {(1, "Emergencias"): 1, (1, "Cirugia"): 2, (1, "Hospitalizacion"): 3,
                        (2, "Emergencias"): 4, (2, "Cirugia"): 5, (2, "Hospitalizacion"): 6,
                        (3, "Emergencias"): 7, (3, "Cirugia"): 8, (3, "Hospitalizacion"): 9}
    estado["unidad"].update({(h, t): i for i, h, t in unidades})

    # camillas: P1 tiene 6 (unidad 1: #1,#2; unidad 3: #1,#2; unidad 4: #1; unidad 6: #1). Se completan 4 por unidad de Emergencias/Hospitalizacion
    camillas, cid = [], 7
    existentes = {1: 2, 3: 2, 4: 1, 6: 1}
    estado["camillas"] = {1: [1, 2], 3: [3, 4], 4: [6], 6: [5]}
    for (h, tipo), uid in sorted(estado["unidad"].items(), key=lambda x: x[1]):
        if tipo == "Cirugia":
            continue
        for n in range(existentes.get(uid, 0) + 1, 5):
            camillas.append((cid, uid, n, "Libre"))
            estado["camillas"].setdefault(uid, []).append(cid)
            cid += 1
    s.append(insertar("camilla", ["id_camilla", "id_unidad_hospital", "numero", "estado"], camillas,
                      "Camillas hasta completar 4 por unidad de Emergencias y de Hospitalizacion"))
    quirofanos = [(4, 2, 2, "Libre"), (5, 3, 1, "Libre"), (6, 3, 2, "Libre"), (7, 4, 1, "Libre"),
                  (8, 4, 2, "Libre"), (9, 5, 1, "Libre"), (10, 5, 2, "Libre")]
    s.append(insertar("quirofano", ["id_quirofano", "id_hospital", "numero", "estado"], quirofanos,
                      "Quirofanos para los hospitales que no tenian (P1: ids 1-3)"))
    estado["quirofanos"] = {1: [1, 2], 2: [3, 4], 3: [5, 6], 4: [7, 8], 5: [9, 10]}

    # ---- medicos nuevos (ids 11-32, personal 21-42): (hospital, especialidad, tipo, cargo, supervisor)
    nuevos = {
        11: (1, 1, "Residente", "Medico", 3),
        12: (2, 12, "Residente", "Jefe de Servicio", 4), 13: (2, 17, "Interno", "Jefe de Servicio", 4),
        14: (2, 7, "Residente", "Medico", 12), 15: (2, 1, "Residente", "Medico", 12),
        16: (3, 12, "Residente", "Jefe de Servicio", 9), 17: (3, 17, "Interno", "Jefe de Servicio", 9),
        18: (3, 7, "Residente", "Medico", 16), 19: (3, 23, "Externo", "Medico", 17), 20: (3, 1, "Residente", "Medico", 16),
        21: (4, 7, "Residente", "Director Medico", None), 22: (4, 12, "Residente", "Jefe de Servicio", 21),
        23: (4, 17, "Interno", "Jefe de Servicio", 21), 24: (4, 7, "Residente", "Medico", 22),
        25: (4, 1, "Residente", "Medico", 22), 26: (4, 18, "Externo", "Medico", 23),
        27: (5, 7, "Residente", "Director Medico", None), 28: (5, 12, "Residente", "Jefe de Servicio", 27),
        29: (5, 17, "Interno", "Jefe de Servicio", 27), 30: (5, 7, "Residente", "Medico", 28),
        31: (5, 1, "Residente", "Medico", 28), 32: (5, 23, "Externo", "Medico", 29),
    }
    medicos = {k: v for k, v in MEDICOS_P1.items()}
    for k, v in nuevos.items():
        medicos[k] = (v[0], v[1])
    estado["medico_hospital"] = {k: v[0] for k, v in medicos.items()}
    estado["medico_esp"] = {k: v[1] for k, v in medicos.items()}
    # Medicos que atienden Emergencias / Consulta Externa (especialidades de categoria Consulta_Emergencia) y cirujanos
    estado["emergencias"] = {1: [1, 2, 3, 11], 2: [5, 12, 14, 15], 3: [16, 18, 20], 4: [22, 24, 25], 5: [28, 30, 31]}
    estado["consulta"] = {1: [1, 2, 3, 10, 11], 2: [4, 5, 12, 14, 15], 3: [9, 16, 18, 20], 4: [21, 22, 24, 25], 5: [27, 28, 30, 31]}
    estado["cirujanos"] = {1: [6, 7, 8], 2: [13], 3: [17, 19], 4: [23, 26], 5: [29, 32]}

    # Reestructura de la jerarquia del Proyecto 1 (3 y 4 niveles) y datos sensibles de los medicos existentes
    s.append("-- Jerarquia de los medicos del Proyecto 1: Director -> Jefes de Servicio -> medicos\n"
             "UPDATE medico SET cargo = 'Jefe de Servicio', id_supervisor = 1 WHERE id_medico IN (2, 6);\n"
             "UPDATE medico SET id_supervisor = 2 WHERE id_medico IN (3, 10);\n"
             "UPDATE medico SET id_supervisor = 6 WHERE id_medico IN (7, 8);\n"
             "UPDATE medico SET cargo = 'Jefe de Servicio', id_supervisor = 4 WHERE id_medico = 5;\n")
    sal_cargo = {"Director Medico": (18000, 22000), "Jefe de Servicio": (14000, 17000), "Medico": (8000, 12000)}
    acc_cargo = {"Director Medico": "Administrador", "Jefe de Servicio": "Avanzado", "Medico": "Intermedio"}
    cargo_p1 = {1: "Director Medico", 4: "Director Medico", 9: "Director Medico", 2: "Jefe de Servicio", 6: "Jefe de Servicio", 5: "Jefe de Servicio"}
    sens = []
    for k in range(1, 33):
        cargo = cargo_p1.get(k, "Medico") if k <= 10 else nuevos[k][3]
        lo, hi = sal_cargo[cargo]
        acceso = acc_cargo[cargo] if (k % 7 or cargo == "Director Medico") else "Basico"
        sens.append((k, round(rnd.randint(lo, hi), -2), acceso))
    s.append("-- Salario y nivel de acceso de los 10 medicos del Proyecto 1 (datos que audita el objetivo 20)\n"
             "UPDATE medico SET salario = v.salario, nivel_acceso = v.acceso\n"
             "FROM (VALUES\n" + ",\n".join(f"    ({k}, {sal}, {q(acc)})" for k, sal, acc in sens if k <= 10) +
             "\n) AS v(id, salario, acceso) WHERE medico.id_medico = v.id;\n")
    sens_nuevo = {k: (sal, acc) for k, sal, acc in sens if k > 10}

    # ---- personal nuevo: medicos 21-42, enfermeros 43-51, encargados 52-62
    personal, med_rows = [], []
    for k, (h, esp, tipo, cargo, sup) in nuevos.items():
        pid = 10 + k  # personal 21..42
        sexo = "F" if k % 2 else "M"
        nombre = nombre_persona(k, sexo, "Dra." if sexo == "F" else "Dr.")
        personal.append((pid, "Medico", nombre, f"3{pid:012d}", fecha_aleatoria(date(2014, 1, 1), date(2026, 8, 31)),
                         f"5{pid:07d}", direccion(pid, MUNICIPIOS[MUNI_HOSPITAL[h]])))
        med_rows.append((k, pid, esp, tipo, h, cargo, sup, sens_nuevo[k][0], sens_nuevo[k][1], MUNI_HOSPITAL[h], "Urbana"))
    enf_hosp = {7: 1, 8: 2, 9: 2, 10: 3, 11: 3, 12: 4, 13: 4, 14: 5, 15: 5}
    enf_rows = []
    for e, h in enf_hosp.items():
        pid = 36 + e  # personal 43..51
        sexo = "F" if e % 3 else "M"
        personal.append((pid, "Enfermero", nombre_persona(e + 40, sexo), f"3{pid:012d}",
                         fecha_aleatoria(date(2016, 1, 1), date(2026, 8, 31)), None, direccion(pid, MUNICIPIOS[MUNI_HOSPITAL[h]])))
        tipo = "Registrado" if e % 2 else "Practicante"
        enf_rows.append((e, pid, tipo, h, f"ENF-{3000 + e}" if tipo == "Registrado" else None))
    enc_hosp = {5: 1, 6: 2, 7: 2, 8: 3, 9: 3, 10: 4, 11: 4, 12: 4, 13: 5, 14: 5, 15: 5}
    puestos = ["Recepcion", "Admisiones", "Facturacion", "Archivo Clinico", "Trabajo Social", "Coordinador de Turno"]
    enc_rows = []
    for e, h in enc_hosp.items():
        pid = 47 + e  # personal 52..62
        sexo = "F" if e % 2 else "M"
        personal.append((pid, "Encargado", nombre_persona(e + 70, sexo), f"3{pid:012d}",
                         fecha_aleatoria(date(2016, 1, 1), date(2026, 8, 31)), f"5{pid:07d}", direccion(pid, MUNICIPIOS[MUNI_HOSPITAL[h]])))
        enc_rows.append((e, pid, escoger(puestos, e, 1, 1), h, f"5{pid:07d}"))
    s.append(insertar("personal", ["id_personal", "tipo_personal", "nombre", "dpi", "fecha_contratacion", "telefono", "direccion"], personal,
                      "Supertipo PERSONAL: 22 medicos, 9 enfermeros y 11 encargados nuevos (ids 21-62)"))
    s.append(secuencia("personal", "id_personal"))
    # (nombre, dpi y telefono de los subtipos los copia el trigger trg_*_heredar_personal desde personal)
    s.append(insertar("medico", ["id_medico", "id_personal", "id_especialidad", "tipo_medico", "id_hospital", "cargo", "id_supervisor", "salario", "nivel_acceso", "id_municipio", "area"],
                      med_rows, "Subtipo MEDICO (ids 11-32). Un supervisor se inserta antes que sus subordinados"))
    s.append(secuencia("medico", "id_medico"))
    s.append(insertar("enfermero", ["id_enfermero", "id_personal", "tipo_enfermero", "id_hospital", "numero_colegiado"], enf_rows,
                      "Subtipo ENFERMERO (ids 7-15)"))
    s.append(secuencia("enfermero", "id_enfermero"))
    s.append(insertar("personal_encargado", ["id_encargado", "id_personal", "puesto", "id_hospital", "telefono"], enc_rows,
                      "Subtipo PERSONAL_ENCARGADO (ids 5-15)"))
    s.append(secuencia("personal_encargado", "id_encargado"))
    estado["enfermeros"] = {1: [1, 2, 3], 2: [4, 5, 8, 9], 3: [6, 10, 11], 4: [12, 13], 5: [14, 15]}
    estado["encargados"] = {1: [1, 2, 5], 2: [3, 6, 7], 3: [4, 8, 9], 4: [10, 11, 12], 5: [13, 14, 15]}

    # ---- datos de contratacion y direccion de los 20 miembros del personal del Proyecto 1 (el DDL les puso fecha de corte)
    legado = []
    for pid in range(1, 21):
        muni = {1: 1, 2: 1, 3: 1, 4: 3, 5: 3, 6: 1, 7: 1, 8: 1, 9: 5, 10: 1}.get(pid, 1 + pid % 5 * 2)
        legado.append((pid, fecha_aleatoria(date(2012, 1, 1), date(2025, 12, 31)), direccion(pid, MUNICIPIOS[muni])))
    s.append("-- El DDL asigno la fecha de corte 2026-01-01 al personal del Proyecto 1: se reemplaza por fechas ficticias y se agrega la direccion\n"
             "UPDATE personal SET fecha_contratacion = v.fecha::date, direccion = v.direccion FROM (VALUES\n" +
             ",\n".join(f"    ({pid}, {q(f)}, {q(d)})" for pid, f, d in legado) +
             "\n) AS v(id, fecha, direccion) WHERE personal.id_personal = v.id;\n")

    # ---- pacientes nuevos (ids 9-30) y responsables de los menores
    pac, resp = [], []
    nacimientos = [2019, 1952, 1987, 1994, 2008, 1976, 1961, 2001, 1983, 1999, 2015, 1948, 1970, 1991, 1980, 2022, 1958, 1996, 1973, 2005, 1985, 1967]
    rid = 5
    for n, anio in enumerate(nacimientos):
        pid = 9 + n
        sexo = "F" if pid % 2 else "M"
        muni = 1 + (pid * 3) % 10
        area = "Urbana" if muni in (1, 3, 5, 7, 9) and pid % 4 else "Rural"
        nac = date(anio, 1 + (pid * 5) % 12, 1 + (pid * 11) % 28)
        menor = anio >= 2008
        nombres, apellidos = partes_nombre(pid, sexo)
        pac.append((pid, f"EXP-2026-{pid:04d}", nombres, apellidos, sexo, nac, muni, area,
                    None if menor else f"4{pid:012d}", f"3{pid:07d}", f"IGSS-{900000 + pid * 17}" if pid % 3 == 0 else None))
        if menor:
            resp.append((rid, pid, nombre_persona(pid + 90, "F" if rid % 2 else "M"), "Madre" if rid % 2 else "Padre",
                         f"5{pid:012d}", f"3{pid:07d}", muni, area))
            rid += 1
    s.append(insertar("paciente", ["id_paciente", "no_expediente", "nombres", "apellidos", "sexo", "fecha_nacimiento", "id_municipio", "area", "dpi", "telefono", "no_seguro_social"],
                      pac, "22 pacientes ficticios (ids 9-30): menores sin DPI, adultos de 1948 a 2001"))
    s.append(secuencia("paciente", "id_paciente"))
    s.append(insertar("responsable_paciente", ["id_responsable", "id_paciente", "nombre", "parentesco", "dpi", "telefono", "id_municipio", "area"], resp,
                      "Responsables de los pacientes menores de edad (ids 5-%d)" % (rid - 1)))
    s.append(secuencia("responsable_paciente", "id_responsable"))
    estado["pac_nombre"] = {1: "Maria Xitumul Tzul", 2: "Jose Manuel Garcia Lopez", 3: "Juana Us Chocoj", 4: "Carlos Alberto Morales Ramirez",
                            5: "Rosa Elvira Tepaz Batz", 6: "Miguel Angel De Leon Argueta", 7: "Ana Lucia Marroquin Giron", 8: "Pedro Cotzojay Ixcoy"}
    estado["pac_nombre"].update({f[0]: f"{f[2]} {f[3]}" for f in pac})
    estado["pacientes"] = list(range(1, 31))
    estado["menores"] = {p[0] for p in pac if p[5].year >= 2008} | {8}
    estado["pac_sexo"] = {1: "F", 2: "M", 3: "F", 4: "M", 5: "F", 6: "M", 7: "F", 8: "M"}
    estado["pac_sexo"].update({9 + n: ("F" if (9 + n) % 2 else "M") for n in range(22)})
    s.append("COMMIT;\n")
    return "\n".join(s)


# =============================================================================================
# ETAPA 2 - DML 07: consulta externa, emergencias, turnos y calificaciones
# =============================================================================================
HOSP_PESO = {1: 0.26, 2: 0.20, 3: 0.18, 4: 0.18, 5: 0.18}   # demanda relativa de cada hospital
DX_CONSULTA = [("Rinofaringitis aguda", "Reposo e hidratacion abundante"), ("Hipertension arterial controlada", "Continuar tratamiento"),
               ("Gastritis cronica", "Dieta blanda y control en un mes"), ("Diabetes mellitus tipo 2", "Control de glucosa semanal"),
               ("Lumbalgia mecanica", "Fisioterapia y analgesicos"), ("Dermatitis de contacto", "Evitar el agente irritante"),
               ("Control prenatal de rutina", "Paciente en buen estado"), ("Faringoamigdalitis", "Antibiotico por 7 dias"),
               ("Control pediatrico de crecimiento", "Desarrollo adecuado para la edad"), ("Cefalea tensional", "Manejo del estres")]
MEDICAMENTOS = [("Paracetamol", "500 mg cada 6 horas", "5 dias"), ("Ibuprofeno", "400 mg cada 8 horas", "5 dias"),
                ("Amoxicilina", "500 mg cada 8 horas", "7 dias"), ("Omeprazol", "20 mg cada dia", "14 dias"),
                ("Loratadina", "10 mg cada dia", "7 dias"), ("Losartan", "50 mg cada dia", "30 dias"),
                ("Metformina", "850 mg cada 12 horas", "30 dias"), ("Salbutamol", "2 inhalaciones cada 6 horas", "10 dias")]
MOTIVOS_EMERG = [("Dolor toracico opresivo", "Sindrome coronario agudo a descartar"), ("Fractura por caida", "Fractura de tibia"),
                 ("Fiebre alta persistente", "Sindrome febril en estudio"), ("Crisis asmatica", "Crisis asmatica moderada"),
                 ("Trauma craneoencefalico por accidente de transito", "Trauma craneoencefalico leve"),
                 ("Dolor abdominal agudo", "Abdomen agudo a descartar"), ("Deshidratacion por vomitos y diarrea", "Gastroenteritis aguda"),
                 ("Herida por arma blanca", "Herida penetrante"), ("Convulsiones", "Crisis convulsiva"),
                 ("Dificultad respiratoria", "Neumonia a descartar"), ("Intoxicacion alimentaria", "Intoxicacion alimentaria")]
FECHA_INI, FECHA_FIN = date(2026, 8, 1), date(2026, 10, 24)


def etapa_consulta_emergencias(estado):
    s = ["-- DML P2-07: Ampliacion de Consulta Externa, Emergencias, turnos y calificaciones",
         "-- Datos FICTICIOS generados con proyecto-2/scripts/generar_datos_prueba.py (semilla fija).",
         "-- Continua los IDs del Proyecto 1. Ejecutar como usr_admin_bd despues de 06_ampliacion_nucleo_personal.sql.\n",
         "SET ROLE rol_administrador;\nBEGIN;\n"]
    horas = [f"{h:02d}:{m:02d}" for h in range(8, 16) for m in (0, 30)]
    hospitales = list(HOSP_PESO)
    pesos = list(HOSP_PESO.values())

    # ---- citas programadas (40 nuevas, ids 5-44)
    citas = []
    for _ in range(40):
        h = rnd.choices(hospitales, pesos)[0]
        medico = rnd.choice(estado["consulta"][h])
        paciente = rnd.choice(estado["pacientes"])
        est = rnd.choices(["Realizada", "Programada", "Cancelada", "Reprogramada"], [0.58, 0.12, 0.18, 0.12])[0]
        fecha = fecha_aleatoria(date(2026, 10, 26), date(2026, 11, 20)) if est == "Programada" else fecha_aleatoria(FECHA_INI, FECHA_FIN)
        citas.append([paciente, medico, fecha, rnd.choice(horas), est, f"Clinica {1 + medico % 6}", h])
    citas.sort(key=lambda c: (c[2], c[3]))
    filas_cita = [(5 + i, c[0], c[1], c[2], c[3], c[4], c[5]) for i, c in enumerate(citas)]
    s.append(insertar("cita_programada", ["id_cita", "id_paciente", "id_medico", "fecha", "hora", "estado", "consultorio"], filas_cita,
                      "40 citas: realizadas, programadas, canceladas y reprogramadas (las canceladas no cuentan como demanda)"))
    s.append(secuencia("cita_programada", "id_cita"))

    # ---- consultas: una por cada cita realizada + 10 pacientes referidos sin cita
    consultas = []
    for i, c in enumerate(citas):
        if c[4] == "Realizada":
            consultas.append([c[0], c[1], c[2], False, 5 + i, c[6]])
    for _ in range(10):
        h = rnd.choices(hospitales, pesos)[0]
        consultas.append([rnd.choice(estado["pacientes"]), rnd.choice(estado["consulta"][h]), fecha_aleatoria(FECHA_INI, FECHA_FIN), True, None, h])
    consultas.sort(key=lambda c: (c[2], c[1]))
    vistos = {1, 4, 7}  # pacientes con consulta en el Proyecto 1
    filas_con, estado["consultas"] = [], []
    for i, c in enumerate(consultas):
        cid = 4 + i
        tipo = "Reconsulta" if c[0] in vistos else "Primera"
        vistos.add(c[0])
        dx = escoger(DX_CONSULTA, cid, 3)
        filas_con.append((cid, c[0], c[1], c[2], tipo, c[3], c[4], dx[0], dx[1]))
        estado["consultas"].append({"id": cid, "paciente": c[0], "medico": c[1], "fecha": c[2], "hospital": c[5]})
    s.append(insertar("consulta_paciente", ["id_consulta", "id_paciente", "id_medico", "fecha", "tipo_consulta", "referido_institucion", "id_cita", "diagnostico", "notas"],
                      filas_con, f"{len(filas_con)} consultas: una por cada cita realizada y 10 de pacientes referidos sin cita"))
    s.append(secuencia("consulta_paciente", "id_consulta"))

    # ---- recetas y medicamentos recetados
    recetas, meds = [], []
    rid, mid = 3, 4
    for c in estado["consultas"]:
        if rnd.random() < 0.72:
            prox = c["fecha"] + timedelta(days=rnd.randint(14, 60)) if rnd.random() < 0.8 else None
            recetas.append((rid, c["id"], c["fecha"], c["hospital"], prox, str(1 + c["medico"] % 9)))
            for _ in range(rnd.randint(1, 3)):
                m = rnd.choice(MEDICAMENTOS)
                meds.append((mid, rid, m[0], m[1], m[2]))
                mid += 1
            rid += 1
    s.append(insertar("receta_medica", ["id_receta", "id_consulta", "fecha", "id_hospital", "proxima_cita", "numero_clinica"], recetas,
                      f"{len(recetas)} recetas; proxima_cita alimenta la demanda de consulta externa (objetivo 1)"))
    s.append(secuencia("receta_medica", "id_receta"))
    s.append(insertar("medicamento_recetado", ["id_medicamento_recetado", "id_receta", "nombre", "dosis", "duracion"], meds, f"{len(meds)} medicamentos recetados"))
    s.append(secuencia("medicamento_recetado", "id_medicamento_recetado"))

    # ---- ingresos y egresos de Emergencias (80 nuevos, ids 6 en adelante)
    espera_media = {1: 3.2, 2: 2.0, 3: 3.8, 4: 0.6, 5: 1.0}          # hospitales 4 y 5 atienden mas rapido (objetivo 4)
    fechas_muerte = {1: [date(2026, 9, 12), date(2026, 10, 3)], 2: [date(2026, 9, 27)], 3: [date(2026, 8, 21), date(2026, 10, 10)],
                     4: [date(2026, 9, 5)], 5: [date(2026, 10, 15)]}
    muertes = {1: 4, 2: 3, 3: 3, 4: 2, 5: 2}
    plan = []
    for h, n in muertes.items():                                      # defunciones concentradas en pocas fechas por hospital
        for k in range(n):
            plan.append((h, "Muerto", fechas_muerte[h][k % len(fechas_muerte[h])]))
    while len(plan) < 80:
        h = rnd.choices(hospitales, pesos)[0]
        codigo = rnd.choices(["Vivo", "Embarazo", "Parto"], [0.9, 0.04, 0.06])[0]
        plan.append((h, codigo, fecha_aleatoria(FECHA_INI, FECHA_FIN)))
    ingresos, egresos, secundarios = [], [], []
    for h, codigo, dia in plan:
        mujer_adulta = [p for p in estado["pacientes"] if estado["pac_sexo"][p] == "F" and p not in (3, 5, 7, 9, 11, 17, 19, 23, 25, 27)]
        paciente = rnd.choice(mujer_adulta) if codigo in ("Embarazo", "Parto") else rnd.choice(estado["pacientes"])
        medico = rnd.choice(estado["emergencias"][h])
        if codigo == "Muerto":
            egr = datetime(dia.year, dia.month, dia.day, rnd.randint(8, 22), rnd.choice((0, 15, 30, 45)))
            ing = egr - timedelta(hours=rnd.randint(3, 20))
        else:
            ing = datetime(dia.year, dia.month, dia.day, rnd.randint(0, 23), rnd.choice((0, 15, 30, 45)))
            egr = ing + timedelta(hours=rnd.randint(2, 30))
        motivo, dx = rnd.choice(MOTIVOS_EMERG)
        if codigo == "Embarazo":
            motivo, dx = "Control obstetrico de emergencia", "Embarazo con amenaza de parto pretermino"
        elif codigo == "Parto":
            motivo, dx = "Trabajo de parto", "Embarazo a termino en trabajo de parto"
        espera = max(0, int(rnd.gauss(espera_media[h], 1.2)))
        uni = estado["unidad"][(h, "Emergencias")]
        camilla = None if (espera >= 2 and rnd.random() < 0.45) else rnd.choice(estado["camillas"][uni])
        activo = codigo != "Muerto" and ing.date() >= date(2026, 10, 22)
        ingresos.append([ing, paciente, uni, medico, motivo, camilla, dx, espera, h, codigo, egr, activo])
    ingresos.sort(key=lambda r: r[0])
    filas_ing, filas_egr, filas_sec = [], [], []
    iid, eid, sid = 6, 5, 2
    for r in ingresos:
        ing, paciente, uni, medico, motivo, camilla, dx, espera, h, codigo, egr, activo = r
        resp = None
        filas_ing.append((iid, paciente, uni, medico, ing, motivo, resp, camilla, dx, espera))
        if not activo:
            sin = rnd.random() < 0.16 and codigo != "Muerto"
            if codigo == "Muerto":
                diag, mot_egr = "Paro cardiorrespiratorio", "Fallecimiento durante la atencion de emergencia"
            elif codigo == "Parto":
                diag, mot_egr = "Parto eutocico sin complicaciones", "Alta medica madre y recien nacido estables"
            elif codigo == "Embarazo":
                diag, mot_egr = "Amenaza de parto pretermino controlada", "Alta con indicaciones y control prenatal"
            else:
                diag, mot_egr = dx + " resuelta", "Alta medica por mejoria"
            filas_egr.append((eid, iid, medico, egr, diag, mot_egr, codigo, sin,
                              rnd.choice(["Paciente solicita egreso voluntario", "Familiar solicita traslado a otro centro"]) if sin else None,
                              None, 0 if (egr - ing) < timedelta(hours=24) else 1, None))
            if codigo == "Vivo" and rnd.random() < 0.15:
                filas_sec.append((sid, eid, "Deshidratacion leve resuelta"))
                sid += 1
            eid += 1
        estado.setdefault("ing_emerg", []).append({"id": iid, "paciente": paciente, "hospital": h, "fecha": ing, "medico": medico, "unidad": uni, "activo": activo})
        iid += 1
    estado["ingreso_sig"], estado["egreso_sig"] = iid, eid
    s.append(insertar("ingreso", ["id_ingreso", "id_paciente", "id_unidad_hospital", "id_medico", "fecha_hora", "motivo_ingreso", "id_responsable", "id_camilla", "diagnostico_presuntivo", "turno_espera"],
                      filas_ing, f"{len(filas_ing)} ingresos a Emergencias (ids 6-{iid - 1}); turno_espera mide los turnos que espero el paciente"))
    s.append(secuencia("ingreso", "id_ingreso"))
    s.append(insertar("egreso", ["id_egreso", "id_ingreso", "id_medico", "fecha_hora", "diagnostico_principal", "motivo_egreso", "codigo_egreso", "egreso_sin_consentimiento", "motivo_sin_consentimiento", "id_traslado", "dias_hospitalizado", "referido_otro_hospital"],
                      filas_egr, f"{len(filas_egr)} egresos de Emergencias: vivos, defunciones (concentradas en pocas fechas por hospital), partos y embarazos; los ingresos recientes siguen activos"))
    s.append(secuencia("egreso", "id_egreso"))
    s.append(insertar("diagnostico_secundario", ["id_diagnostico_secundario", "id_egreso", "descripcion"], filas_sec, "Diagnosticos secundarios de algunos egresos"))
    s.append(secuencia("diagnostico_secundario", "id_diagnostico_secundario"))

    # ---- turnos laborados por los medicos de emergencias (ids 1 en adelante); un turno cada 2 dias como minimo
    turnos, tid = [], 1
    dias_total = (FECHA_FIN - FECHA_INI).days + 1
    for h, medicos in estado["emergencias"].items():
        uni = estado["unidad"][(h, "Emergencias")]
        for m in medicos:
            desfase = rnd.randint(0, 1)
            dias = sorted(rnd.sample(range(desfase, dias_total, 2), rnd.randint(10, 17)))
            for d in dias:
                hora = rnd.choice((6, 14, 22))
                dur = 12 if rnd.random() < 0.3 else 8
                ini = datetime.combine(FECHA_INI + timedelta(days=d), datetime.min.time()) + timedelta(hours=hora)
                turnos.append((m, uni, ini, ini + timedelta(hours=dur)))
    turnos.sort(key=lambda t: (t[2], t[0]))
    s.append(insertar("turno_laboral", ["id_turno_laboral", "id_medico", "id_unidad_hospital", "fecha_hora_inicio", "fecha_hora_fin"],
                      [(i + 1, *t) for i, t in enumerate(turnos)],
                      f"{len(turnos)} turnos de 8 o 12 horas de los medicos de Emergencias (el turno se calcula solo con turno_de_hora)"))
    s.append(secuencia("turno_laboral", "id_turno_laboral"))

    # ---- calificaciones: cada medico tiene una calidad propia para que el ranking de los peor calificados tenga sentido
    calidad = {m: 1.8 + 3.0 * rnd.random() for m in estado["medico_hospital"]}
    califs = []
    cid = 2
    for h in hospitales:
        for m in estado["consulta"][h] + estado["cirujanos"][h]:
            for _ in range(rnd.randint(3, 8)):
                califs.append((m, max(1, min(5, round(rnd.gauss(calidad[m], 0.8)))), fecha_aleatoria(FECHA_INI, FECHA_FIN),
                               rnd.choice(estado["pacientes"])))
    califs.sort(key=lambda c: c[2])
    comentarios = {1: "Atencion deficiente, no explico el tratamiento", 2: "Larga espera y poca claridad", 3: "Atencion regular",
                   4: "Buena atencion y trato amable", 5: "Excelente atencion, muy profesional"}
    s.append(insertar("calificacion_medico", ["id_calificacion", "id_medico", "puntaje", "fecha", "id_paciente", "comentario"],
                      [(cid + i, m, p, f, pac, comentarios[p]) for i, (m, p, f, pac) in enumerate(califs)],
                      f"{len(califs)} calificaciones de medicos (1 a 5)"))
    s.append(secuencia("calificacion_medico", "id_calificacion"))

    def otras(tabla, col_id, ids_por_hospital, cantidad, comentario):
        filas = []
        for i in range(cantidad):
            h = hospitales[i % 5]
            filas.append((2 + i, escoger(ids_por_hospital[h], i), max(1, min(5, round(rnd.gauss(3.8 - 0.3 * (h == 3), 1.0)))),
                          fecha_aleatoria(FECHA_INI, FECHA_FIN), rnd.choice(estado["pacientes"]), None))
        return insertar(tabla, ["id_calificacion", col_id, "puntaje", "fecha", "id_paciente", "comentario"], filas, comentario)
    filas_h = [(2 + i, hospitales[i % 5], max(1, min(5, round(rnd.gauss((3.9, 3.5, 3.2, 4.3, 4.1)[i % 5], 0.8)))),
                fecha_aleatoria(FECHA_INI, FECHA_FIN), rnd.choice(estado["pacientes"]), None) for i in range(25)]
    s.append(insertar("calificacion_hospital", ["id_calificacion", "id_hospital", "puntaje", "fecha", "id_paciente", "comentario"], filas_h, "25 calificaciones de hospitales"))
    s.append(secuencia("calificacion_hospital", "id_calificacion"))
    s.append(otras("calificacion_enfermero", "id_enfermero", estado["enfermeros"], 22, "22 calificaciones de enfermeros"))
    s.append(secuencia("calificacion_enfermero", "id_calificacion"))
    s.append(otras("calificacion_personal_encargado", "id_encargado", estado["encargados"], 22, "22 calificaciones del personal encargado"))
    s.append(secuencia("calificacion_personal_encargado", "id_calificacion"))
    s.append("COMMIT;\n")
    return "\n".join(s)


# =============================================================================================
# ETAPA 3 - DML 08: cirugia, hospitalizacion, facturacion y cuotas
# =============================================================================================
# procedimiento -> (costo base, minutos, anestesia, urgente)
PROCEDIMIENTOS = {"Apendicectomia convencional": (3500, 90, "General", True), "Hernioplastia inguinal": (4800, 100, "Regional", False),
                  "Drenaje de absceso": (1800, 45, "Local", True), "Laparotomia exploradora": (11000, 180, "General", True),
                  "Colecistectomia laparoscopica": (8200, 120, "General", False), "Reduccion abierta de fractura de tibia": (9500, 150, "Regional", True),
                  "Artroscopia de rodilla": (7000, 110, "Regional", False)}
PROC_POR_ESPECIALIDAD = {17: ["Apendicectomia convencional", "Hernioplastia inguinal", "Drenaje de absceso", "Laparotomia exploradora"],
                         18: ["Colecistectomia laparoscopica"], 23: ["Reduccion abierta de fractura de tibia", "Artroscopia de rodilla"]}
MOTIVOS_RECHAZO = ["Estudios preoperatorios incompletos", "Paciente con riesgo anestesico no controlado (ASA IV)", "Falta de insumos para el procedimiento"]
CHEQUEOS = [("Preoperatorio", "Entrada: brazalete de identificacion y ficha clinica"), ("Intraoperatorio", "Chequeo en quirofano"),
            ("Intraoperatorio", "Procedimientos de pausa quirurgica"), ("Intraoperatorio", "Gestion de cuidados intraoperatoria: balance hidrico"),
            ("Intraoperatorio", "Salida quirurgica: conteo de instrumental"), ("Postoperatorio", "Ingreso a sala de recuperacion"),
            ("Postoperatorio", "Traslado seguro a Hospitalizacion")]
COSTO_DIA = {1: 380, 2: 340, 3: 300, 4: 320, 5: 330}
DIAS_MEDIA = {1: 4, 2: 4, 3: 3, 4: 6, 5: 5}
CAMAS_USADAS = {1: 4, 2: 4, 3: 3, 4: 2, 5: 3}
METODOS = ["Efectivo", "Tarjeta de credito", "Tarjeta de debito"]
PREF_PAGO = {1: [0.2, 0.6, 0.2], 2: [0.5, 0.2, 0.3], 3: [0.6, 0.1, 0.3], 4: [0.3, 0.3, 0.4], 5: [0.2, 0.2, 0.6]}
HOY = date(2026, 10, 24)


def etapa_cirugia_facturacion(estado):
    s = ["-- DML P2-08: Ampliacion de Cirugia, Hospitalizacion, Facturacion y cuotas",
         "-- Datos FICTICIOS generados con proyecto-2/scripts/generar_datos_prueba.py (semilla fija).",
         "-- Flujos completos Emergencias -> Cirugia -> Hospitalizacion con traslados. Ejecutar despues de 07_ampliacion_consulta_emergencias.sql.\n",
         "SET ROLE rol_administrador;\nBEGIN;\n"]
    hospitales = list(HOSP_PESO)
    unidad = estado["unidad"]
    ing, egr, tras, sol, cir, det = [], [], [], [], [], []
    req_ins, req_inst, req_eq, uso_ins, regs, cons, cheq = [], [], [], [], [], [], []
    iid, eid, tid, sid, cid, rid, hid = estado["ingreso_sig"], estado["egreso_sig"], 3, 3, 2, 8, 3
    kcons = estado.get("cons_id", 2)
    kchq = 2
    pac_nombre = {}

    # ---- catalogos nuevos de cirugia
    insumos = [(6, "Compresas quirurgicas", "Textil", "Quirurgico", "Compresas absorbentes esteriles"), (7, "Sutura Nylon 3-0", "Sintetico", "Quirurgico", "Sutura no absorbible"),
               (8, "Solucion antiseptica yodada", "Liquido", "Medico", "Antisepsia de la piel"), (9, "Mascarilla quirurgica", "Textil", "Medico", "Proteccion del equipo"),
               (10, "Malla quirurgica", "Polipropileno", "Quirurgico", "Refuerzo en hernioplastia")]
    instrumentos = [(6, "Pinza de diseccion Adson", "Quirurgico", "Accesorio", "Manipulacion de tejidos"), (7, "Separador Gelpi", "Quirurgico", "Retractor", "Separacion de planos"),
                    (8, "Clamp vascular", "Quirurgico", "Hemostatica", "Control de sangrado"), (9, "Taladro ortopedico", "Quirurgico", "Corte", "Perforacion de hueso"),
                    (10, "Tijera Mayo", "Quirurgico", "Corte", "Corte de suturas y tejido")]
    equipos = [(5, "Monitor de CO2", "Medico", "Diagnostico", "Capnografia"), (6, "Bomba de infusion", "Medico", "Tratamiento", "Infusion controlada"),
               (7, "Torre de laparoscopia", "Quirurgico", "Exploracion", "Cirugia minimamente invasiva"), (8, "Sierra ortopedica electrica", "Quirurgico", "Tratamiento", "Corte oseo")]
    s.append(insertar("insumo", ["id_insumo", "nombre", "material", "tipo", "descripcion"], insumos, "Insumos nuevos del catalogo (P1: ids 1-5)"))
    s.append(secuencia("insumo", "id_insumo"))
    s.append(insertar("instrumento", ["id_instrumento", "nombre", "tipo", "funcion", "descripcion"], instrumentos, "Instrumentos nuevos del catalogo (P1: ids 1-5)"))
    s.append(secuencia("instrumento", "id_instrumento"))
    s.append(insertar("equipo", ["id_equipo", "nombre", "tipo", "funcion", "descripcion"], equipos, "Equipos nuevos del catalogo (P1: ids 1-4)"))
    s.append(secuencia("equipo", "id_equipo"))

    # ---- estilo de cada cirujano: factor < 1 = pide menos material (objetivo 5) ; peso = cuantas cirugias agenda
    cirujanos = [m for h in hospitales for m in estado["cirujanos"][h]]
    factor = {m: 0.55 + 0.9 * rnd.random() for m in cirujanos}
    peso = {m: 0.5 + 2.0 * rnd.random() for m in cirujanos}
    consulta_por_h = {h: [c for c in estado["consultas"] if c["hospital"] == h and c["fecha"] <= date(2026, 9, 20)] for h in hospitales}
    usados = set()

    # ---- 18 cirugias aprobadas: 9 urgentes (desde Emergencias) y 9 programadas (ingreso directo a Cirugia)
    n_flujos = 18
    muerte_cirugia = {5, 12}      # flujos que terminan en defuncion en Cirugia
    muerte_hosp = {8, 15}         # flujos que terminan en defuncion en Hospitalizacion
    flujos = []
    for k in range(n_flujos):
        h = rnd.choices(hospitales, [0.30, 0.20, 0.18, 0.16, 0.16])[0]
        urgente = k % 2 == 0
        cirujano = rnd.choices(estado["cirujanos"][h], [peso[m] for m in estado["cirujanos"][h]])[0]
        lista = PROC_POR_ESPECIALIDAD[estado["medico_esp"][cirujano]]
        lista = [p for p in lista if PROCEDIMIENTOS[p][3] == urgente] or lista
        proc = rnd.choice(lista)
        pareja = [c for c in consulta_por_h[h] if c["paciente"] not in usados]
        if urgente and pareja and k < 12:                       # pacientes "fieles": consulta externa -> emergencias -> cirugia -> hospitalizacion
            c = rnd.choice(pareja)
            paciente, dia = c["paciente"], min(c["fecha"] + timedelta(days=rnd.randint(3, 25)), date(2026, 10, 10))
        else:
            paciente, dia = rnd.choice(estado["pacientes"]), fecha_aleatoria(date(2026, 8, 5), date(2026, 10, 12))
        usados.add(paciente)
        flujos.append((dia, h, urgente, cirujano, proc, paciente))
    flujos.sort(key=lambda f: f[0])

    quirofano_libre = {}
    for k, (dia, h, urgente, cirujano, proc, paciente) in enumerate(flujos):
        costo_base, minutos, anestesia, _ = PROCEDIMIENTOS[proc]
        u_em, u_ci, u_ho = unidad[(h, "Emergencias")], unidad[(h, "Cirugia")], unidad[(h, "Hospitalizacion")]
        hora0 = rnd.randint(7, 11) if not urgente else rnd.randint(0, 23)
        t0 = datetime(dia.year, dia.month, dia.day, hora0, rnd.choice((0, 15, 30, 45)))
        med_em = rnd.choice(estado["emergencias"][h])
        enf = rnd.choice(estado["enfermeros"][h])
        quiro = rnd.choice(estado["quirofanos"][h])
        dur = timedelta(minutes=minutos + rnd.randint(-10, 25))
        costo = round(costo_base * (0.9 + 0.35 * rnd.random()), -1)
        # solicitud, ingreso y (si es urgente) paso previo por Emergencias
        if urgente:
            ing_e, eg_e, tr_e = iid, eid, tid
            ing.append((ing_e, paciente, u_em, med_em, t0, "Cuadro agudo con indicacion quirurgica", None, rnd.choice(estado["camillas"][u_em]), proc + " requerida", 0))
            tras.append((tr_e, paciente, med_em, t0 + timedelta(minutes=45), u_ci, True, u_em, True))
            egr.append((eg_e, ing_e, med_em, t0 + timedelta(minutes=45), "Cuadro quirurgico agudo", "Traslado a Cirugia", "Vivo", False, None, tr_e, 0, None))
            iid, eid, tid = iid + 1, eid + 1, tid + 1
            t_ing_c = t0 + timedelta(hours=1)
            t_sol = t0 + timedelta(minutes=10)
        else:
            t_ing_c = t0
            t_sol = t0 - timedelta(days=rnd.randint(2, 6))
        t_ini = t_ing_c + timedelta(minutes=20)
        t_fin = t_ini + dur
        ing_c = iid
        ing.append((ing_c, paciente, u_ci, cirujano, t_ing_c, f"Intervencion quirurgica: {proc.lower()}", None, None, proc, None))
        iid += 1
        sol_id = sid
        sol.append((sol_id, paciente, cirujano, "Urgente" if urgente else "Programado", proc, t_sol, "Aprobada", h,
                    "Paciente con indicacion quirurgica segun valoracion clinica", f"{minutos // 60:02d}:{minutos % 60:02d}:00", anestesia, None, quiro, t_ini - timedelta(minutes=15)))
        sid += 1
        f = factor[cirujano]   # cirujanos eficientes (factor bajo) piden menos cantidad de cada cosa
        pedidos = []
        for tabla, catalogo, maximo in ((req_ins, range(1, 11), 10), (req_inst, range(1, 11), 4), (req_eq, range(1, 9), 3)):
            for item in rnd.sample(list(catalogo), rnd.randint(3, 4)):
                fila = (sol_id, item, max(1, round(rnd.randint(1, maximo) * f)))
                tabla.append(fila)
                if tabla is req_ins:
                    pedidos.append(fila)
        for (_, item, qty) in pedidos[:3]:   # lo realmente utilizado nunca supera lo solicitado
            uso_ins.append((cid, item, max(1, qty - rnd.randint(0, 2))))
        nombre_pac = estado["pac_nombre"][paciente]
        cons.append((kcons, sol_id, proc, f"Realizar {proc.lower()} para resolver el cuadro clinico", cirujano, nombre_pac, t_sol.date(), "Procedimiento bajo anestesia " + anestesia.lower(), "Sangrado, infeccion, reaccion anestesica"))
        kcons += 1
        anest = rnd.choice([m for m in estado["consulta"][h] if m != cirujano])
        cheq.append((kchq, sol_id, rnd.choice(["I", "II", "II", "III"]), cirujano, anest, "Anestesia " + anestesia.lower()))
        kchq += 1
        # resultados de los checklists: la mayoria sin problemas; algunas cirugias tienen fallas o complicaciones
        incidente = rnd.random() < 0.25
        post_mal = rnd.random() < 0.15
        fallece_c = k in muerte_cirugia
        for j, (etapa, procedimiento) in enumerate(CHEQUEOS):
            if fallece_c and etapa == "Postoperatorio":
                continue
            if etapa == "Intraoperatorio":
                res = rnd.choice(["Aceptable", "Exito"])
                if incidente and j == 3:
                    res = rnd.choice(["Medianamente aceptable", "No aceptable", "Falla"])
            elif etapa == "Postoperatorio":
                res = "Exito" if not post_mal else rnd.choice(["No aceptable", "Falla"])
            else:
                res = "Aceptable"
            hora = t_ing_c if etapa == "Preoperatorio" else (t_ini + dur * j / 6 if etapa == "Intraoperatorio" else t_fin + timedelta(minutes=10 * (j - 4)))
            desc = "Complicacion registrada durante la evolucion" if (res in ("Falla", "No aceptable") and etapa == "Postoperatorio") else "Sin complicaciones"
            regs.append((rid, cid, etapa, procedimiento, res, hora.replace(second=0, microsecond=0), enf, desc))
            rid += 1
        cir.append((cid, sol_id, ing_c, quiro, enf, t_ini, t_fin, costo))
        cid += 1
        # destino despues de la cirugia
        t_sale = t_fin + timedelta(minutes=30)
        if fallece_c:
            egr.append((eid, ing_c, cirujano, t_sale, "Falla multiorganica postoperatoria", "Fallecimiento durante la cirugia", "Muerto", False, None, None, 0, None))
            eid += 1
            estado.setdefault("facturas_flujo", []).append((h, paciente, ing_c, t_sale.date(), costo + 1200, "cirugia"))
            continue
        tr_h = tid
        tras.append((tr_h, paciente, cirujano, t_sale, u_ho, True, u_ci, True))
        tid += 1
        egr.append((eid, ing_c, cirujano, t_sale, proc + " realizada", "Traslado a Hospitalizacion para recuperacion", "Vivo", False, None, tr_h, None, None))
        eid += 1
        ing_h = iid
        t_ing_h = t_sale + timedelta(minutes=15)
        medh = rnd.choice(estado["consulta"][h])
        camas = estado["camillas"][u_ho][:CAMAS_USADAS[h]]
        cama = rnd.choice(camas)
        iid += 1
        ing.append((ing_h, paciente, u_ho, medh, t_ing_h, f"Recuperacion postoperatoria de {proc.lower()}", None, cama, "Postoperatorio", None))
        dias = max(1, int(rnd.gauss(DIAS_MEDIA[h], 1.5)))
        cdia = round(COSTO_DIA[h] * (0.9 + 0.2 * rnd.random()), -1)
        servicio = 6 if paciente in estado["menores"] else rnd.choice([2, 5, 7, 2, 5])
        t_alta = t_ing_h + timedelta(days=dias)
        if t_alta.date() > HOY:
            det.append((hid, ing_h, servicio, cama, cdia, None)); hid += 1
            total = costo + 1200
        else:
            muerto = k in muerte_hosp
            det.append((hid, ing_h, servicio, cama, cdia, dias)); hid += 1
            egr.append((eid, ing_h, medh, t_alta, "Postoperatorio de " + proc.lower() + (" con complicaciones" if muerto else " sin complicaciones"),
                        "Fallecimiento en recuperacion" if muerto else "Alta medica por mejoria", "Muerto" if muerto else "Vivo", False, None, None, dias, None))
            eid += 1
            total = costo + cdia * dias + 1200
        estado.setdefault("facturas_flujo", []).append((h, paciente, ing_c, min(t_alta.date(), HOY), total, "cirugia"))

    # ---- solicitudes no aprobadas (3 rechazadas y 3 pendientes)
    for j in range(6):
        h = hospitales[j % 5]
        cirujano = rnd.choice(estado["cirujanos"][h])
        proc = rnd.choice(PROC_POR_ESPECIALIDAD[estado["medico_esp"][cirujano]])
        rechazada = j < 3
        t_sol = datetime.combine(fecha_aleatoria(date(2026, 8, 10), date(2026, 10, 20)), datetime.min.time()) + timedelta(hours=rnd.randint(8, 16))
        sol.append((sid, rnd.choice(estado["pacientes"]), cirujano, "Programado", proc, t_sol, "Rechazada" if rechazada else "Pendiente", h,
                    "Valoracion clinica en curso", "01:30:00", PROCEDIMIENTOS[proc][2], MOTIVOS_RECHAZO[j % 3] if rechazada else None, None, None))
        sid += 1

    # ---- hospitalizaciones directas (sin cirugia): 12 ingresos, los mas recientes siguen activos
    for j in range(12):
        h = rnd.choices(hospitales, [0.2, 0.2, 0.2, 0.2, 0.2])[0]
        u_ho = unidad[(h, "Hospitalizacion")]
        paciente = rnd.choice(estado["pacientes"])
        t = datetime.combine(fecha_aleatoria(date(2026, 8, 5), date(2026, 10, 23)), datetime.min.time()) + timedelta(hours=rnd.randint(7, 20))
        med = rnd.choice(estado["consulta"][h])
        cama = rnd.choice(estado["camillas"][u_ho][:CAMAS_USADAS[h]])
        dx = rnd.choice([("Neumonia adquirida en la comunidad", 3), ("Insuficiencia cardiaca descompensada", 7), ("Fractura de cadera", 5),
                         ("Cetoacidosis diabetica", 2), ("Bronquiolitis", 6), ("Anemia severa", 1)])
        servicio = 6 if paciente in estado["menores"] else dx[1]
        dias = max(1, int(rnd.gauss(DIAS_MEDIA[h], 1.5)))
        cdia = round(COSTO_DIA[h] * (0.9 + 0.2 * rnd.random()), -1)
        ing.append((iid, paciente, u_ho, med, t, dx[0], None, cama, dx[0], None))
        t_alta = t + timedelta(days=dias)
        if t_alta.date() > HOY:
            det.append((hid, iid, servicio, cama, cdia, None)); hid += 1
        else:
            det.append((hid, iid, servicio, cama, cdia, dias)); hid += 1
            egr.append((eid, iid, med, t_alta, dx[0] + " tratada", "Alta medica por mejoria", "Vivo", False, None, None, dias, None))
            eid += 1
            estado.setdefault("facturas_flujo", []).append((h, paciente, iid, t_alta.date(), cdia * dias + 500, "hospitalizacion"))
        iid += 1

    s.append(insertar("traslado", ["id_traslado", "id_paciente", "id_medico_indica", "fecha_hora", "id_unidad_destino", "interno_destino", "id_unidad_origen", "interno_origen"], tras,
                      f"{len(tras)} traslados entre unidades (Emergencias -> Cirugia -> Hospitalizacion)"))
    s.append(secuencia("traslado", "id_traslado"))
    s.append(insertar("ingreso", ["id_ingreso", "id_paciente", "id_unidad_hospital", "id_medico", "fecha_hora", "motivo_ingreso", "id_responsable", "id_camilla", "diagnostico_presuntivo", "turno_espera"], ing,
                      f"{len(ing)} ingresos de los flujos de Cirugia y Hospitalizacion"))
    s.append(secuencia("ingreso", "id_ingreso"))
    s.append(insertar("egreso", ["id_egreso", "id_ingreso", "id_medico", "fecha_hora", "diagnostico_principal", "motivo_egreso", "codigo_egreso", "egreso_sin_consentimiento", "motivo_sin_consentimiento", "id_traslado", "dias_hospitalizado", "referido_otro_hospital"], egr,
                      f"{len(egr)} egresos (altas, traslados y defunciones)"))
    s.append(secuencia("egreso", "id_egreso"))
    s.append(insertar("solicitud_cirugia", ["id_solicitud", "id_paciente", "id_cirujano", "caracter", "tipo_procedimiento", "fecha_hora_solicitud", "estado", "id_hospital", "historia_clinica", "tiempo_estimado", "tipo_anestesia", "motivo_rechazo", "id_quirofano", "fecha_hora_agendada"], sol,
                      f"{len(sol)} solicitudes de cirugia: aprobadas, rechazadas y pendientes"))
    s.append(secuencia("solicitud_cirugia", "id_solicitud"))
    s.append(insertar("requerimiento_insumo", ["id_solicitud", "id_insumo", "cantidad"], req_ins, "Insumos solicitados en cada agendamiento"))
    s.append(insertar("requerimiento_instrumento", ["id_solicitud", "id_instrumento", "cantidad"], req_inst, "Instrumentos solicitados en cada agendamiento"))
    s.append(insertar("requerimiento_equipo", ["id_solicitud", "id_equipo", "cantidad"], req_eq, "Equipos solicitados en cada agendamiento"))
    s.append(insertar("consentimiento_informado", ["id_consentimiento", "id_solicitud", "nombre_procedimiento", "objetivo", "id_medico", "firma_paciente", "fecha", "caracteristicas", "riesgos"], cons, "Consentimientos firmados"))
    s.append(secuencia("consentimiento_informado", "id_consentimiento"))
    s.append(insertar("chequeo_preanestesico", ["id_chequeo", "id_solicitud", "clasificacion_asa", "id_medico_clasifica", "id_anestesista", "plan_anestesia"], cheq, "Chequeos preanestesicos"))
    s.append(secuencia("chequeo_preanestesico", "id_chequeo"))
    s.append(insertar("cirugia", ["id_cirugia", "id_solicitud", "id_ingreso", "id_quirofano", "id_enfermero_encargado", "fecha_hora_inicio", "fecha_hora_fin", "costo"], cir,
                      f"{len(cir)} cirugias realizadas"))
    s.append(secuencia("cirugia", "id_cirugia"))
    s.append(insertar("insumo_utilizado_cirugia", ["id_cirugia", "id_insumo", "cantidad"], uso_ins, "Insumos usados en cada cirugia"))
    s.append(insertar("registro_procedimiento_cirugia", ["id_registro", "id_cirugia", "etapa", "procedimiento", "resultado", "hora_registro", "id_enfermero", "descripcion"], regs,
                      f"{len(regs)} registros de checklists (algunas cirugias con fallas o complicaciones)"))
    s.append(secuencia("registro_procedimiento_cirugia", "id_registro"))
    s.append(insertar("hospitalizacion_detalle", ["id_hospitalizacion_detalle", "id_ingreso", "id_servicio", "id_camilla", "costo_dia", "dias"], det,
                      f"{len(det)} estadias de Hospitalizacion (los hospitales 4 y 5 usan menos camillas)"))
    s.append(secuencia("hospitalizacion_detalle", "id_hospitalizacion_detalle"))

    # ---- facturas: consultas externas, atenciones de emergencia sueltas y los flujos de cirugia/hospitalizacion
    fact = []   # (id, hospital, paciente, fecha, descripcion, monto, id_consulta, id_ingreso)
    fid = 4
    for c in estado["consultas"]:
        if rnd.random() < 0.6 and c["fecha"] <= HOY:
            monto = rnd.choice([150, 200, 250, 300]) * (0.5 if c["id"] % 3 == 0 else 1)
            fact.append((fid, c["hospital"], c["paciente"], c["fecha"], "Consulta externa de " + ("reconsulta" if c["id"] % 3 == 0 else "primera consulta"), monto, c["id"], None))
            fid += 1
    for e in estado["ing_emerg"]:
        if not e["activo"] and rnd.random() < 0.4:
            fact.append((fid, e["hospital"], e["paciente"], e["fecha"].date() + timedelta(days=1), "Atencion de emergencia", float(rnd.randint(400, 2500)), None, e["id"]))
            fid += 1
    for (h, paciente, ingreso, fecha, total, tipo) in estado["facturas_flujo"]:
        desc = "Cirugia y hospitalizacion asociada" if tipo == "cirugia" else "Hospitalizacion"
        fact.append((fid, h, paciente, fecha, desc, float(total), None, ingreso))
        fid += 1
    fact.sort(key=lambda f: (f[3], f[0]))
    renum = {f[0]: 4 + i for i, f in enumerate(fact)}
    fact = [(renum[f[0]], *f[1:]) for f in fact]
    cuotas, qid = [], 6
    for f in fact:
        fid_, h, _, fecha, _, monto, _, _ = f
        n = rnd.randint(1, 2) if monto <= 2000 else (rnd.randint(2, 4) if monto <= 8000 else rnd.randint(3, 6))
        if f[6] is not None and rnd.random() < 0.9:
            n = 1
        base = round(monto / n, 2)
        for k in range(1, n + 1):
            valor = base if k < n else round(monto - base * (n - 1), 2)
            pago = fecha + timedelta(days=30 * (k - 1))
            pagada = pago <= HOY and rnd.random() < 0.93
            cuotas.append((qid, fid_, k, valor, pago if pagada else None, rnd.choices(METODOS, PREF_PAGO[h])[0]))
            qid += 1
    s.append(insertar("factura", ["id_factura", "id_hospital", "id_paciente", "fecha", "descripcion", "monto", "id_consulta", "id_ingreso"], fact,
                      f"{len(fact)} facturas: de consulta externa o de un ingreso (arco exclusivo)"))
    s.append(secuencia("factura", "id_factura"))
    s.append(insertar("cuota", ["id_cuota", "id_factura", "numero_cuota", "monto", "fecha_pago", "metodo_pago"], cuotas,
                      f"{len(cuotas)} cuotas con su metodo de pago; fecha_pago NULL = aun sin pagar"))
    s.append(secuencia("cuota", "id_cuota"))
    s.append("COMMIT;\n")
    return "\n".join(s)


def main():
    estado = {}
    DML.mkdir(parents=True, exist_ok=True)
    (DML / "06_ampliacion_nucleo_personal.sql").write_text(etapa_nucleo(estado), encoding="utf-8")
    print("generado: sql/dml/06_ampliacion_nucleo_personal.sql")
    (DML / "07_ampliacion_consulta_emergencias.sql").write_text(etapa_consulta_emergencias(estado), encoding="utf-8")
    print("generado: sql/dml/07_ampliacion_consulta_emergencias.sql")
    (DML / "08_ampliacion_cirugia_hospitalizacion.sql").write_text(etapa_cirugia_facturacion(estado), encoding="utf-8")
    print("generado: sql/dml/08_ampliacion_cirugia_hospitalizacion.sql")


if __name__ == "__main__":
    main()
