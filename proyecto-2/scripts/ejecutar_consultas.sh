#!/usr/bin/env bash
# Ejecuta las consultas de proyecto-2/sql/consultas con el usuario de solo lectura (usr_auditoria).
#
# proyecto-2/scripts/ejecutar_consultas.sh [patron] [-v fecha_inicio=2026-09-01 -v fecha_fin=2026-09-30 ...]
#   patron  fragmento del nombre del archivo (por ejemplo: obj_03, obj_1). Sin patron corre todas.
#   -v      variables de psql para los lapsos de tiempo y parametros (id_medico, ...).
set -euo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BD="${BD:-hospital_bd_p2}"
patron="${1:-obj_}"; shift || true
for f in "$RAIZ"/proyecto-2/sql/consultas/${patron}*.sql; do
    [ -e "$f" ] || { echo "No hay consultas que coincidan con '$patron'"; exit 1; }
    echo "=================================================================="
    echo ">> $(basename "$f")"
    echo "=================================================================="
    psql -X -q -U usr_auditoria -d "$BD" -v ON_ERROR_STOP=1 "$@" -f "$f" 2> >(grep -vE 'collation|COLLATION|discordancia|DETALLE|SUGERENCIA|^$' >&2)
done
