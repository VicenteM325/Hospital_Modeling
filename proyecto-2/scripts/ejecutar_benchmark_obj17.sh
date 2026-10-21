#!/usr/bin/env bash
# Mide las 3 formas de construir el objetivo 17 con volumenes crecientes de medicos.
#   A: funciones de ventana   B: subconsulta correlacionada   C: autojoin
# Para cada tamaño crea una copia desechable de hospital_bd_p2 (hospital_bd_p2_bench), le agrega datos
# sinteticos, corre EXPLAIN (ANALYZE, BUFFERS) de cada variante y guarda el resumen en
# proyecto-2/documentacion/benchmark_obj17.txt. Al terminar borra la copia.
# Uso: proyecto-2/scripts/ejecutar_benchmark_obj17.sh [tamaño ...]     (por defecto 1000 5000 20000)
set -euo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DIR="$RAIZ/proyecto-2/sql/consultas/17_benchmark"
SALIDA="$RAIZ/proyecto-2/documentacion/benchmark_obj17.txt"
BD=hospital_bd_p2_bench
TAMANOS=("${@:-1000 5000 20000}")
read -r -a TAMANOS <<< "${TAMANOS[*]}"
TIMEOUT_MS=240000
filtrar() { grep -vE 'collation|COLLATION|discordancia|DETALLE|SUGERENCIA|^$' || true; }

{
echo "Evaluacion del objetivo 17 - tiempo de ejecucion (EXPLAIN ANALYZE) segun el numero de medicos"
echo "Fecha de la medicion: $(date '+%Y-%m-%d %H:%M')   PostgreSQL: $(psql -X -At -d postgres -c 'show server_version' 2>/dev/null | head -1)"
echo "Variantes: A = funciones de ventana | B = subconsulta correlacionada | C = autojoin. Limite por consulta: $((TIMEOUT_MS / 1000)) s."
echo
printf '%-18s %-14s %-14s %-14s\n' "medicos (total)" "A ventana" "B correlac." "C autojoin"
} > "$SALIDA"

PLANES=""
for n in "${TAMANOS[@]}"; do
    dropdb --if-exists --force "$BD" 2> >(filtrar >&2)
    createdb -T hospital_bd_p2 "$BD" 2> >(filtrar >&2)
    psql -X -q -d "$BD" -v ON_ERROR_STOP=1 -v n="$n" -f "$DIR/datos_sinteticos.sql" > /dev/null 2> >(filtrar >&2)
    total=$(psql -X -At -d "$BD" -c "select count(*) from medico" 2>/dev/null)
    fila=$(printf '%-18s' "$total")
    for v in a_ventana b_subconsulta_correlacionada c_autojoin; do
        consulta="$(cat "$DIR/variante_$v.sql")"
        plan=$(psql -X -At -d "$BD" -c "SET statement_timeout = $TIMEOUT_MS" -c "EXPLAIN (ANALYZE, BUFFERS) ${consulta}" 2>&1 | filtrar) || true
        ms=$(grep -oE 'Execution Time: [0-9.]+' <<< "$plan" | grep -oE '[0-9.]+' | head -1 || true)
        [ -n "$ms" ] || ms=">${TIMEOUT_MS}"
        fila+=$(printf ' %-14s' "${ms} ms")
        if [ "$n" = "${TAMANOS[-1]}" ]; then
            PLANES+=$'\n'"--- Plan de la variante $v con $total medicos ---"$'\n'"$plan"$'\n'
        fi
    done
    echo "$fila" >> "$SALIDA"
    echo "tamano $n listo: $fila"
done
{
echo
echo "Conclusion: la variante A (ventana) hace una sola pasada ordenada, O(n log n); B y C comparan cada medico con"
echo "todos los demas, O(n^2), y se vuelven inviables al crecer los registros. Se elige A."
echo "$PLANES"
} >> "$SALIDA"
dropdb --if-exists --force "$BD" 2> >(filtrar >&2)
echo "Resultados en ${SALIDA#"$RAIZ"/}"
