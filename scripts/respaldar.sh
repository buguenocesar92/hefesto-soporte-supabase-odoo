#!/usr/bin/env bash
# Respaldo del kit portable Hefesto Soporte.
# Cumple el contrato canonico docs/CONTRATO-RESPALDO.md (Hefesto Studio,
# que vive en hefesto-monitor-uptime-kuma y hefesto-respaldo-kopia):
#   - salida en <timestamp>/ con data.tar.gz, SHA256SUMS y manifest.json
#   - manifest.json SIEMPRE trae software, version, database, sha256 y status
#   - el .env NUNCA viaja en claro: solo viajan los NOMBRES de las variables
#   - la auditoria vive FUERA del repositorio
#
# Salida: 0 -> respaldo completo; 1 -> fallo; 2 -> error de uso.
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
project_root="$(cd "${script_dir}/.." && pwd)"

destino=""
datos=""
software="hefesto-soporte"
version=""
database=""
modo="completo"
audit_log="${HEFESTO_RESPALDO_AUDIT:-${XDG_STATE_HOME:-$HOME/.local/state}/hefesto-respaldo/audit.log}"

usage(){
  cat <<'EOF'
Uso: scripts/respaldar.sh --destino DIR [opciones]
  --destino DIR           Carpeta base donde se escribe <timestamp>/ (obligatorio)
  --datos RUTA            Fichero o directorio de datos (por defecto $DATA_DIR)
  --software NOMBRE       Identificador del kit
  --version V             Version del kit (por defecto portable/package.json)
  --database D            Identificador de la base de datos (por defecto sqlite:<datos>)
  --modo rapido|completo  rapido omite la verificacion previa (por defecto completo)
  --audit-log RUTA        Log append-only de auditoria (fuera del repositorio)
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --destino) destino="${2:-}"; shift 2;;
    --datos) datos="${2:-}"; shift 2;;
    --software) software="${2:-}"; shift 2;;
    --version) version="${2:-}"; shift 2;;
    --database) database="${2:-}"; shift 2;;
    --modo) modo="${2:-}"; shift 2;;
    --audit-log) audit_log="${2:-}"; shift 2;;
    -h|--help) usage; exit 0;;
    *) echo "argumento desconocido: $1" >&2; usage >&2; exit 2;;
  esac
done

[[ -n "${destino}" ]] || { echo "falta --destino" >&2; usage >&2; exit 2; }
case "${modo}" in rapido|completo) ;; *) echo "--modo debe ser rapido o completo" >&2; exit 2;; esac
[[ -d "${destino}" ]] || { echo "el destino no existe: ${destino}" >&2; exit 2; }

if [[ -z "${datos}" ]]; then
  datos="${DATA_DIR:-}"
  [[ -n "${datos}" ]] || datos="${project_root}/data"
fi
[[ -e "${datos}" ]] || { echo "no hay datos que respaldar: ${datos}" >&2; exit 1; }

if [[ -z "${version}" ]]; then
  version="$(node -p "JSON.parse(require('fs').readFileSync('${project_root}/portable/package.json','utf8')).version" 2>/dev/null || echo "0.0.0")"
fi
[[ -n "${database}" ]] || database="sqlite:${datos}"

stamp="$(date -u +%Y%m%dT%H%M%SZ)"
run_dir="${destino}/${stamp}"
[[ ! -e "${run_dir}" ]] || { echo "ya existe ${run_dir}" >&2; exit 1; }
mkdir -p "${run_dir}"

# Nombres de variables de entorno: NUNCA sus valores.
env_vars=""
for candidate in "${datos}/.env" "${project_root}/.env" "${project_root}/.env.example"; do
  if [[ -f "${candidate}" ]]; then
    env_vars="$(grep -oE '^[[:space:]]*[A-Za-z_][A-Za-z0-9_]*=' "${candidate}" | tr -d ' =' | sort -u || true)"
    break
  fi
done

tar -czf "${run_dir}/data.tar.gz" \
  --exclude='.env' --exclude='.env.*' --exclude='node_modules' \
  --exclude='*.sqlite-wal' --exclude='*.sqlite-shm' \
  -C "$(dirname "${datos}")" "$(basename "${datos}")"

sha="$(sha256sum "${run_dir}/data.tar.gz" | awk '{print $1}')"
printf '%s  data.tar.gz\n' "${sha}" > "${run_dir}/SHA256SUMS"

cat > "${run_dir}/manifest.json" <<JSON
{
  "software": "${software}",
  "version": "${version}",
  "database": "${database}",
  "sha256": "${sha}",
  "status": "completed",
  "created_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "mode": "${modo}",
  "env_included": false,
  "env_vars": $(printf '%s' "${env_vars}" | python3 -c 'import sys,json;print(json.dumps([l for l in sys.stdin.read().split() if l]))'),
  "note": "El .env no viaja en claro. Solo los nombres de las variables; los valores se reconfiguran en el destino."
}
JSON

if [[ "${modo}" == "completo" ]]; then
  ( cd "${run_dir}" && sha256sum -c SHA256SUMS >/dev/null )
  if tar -tzf "${run_dir}/data.tar.gz" | grep -qE '(^|/)\.env$'; then
    echo "el .env quedo en claro: el respaldo no se publica" >&2
    exit 1
  fi
fi

mkdir -p "$(dirname "${audit_log}")"
printf '%s backup software=%s version=%s sha256=%s destino=%s resultado=completed\n' \
  "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "${software}" "${version}" "${sha}" "${run_dir}" >> "${audit_log}"

echo "${run_dir}"
