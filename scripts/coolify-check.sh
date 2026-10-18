#!/usr/bin/env bash
# Verifica que el compose activo en Coolify cumple el contrato del MVP Hefesto.
# Pensado para correr antes de cada deploy desde la rama `coolify`.
#
# Para cada compose listado en COMPOSE_FILES:
#   1. Genera un .env temporal con un valor ficticio no secreto por cada
#      variable ${VAR} requerida. Las variables de URL/host/origen usan
#      https://ejemplo.invalid.
#   2. Renderiza con `docker compose ... config --format json` (debe pasar).
#   3. Con `jq` aplica las restricciones del contrato a los servicios SIN
#      profiles y falla con `servicio: motivo` ante cualquier violación.
#
# Salida: 0 si todo cumple, 1 si hay alguna violación.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMPDIR_LOCAL="${TMPDIR:-/tmp}"
mkdir -p "$TMPDIR_LOCAL"

COMPOSE_FILES=(
  "$REPO_ROOT/compose.supabase.yaml"
)

fail() {
  echo "$1" >&2
  exit 1
}

extract_vars() {
  local compose="$1"
  # Captura ${VAR}, ${VAR:-default} y ${VAR:?error message}.
  grep -oE '\$\{[A-Z_][A-Z0-9_]*(:[-?][^}]*)?\}' "$compose" \
    | sed -E 's/^\$\{([A-Z_][A-Z0-9_]*).*$/\1/' \
    | sort -u
}

# Genera un .env temporal con valores ficticios no secretos.
# Las variables que parezcan URL/host/origen van con https://ejemplo.invalid.
generate_env() {
  local compose="$1" tmp_env="$2"
  : > "$tmp_env"
  local var
  while IFS= read -r var; do
    case "$var" in
      *URL*|*ORIGIN*|*HOST*|*SITE*)
        printf '%s=https://ejemplo.invalid\n' "$var" >> "$tmp_env"
        ;;
      *)
        printf '%s=x12345678901234567890\n' "$var" >> "$tmp_env"
        ;;
    esac
  done < <(extract_vars "$compose")
}

# Aplica las validaciones del contrato a los servicios sin profiles de un render.
# Imprime violaciones (una por línea) y devuelve 0 si está vacío, 1 si hay
# violaciones o si jq falló. Se evita `jq -e` porque jq 1.7 devuelve código 4
# cuando el filtro produce `empty` (sin output) en lugar del código 1 esperado,
# lo que vuelve inutilizable el patrón `jq -e ... select(...)`.
validate_render() {
  local render="$1" compose_label="$2"
  local tmp="$TMPDIR_LOCAL/coolify-check.violations.$$"
  local rc output
  output="$(printf '%s' "$render" | jq -r '
    .services
    | to_entries[]
    | select((.value.profiles // null) == null)
    | {
        svc: .key,
        ports: (.value.ports // [] | length),
        container_name: (.value.container_name // null),
        privileged: (.value.privileged // false),
        cap_add: (.value.cap_add // [] | length),
        devices: (.value.devices // [] | length),
        network_mode: (.value.network_mode // null),
        pid: (.value.pid // null),
        ipc: (.value.ipc // null),
        sec_unconfined: ((.value.security_opt // []) | any(. == "unconfined")),
        docker_sock: ((.value.volumes // []) | map(select(type == "object" and (.source // "") == "/var/run/docker.sock")) | length > 0),
        outside_binds: (
          (.value.volumes // [])
          | map(select(type == "object" and .type == "bind"))
          | map(.source // "")
          | map(select(type == "string"))
          | map(select(test("^/") or test("^[A-Za-z]:[\\\\/]")))
          | length > 0
        )
      }
    | [
        (if .ports > 0 then "ports no permitidos en servicios sin profiles" else empty end),
        (if .container_name != null then "container_name no permitido" else empty end),
        (if .privileged then "privileged no permitido" else empty end),
        (if .cap_add > 0 then "cap_add no permitido" else empty end),
        (if .devices > 0 then "devices no permitido" else empty end),
        (if .network_mode == "host" then "network_mode host no permitido" else empty end),
        (if .pid == "host" then "pid host no permitido" else empty end),
        (if .ipc == "host" then "ipc host no permitido" else empty end),
        (if .sec_unconfined then "security_opt unconfined no permitido" else empty end),
        (if .docker_sock then "docker.sock no permitido" else empty end),
        (if .outside_binds then "bind fuera del repo (no se permiten bind mounts absolutos en servicios sin profiles)" else empty end)
      ] as $violations
    | if ($violations | length) > 0
      then "\(.svc): \($violations | join("; "))"
      else empty
      end
  ' 2>/dev/null)"
  rc=$?
  if [[ $rc -ne 0 ]]; then
    echo "$compose_label: jq falló con código $rc (parser roto: tratar como fail-closed)" >&2
    return 1
  fi
  if [[ -z "$output" ]]; then
    return 0
  fi
  printf '%s\n' "$output" | sed "s|^|$compose_label: |" >&2
  return 1
}

# Recorre los compose y aplica el contrato.
main() {
  local compose
  for compose in "${COMPOSE_FILES[@]}"; do
    if [[ ! -f "$compose" ]]; then
      fail "Falta $compose"
    fi
    local label
    label="$(basename "$compose")"

    local tmp_env tmp
    tmp_env="$(mktemp "$TMPDIR_LOCAL/coolify-check.XXXXXX.env")"
    tmp=""
    trap "rm -f $tmp_env $tmp" EXIT

    generate_env "$compose" "$tmp_env"

    local render
    if ! render="$(docker compose --project-directory "$REPO_ROOT" \
      -f "$compose" --env-file "$tmp_env" config --format json 2>/dev/null)"; then
      fail "$label: docker compose config falló"
    fi

    if ! validate_render "$render" "$label"; then
      fail "$label: contrato Coolify incumplido"
    fi

    rm -f "$tmp_env"
  done

  echo "Coolify check OK"
}

main "$@"