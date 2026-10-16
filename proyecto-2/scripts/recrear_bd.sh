#!/usr/bin/env bash
# Reconstruye desde cero la base hospital_bd_p2 = Proyecto 1 + extension del Proyecto 2.
# Uso: proyecto-2/scripts/recrear_bd.sh [nombre_bd]      (por defecto hospital_bd_p2)
#   1. Proyecto 1: sql/ddl, sql/dml y sql/dcl   (como superusuario del servidor)
#   2. Proyecto 2: sql/dcl  propiedad y privilegios para el rol administrativo (superusuario)
#   3. Proyecto 2: sql/ddl, sql/dml             (como usr_admin_bd, rol administrativo)
#   4. Proyecto 2: sql/auditoria                (como usr_admin_bd)
set -euo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
P2="$RAIZ/proyecto-2"
BD="${1:-hospital_bd_p2}"
FILTRO='collation|COLLATION|discordancia|DETALLE|DETAIL|HINT|SUGERENCIA|skipping|omitiendo|^$'

[ "$BD" != "hospital_bd" ] || { echo "Por seguridad no se reconstruye hospital_bd (base del Proyecto 1)"; exit 1; }

# ejecutar <archivo> [usuario] [estricto|tolerante]
ejecutar() {
    local archivo="$1" usuario="${2:-}" modo="${3:-estricto}" args=(-X -q -d "$BD" -v "NOMBRE_BD=$BD")
    [ -n "$usuario" ] && args+=(-U "$usuario")
    local filtro="$FILTRO"
    if [ "$modo" = "estricto" ]; then args+=(-v ON_ERROR_STOP=1); else filtro="$FILTRO|already exists|ya existe"; fi
    echo "  -> ${archivo#"$RAIZ"/}${usuario:+  (como $usuario)}"
    psql "${args[@]}" -f "$archivo" 2> >(grep -vE "$filtro" >&2) >/dev/null
}

echo "== Creando base $BD =="
dropdb --if-exists --force "$BD" 2> >(grep -vE "$FILTRO" >&2) || true
createdb -T template0 -E UTF8 --locale=es_GT.UTF-8 "$BD" 2> >(grep -vE "$FILTRO" >&2)

echo "== Fase 1: Proyecto 1 (DDL, DML, DCL) =="
for f in "$RAIZ"/sql/ddl/*.sql "$RAIZ"/sql/dml/*.sql; do ejecutar "$f"; done
# El DCL del Proyecto 1 hace CREATE ROLE de roles que ya existen en el servidor: se tolera ese error
ejecutar "$RAIZ/sql/dcl/01_roles_privilegios.sql" "" tolerante

echo "== Fase 2: Proyecto 2 - propiedad y privilegios =="
for f in "$P2"/sql/dcl/*.sql; do [ -e "$f" ] || continue; ejecutar "$f"; done

echo "== Fase 3: Proyecto 2 - DDL y DML (rol administrativo) =="
for f in "$P2"/sql/ddl/*.sql "$P2"/sql/dml/*.sql; do [ -e "$f" ] || continue; ejecutar "$f" usr_admin_bd; done

echo "== Fase 4: Proyecto 2 - auditoria =="
for f in "$P2"/sql/auditoria/*.sql; do [ -e "$f" ] || continue; ejecutar "$f" usr_admin_bd; done

echo "== Base $BD lista =="
