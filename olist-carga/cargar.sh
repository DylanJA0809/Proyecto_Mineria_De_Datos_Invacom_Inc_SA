#!/bin/bash
# Carga los 9 CSV de olist en OLIST_SRC con SQL*Loader. Corre DENTRO del contenedor uni-oracle.
# La contraseña de OLIST_SRC llega por la entrada estándar, para que no quede en la lista de procesos:
#   grep '^OLIST_SRC_PASSWORD=' ~/uni-oracle/.env | cut -d= -f2 | docker exec -i uni-oracle bash /opt/oracle/import/olist_carga/cargar.sh
# Es repetible: cada .ctl hace TRUNCATE antes de cargar. OJO: desde que existen las llaves de
# 02_llaves.sql, el TRUNCATE de una tabla padre falla (ORA-02266). Para recargar, primero
# desactivar las FK (alter table ... disable constraint ...) y reactivarlas al final.
set -u
read -r P
cd "$(dirname "$0")/ctl"
LOGS=/opt/oracle/import/olist_logs
PAR=$(mktemp)
trap 'rm -f "$PAR"' EXIT
chmod 600 "$PAR"
echo "userid=olist_src/$P@//localhost:1521/XEPDB1" > "$PAR"
export NLS_LANG=AMERICAN_AMERICA.AL32UTF8   # punto como separador decimal

for ctl in *.ctl; do
  t=${ctl%.ctl}
  rm -f "$LOGS/$t.bad"
  sqlldr parfile="$PAR" control="$ctl" log="$LOGS/$t.log" silent=header,feedback
  rc=$?
  cargadas=$(grep -oE '^ *[0-9]+ Rows? successfully loaded' "$LOGS/$t.log" | grep -oE '[0-9]+')
  rechazadas=$(grep -oE '^ *[0-9]+ Rows? not loaded due to data errors' "$LOGS/$t.log" | grep -oE '[0-9]+')
  printf '%-36s cargadas=%-8s rechazadas=%-5s rc=%s\n' "$t" "${cargadas:-?}" "${rechazadas:-?}" "$rc"
done
