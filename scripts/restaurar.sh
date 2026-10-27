#!/usr/bin/env bash
# Restauracion de un respaldo Hefesto Soporte.
# Cumple las reglas 6 y 12 del contrato canonico docs/CONTRATO-RESPALDO.md, en
# este orden: manifiesto (claves, version, status) -> checksum -> rutas del tar
# -> destino vacio. Nunca vacia ni sobrescribe datos existentes.
set -euo pipefail

respaldo=""
destino=""
version_esperada=""
audit_log="${HEFESTO_RESPALDO_AUDIT:-${XDG_STATE_HOME:-$HOME/.local/state}/hefesto-respaldo/audit.log}"
sha="desconocido"

usage(){
  cat <<'EOF'
Uso: scripts/restaurar.sh --respaldo DIR --destino DIR [--version-esperada V] [--audit-log RUTA]
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --respaldo) respaldo="${2:-}"; shift 2;;
    --destino) destino="${2:-}"; shift 2;;
    --version-esperada) version_esperada="${2:-}"; shift 2;;
    --audit-log) audit_log="${2:-}"; shift 2;;
    -h|--help) usage; exit 0;;
    *) echo "argumento desconocido: $1" >&2; usage >&2; exit 2;;
  esac
done

[[ -n "${respaldo}" && -n "${destino}" ]] || { usage >&2; exit 2; }
[[ -d "${respaldo}" ]] || { echo "no existe el respaldo: ${respaldo}" >&2; exit 1; }
[[ -f "${respaldo}/manifest.json" ]] || { echo "falta manifest.json" >&2; exit 1; }
[[ -f "${respaldo}/data.tar.gz" ]] || { echo "falta data.tar.gz" >&2; exit 1; }
[[ -f "${respaldo}/SHA256SUMS" ]] || { echo "falta SHA256SUMS" >&2; exit 1; }

audit(){ mkdir -p "$(dirname "${audit_log}")"; printf '%s restore origen=%s sha256=%s destino=%s resultado=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "${respaldo}" "${sha}" "${destino}" "$1" >> "${audit_log}"; }

# 1. manifiesto: claves obligatorias, version esperada y status=completed
if ! sha="$(python3 - "${respaldo}/manifest.json" "${version_esperada}" <<'PY'
import json,sys
path,esperada=sys.argv[1],sys.argv[2]
m=json.load(open(path))
faltan=[k for k in ("software","version","database","sha256","status") if k not in m]
if faltan:
    raise SystemExit("manifiesto incompleto, faltan: "+", ".join(faltan))
if m["status"]!="completed":
    raise SystemExit("el respaldo no es restaurable: status="+str(m["status"]))
if esperada and m["version"]!=esperada:
    raise SystemExit("version inesperada: %s != %s"%(m["version"],esperada))
print(m["sha256"])
PY
)"; then
  audit "rechazado-manifiesto"
  exit 1
fi

# 2. checksum
esperado="$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1]))["sha256"])' "${respaldo}/manifest.json")"
if ! ( cd "${respaldo}" && sha256sum -c SHA256SUMS >/dev/null ); then
  audit "rechazado-checksum"
  exit 1
fi
verificado="$(cd "${respaldo}" && sha256sum data.tar.gz | awk '{print $1}')"
[[ "${verificado}" == "${esperado}" ]] || { echo "checksum no coincide" >&2; audit "rechazado-checksum"; exit 1; }
sha="${verificado}"

# 3. rutas dentro del tar: nada absoluto, nada con .., solo archivos o directorios
if tar -tzf "${respaldo}/data.tar.gz" | grep -qE '(^/|(^|/)\.\.(/|$))'; then
  echo "el tar contiene rutas prohibidas" >&2; audit "rechazado-rutas"; exit 1
fi
if tar -tvzf "${respaldo}/data.tar.gz" | grep -qE '^[lchpb]'; then
  echo "el tar contiene enlaces o dispositivos" >&2; audit "rechazado-enlaces"; exit 1
fi

# 4. destino vacio
mkdir -p "${destino}"
if [[ -n "$(ls -A "${destino}")" ]]; then
  echo "el destino no esta vacio: ${destino}" >&2; audit "rechazado-destino"; exit 1
fi

tar -xzf "${respaldo}/data.tar.gz" -C "${destino}"
audit "ok"
echo "${destino}"
