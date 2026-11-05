#!/usr/bin/env bash
# Pruebas de humo del MOTD. No requieren GPU ni root.
# Uso: bash tests/smoke.sh

set -Eeuo pipefail

ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
MOTD="${ROOT}/motd/00-miner-ai"
TMP=$(mktemp -d "${TMPDIR:-/tmp}/miner-ai-motd-test.XXXXXX")
trap 'rm -rf "$TMP"' EXIT

CHECKS=0
OUTPUT=''

fail() {
    printf 'FAIL: %s\n' "$*" >&2
    exit 1
}

assert_contains() {
    local text=$1
    local needle=$2
    local name=$3
    if [[ $text != *"$needle"* ]]; then
        printf '--- salida ---\n%s\n--------------\n' "$text" >&2
        fail "$name: no se encontró: $needle"
    fi
    CHECKS=$((CHECKS + 1))
}

assert_not_contains() {
    local text=$1
    local needle=$2
    local name=$3
    if [[ $text == *"$needle"* ]]; then
        fail "$name: no debería contener: $needle"
    fi
    CHECKS=$((CHECKS + 1))
}

# Crea una copia del MOTD cuyo PATH empieza por un directorio de mocks.
make_test_copy() {
    local mockdir=$1
    local output=$2
    sed "s|^export PATH=.*|export PATH=\"${mockdir}:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin\"|" \
        "$MOTD" > "$output"
}

run_motd() {
    local script=$1
    local errfile="${TMP}/stderr"

    OUTPUT=$(MINER_MOTD_COLOR=never bash "$script" 2>"$errfile") || {
        printf '%s\n' "$OUTPUT" >&2
        cat "$errfile" >&2
        fail "el MOTD terminó con error"
    }

    if [[ -s $errfile ]]; then
        cat "$errfile" >&2
        fail "el MOTD escribió en stderr"
    fi
}

# ─────────────────────────────────────────────────────────────────────────────
# 1. Salida básica sin GPU (mocks que fallan)
# ─────────────────────────────────────────────────────────────────────────────
mkdir -p "${TMP}/nogpu"
cat > "${TMP}/nogpu/nvidia-smi" <<'MOCK'
#!/bin/bash
exit 1
MOCK
cat > "${TMP}/nogpu/systemctl" <<'MOCK'
#!/bin/bash
exit 1
MOCK
cat > "${TMP}/nogpu/docker" <<'MOCK'
#!/bin/bash
exit 1
MOCK
cat > "${TMP}/nogpu/pgrep" <<'MOCK'
#!/bin/bash
exit 1
MOCK
chmod +x "${TMP}/nogpu/"*

make_test_copy "${TMP}/nogpu" "${TMP}/motd-nogpu"
run_motd "${TMP}/motd-nogpu"

assert_contains "$OUTPUT" 'MINER AI | GPU HOST' 'título'
assert_contains "$OUTPUT" 'Sistema    :' 'sistema'
assert_contains "$OUTPUT" 'Host       :' 'host'
assert_contains "$OUTPUT" 'Usuario    :' 'usuario'
assert_contains "$OUTPUT" 'ESTADO DEL SERVIDOR' 'sección estado'
assert_contains "$OUTPUT" 'SERVICIOS' 'sección servicios'
assert_contains "$OUTPUT" 'CPU        :' 'cpu'
assert_contains "$OUTPUT" 'RAM        :' 'ram'
assert_contains "$OUTPUT" 'GPU        :' 'gpu'
assert_contains "$OUTPUT" 'GPU Temp   :' 'gpu temp'
assert_contains "$OUTPUT" 'GPU Power  :' 'gpu power'
assert_contains "$OUTPUT" 'Disco      :' 'disco'
assert_contains "$OUTPUT" 'Uptime     :' 'uptime'
assert_contains "$OUTPUT" 'Vast.ai    :' 'vast'
assert_contains "$OUTPUT" 'Docker     :' 'docker'
assert_contains "$OUTPUT" 'NVIDIA     :' 'nvidia'
assert_contains "$OUTPUT" 'Vast.ai    : ● OFFLINE' 'vast offline'
assert_contains "$OUTPUT" 'Docker     : ● ' 'docker status'

# ─────────────────────────────────────────────────────────────────────────────
# 2. Salida con GPU y servicios simulados
# ─────────────────────────────────────────────────────────────────────────────
mkdir -p "${TMP}/gpu"
cat > "${TMP}/gpu/nvidia-smi" <<'MOCK'
#!/bin/bash
if [[ "$*" == *"name,temperature.gpu,power.draw,power.limit"* ]]; then
    printf 'NVIDIA GeForce RTX 4090, 42, 78, 450\n'
    printf 'NVIDIA GeForce RTX 4090, 38, 70, 450\n'
    exit 0
fi
exit 1
MOCK
cat > "${TMP}/gpu/systemctl" <<'MOCK'
#!/bin/bash
[[ "${1:-}" == "is-active" ]] || exit 1
for arg in "$@"; do
    case "$arg" in
        vastai_kaalia|vastai_kaalia.service|docker|docker.service) exit 0 ;;
    esac
done
exit 1
MOCK
cat > "${TMP}/gpu/docker" <<'MOCK'
#!/bin/bash
case "${1:-}" in
    info) exit 0 ;;
    ps) printf 'vastai_kaalia\n'; exit 0 ;;
esac
exit 1
MOCK
cat > "${TMP}/gpu/pgrep" <<'MOCK'
#!/bin/bash
exit 1
MOCK
chmod +x "${TMP}/gpu/"*

make_test_copy "${TMP}/gpu" "${TMP}/motd-gpu"
run_motd "${TMP}/motd-gpu"

assert_contains "$OUTPUT" 'NVIDIA GeForce RTX 4090 (x2)' 'multi-gpu'
assert_contains "$OUTPUT" 'GPU Temp   : 42 °C' 'temperatura máxima'
assert_contains "$OUTPUT" 'GPU Power  : 148 W / 900 W' 'potencia total'
assert_contains "$OUTPUT" 'Vast.ai    : ● ONLINE' 'vast online'
assert_contains "$OUTPUT" 'Docker     : ● ACTIVE' 'docker active'
assert_contains "$OUTPUT" 'NVIDIA     : ● DETECTED' 'nvidia detected'

# ─────────────────────────────────────────────────────────────────────────────
# 3. Modo ASCII y título personalizado
# ─────────────────────────────────────────────────────────────────────────────
OUTPUT=$(MINER_MOTD_COLOR=never MINER_MOTD_ASCII=1 bash "$MOTD" 2>"${TMP}/stderr") || fail "modo ASCII falló"
assert_contains "$OUTPUT" '+----' 'marco ASCII'
assert_not_contains "$OUTPUT" '╔' 'sin Unicode'

OUTPUT=$(MINER_MOTD_COLOR=never MINER_MOTD_TITLE='RIG 04 | GPU HOST' bash "$MOTD" 2>"${TMP}/stderr") || fail "título personalizado falló"
assert_contains "$OUTPUT" 'RIG 04 | GPU HOST' 'título personalizado'

printf 'OK: %d comprobaciones superadas\n' "$CHECKS"
