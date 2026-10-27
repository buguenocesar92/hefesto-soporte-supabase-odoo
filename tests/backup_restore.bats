#!/usr/bin/env bats
# Ciclo completo de respaldo y restauracion con datos sinteticos y en aislamiento.
# Contrato canonico docs/CONTRATO-RESPALDO.md, reglas 2, 3, 5, 6, 7 y 12.

setup(){
  kit="$(cd "$(dirname "${BATS_TEST_FILENAME}")/.." && pwd)"
  base="$(mktemp -d)"
  datos="${base}/datos"; mkdir -p "${datos}"
  printf '{"clientes":["c1"]}' > "${datos}/estado.json"
  printf 'ADMIN_PASSWORD=valor-secreto\n' > "${datos}/.env"
  destino="${base}/destino"; mkdir -p "${destino}"
  audit="${base}/audit.log"
  run_dir="$(bash "${kit}/scripts/respaldar.sh" --destino "${destino}" --datos "${datos}" --audit-log "${audit}" | tail -n1)"
}

teardown(){ rm -rf "${base}"; }

@test "el respaldo escribe data.tar.gz, SHA256SUMS y manifest.json" {
  [ -f "${run_dir}/data.tar.gz" ]
  [ -f "${run_dir}/SHA256SUMS" ]
  [ -f "${run_dir}/manifest.json" ]
}

@test "el manifiesto trae las cinco claves obligatorias y status completed" {
  run python3 -c "import json,sys;m=json.load(open(sys.argv[1]));assert all(k in m for k in ('software','version','database','sha256','status'));assert m['status']=='completed'" "${run_dir}/manifest.json"
  [ "$status" -eq 0 ]
}

@test "el .env no queda en claro dentro del respaldo" {
  run bash -c "tar -xzOf '${run_dir}/data.tar.gz' 2>/dev/null | grep -q 'valor-secreto'"
  [ "$status" -ne 0 ]
}

@test "la restauracion acepta el respaldo y deja auditoria" {
  destino_r="${base}/restaurado"
  run bash "${kit}/scripts/restaurar.sh" --respaldo "${run_dir}" --destino "${destino_r}" --audit-log "${audit}"
  [ "$status" -eq 0 ]
  [ -f "${destino_r}/datos/estado.json" ]
  grep -q "resultado=ok" "${audit}"
}

@test "un manifiesto invalido se rechaza antes de tocar el destino" {
  python3 - "${run_dir}/manifest.json" <<'PY'
import json,sys
p=sys.argv[1];m=json.load(open(p));m['status']='failed';json.dump(m,open(p,'w'))
PY
  destino_r="${base}/no-restaurado"; mkdir -p "${destino_r}"
  run bash "${kit}/scripts/restaurar.sh" --respaldo "${run_dir}" --destino "${destino_r}" --audit-log "${audit}"
  [ "$status" -ne 0 ]
  [ -z "$(ls -A "${destino_r}")" ]
}

@test "un destino no vacio se rechaza" {
  destino_r="${base}/ocupado"; mkdir -p "${destino_r}"; printf 'x' > "${destino_r}/dato.txt"
  run bash "${kit}/scripts/restaurar.sh" --respaldo "${run_dir}" --destino "${destino_r}" --audit-log "${audit}"
  [ "$status" -ne 0 ]
  [ -f "${destino_r}/dato.txt" ]
}
