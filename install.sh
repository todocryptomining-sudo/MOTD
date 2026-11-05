#!/bin/bash
# MINER AI | GPU HOST - instalador / desinstalador del MOTD
#
# Uso local:
#   sudo ./install.sh
#   sudo ./install.sh --uninstall
#
# Uso remoto (GitHub):
#   curl -fsSL https://raw.githubusercontent.com/todocryptomining-sudo/miner-ai-motd/main/install.sh | sudo bash
#
# El instalador es idempotente: se puede ejecutar varias veces para actualizar.

set -Eeuo pipefail

readonly SCRIPT_VERSION="1.0.0"
readonly MOTD_FILENAME="00-miner-ai"
readonly MOTD_TARGET="/etc/update-motd.d/${MOTD_FILENAME}"
readonly STATE_DIR="/var/lib/miner-ai-motd"
readonly MARKER="# MINER_AI_MOTD"
readonly DEFAULT_REPO="todocryptomining-sudo/miner-ai-motd"
readonly DEFAULT_REF="main"

ACTION="install"
CLEAN_DEFAULTS=1
FORCE=0
REPO="${MINER_MOTD_REPO:-$DEFAULT_REPO}"
REF="${MINER_MOTD_REF:-$DEFAULT_REF}"
SOURCE=""
TEMP_FILES=()

# Scripts cosméticos de Ubuntu que duplican información o muestran anuncios.
# No se tocan avisos importantes (reinicio requerido, fin de soporte, etc.).
NOISY_SCRIPTS=(
    "00-header"
    "10-help-text"
    "50-motd-news"
    "90-updates-available"
    "91-contract-ua-esm-status"
)

if [[ -t 1 ]]; then
    NC=$'\033[0m'
    BLUE=$'\033[34m'
    GREEN=$'\033[32m'
    YELLOW=$'\033[33m'
    RED=$'\033[31m'
else
    NC=''
    BLUE=''
    GREEN=''
    YELLOW=''
    RED=''
fi

log() {
    printf '%s[miner-ai-motd]%s %s\n' "$BLUE" "$NC" "$*"
}

ok() {
    printf '%s[miner-ai-motd]%s %s%s%s\n' "$BLUE" "$NC" "$GREEN" "$*" "$NC"
}

warn() {
    printf '%s[miner-ai-motd]%s %s%s%s\n' "$BLUE" "$NC" "$YELLOW" "$*" "$NC" >&2
}

die() {
    printf '%s[miner-ai-motd]%s %s%s%s\n' "$BLUE" "$NC" "$RED" "$*" "$NC" >&2
    exit 1
}

usage() {
    cat <<EOF
MINER AI | GPU HOST - MOTD para hosts GPU (Ubuntu Server / Vast.ai)

Uso:
  sudo ./install.sh [opciones]

Opciones:
  --repo OWNER/REPO   Repositorio de GitHub del que descargar el MOTD.
                      Por defecto: ${DEFAULT_REPO}
  --ref REF           Rama, tag o commit. Por defecto: ${DEFAULT_REF}
  --keep-defaults     No desactiva los mensajes estándar de Ubuntu
                      (00-header, 10-help-text, 50-motd-news, etc.).
  --force             Sobrescribe un ${MOTD_FILENAME} existente que no sea
                      de este instalador (se guarda una copia de seguridad).
  --uninstall         Elimina el MOTD y restaura los scripts desactivados.
  -h, --help          Muestra esta ayuda.
  -V, --version       Muestra la versión.

Instalación local:
  git clone https://github.com/${DEFAULT_REPO}.git
  cd miner-ai-motd
  sudo ./install.sh

Instalación remota:
  curl -fsSL https://raw.githubusercontent.com/${DEFAULT_REPO}/${DEFAULT_REF}/install.sh | sudo bash

Desinstalación:
  sudo ./install.sh --uninstall
  curl -fsSL https://raw.githubusercontent.com/${DEFAULT_REPO}/${DEFAULT_REF}/install.sh | sudo bash -s -- --uninstall

Variables de entorno para el banner (opcionales):
  MINER_MOTD_TITLE, MINER_MOTD_WIDTH, MINER_MOTD_COLOR, MINER_MOTD_ASCII,
  MINER_MOTD_SYSTEM, MINER_MOTD_DISK_PATH
EOF
}

cleanup() {
    local file
    if (( ${#TEMP_FILES[@]} > 0 )); then
        for file in "${TEMP_FILES[@]}"; do
            rm -f -- "$file" 2>/dev/null || true
        done
    fi
}
trap cleanup EXIT

# ─────────────────────────────────────────────────────────────────────────────
# Argumentos
# ─────────────────────────────────────────────────────────────────────────────
while (( $# > 0 )); do
    case "$1" in
        --repo)
            [[ $# -ge 2 ]] || die "Falta el valor de --repo"
            REPO=$2
            shift 2
            ;;
        --repo=*)
            REPO=${1#*=}
            shift
            ;;
        --ref)
            [[ $# -ge 2 ]] || die "Falta el valor de --ref"
            REF=$2
            shift 2
            ;;
        --ref=*)
            REF=${1#*=}
            shift
            ;;
        --keep-defaults)
            CLEAN_DEFAULTS=0
            shift
            ;;
        --force)
            FORCE=1
            shift
            ;;
        --uninstall)
            ACTION="uninstall"
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        -V|--version)
            printf 'miner-ai-motd %s\n' "$SCRIPT_VERSION"
            exit 0
            ;;
        *)
            die "Opción desconocida: $1 (usa --help)"
            ;;
    esac
done

if (( EUID != 0 )); then
    die "Se requieren permisos de root. Ejecuta: sudo bash install.sh"
fi

if [[ ! -d /etc/update-motd.d ]]; then
    die "No existe /etc/update-motd.d. Este sistema no parece usar update-motd (Ubuntu/Debian)."
fi

if [[ ! $REPO =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]]; then
    die "Repositorio inválido: '$REPO'. Formato esperado: usuario/repositorio"
fi

if [[ ! $REF =~ ^[A-Za-z0-9._/-]+$ ]]; then
    die "Referencia inválida: '$REF'"
fi

# ─────────────────────────────────────────────────────────────────────────────
# Origen del archivo MOTD
# ─────────────────────────────────────────────────────────────────────────────
download_motd() {
    local url="https://raw.githubusercontent.com/${REPO}/${REF}/motd/${MOTD_FILENAME}"
    local tmp

    tmp=$(mktemp "${TMPDIR:-/tmp}/miner-ai-motd.XXXXXX") || die "No se pudo crear un archivo temporal"
    TEMP_FILES+=("$tmp")
    SOURCE=$tmp

    log "Descargando ${url}"
    if command -v curl >/dev/null 2>&1; then
        curl --proto '=https' --tlsv1.2 -fsSL --retry 3 --connect-timeout 10 \
            "$url" -o "$tmp" || die "No se pudo descargar el MOTD desde GitHub"
    elif command -v wget >/dev/null 2>&1; then
        wget -qO "$tmp" "$url" || die "No se pudo descargar el MOTD desde GitHub"
    else
        die "Se necesita curl o wget para la instalación remota"
    fi
}

resolve_source() {
    local local_source

    if [[ -n ${BASH_SOURCE[0]:-} ]]; then
        SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" 2>/dev/null && pwd) || SCRIPT_DIR=$(pwd)
    else
        SCRIPT_DIR=$(pwd)
    fi
    local_source="${SCRIPT_DIR}/motd/${MOTD_FILENAME}"

    if [[ -f $local_source ]]; then
        SOURCE=$local_source
        log "Usando archivo local: ${SOURCE}"
    else
        download_motd
    fi
}

prepare_source() {
    local normalized

    [[ -f $SOURCE ]] || die "No se encontró el archivo del MOTD"
    if [[ ! -s $SOURCE ]]; then
        die "El archivo del MOTD está vacío"
    fi

    # Tolerancia a finales de línea CRLF (clonado/descarga desde Windows).
    if grep -q $'\r' "$SOURCE" 2>/dev/null; then
        normalized=$(mktemp "${TMPDIR:-/tmp}/miner-ai-motd.XXXXXX") || die "No se pudo crear un archivo temporal"
        TEMP_FILES+=("$normalized")
        sed 's/\r$//' "$SOURCE" > "$normalized"
        SOURCE=$normalized
    fi

    if ! grep -Fqx "$MARKER" "$SOURCE"; then
        die "El archivo descargado no parece ser el MOTD de MINER AI (falta el marcador)"
    fi
}

# ─────────────────────────────────────────────────────────────────────────────
# Estado / scripts del sistema
# ─────────────────────────────────────────────────────────────────────────────
disable_noisy_scripts() {
    local name file
    local disabled_file="${STATE_DIR}/disabled-scripts"

    touch "$disabled_file"

    for name in "${NOISY_SCRIPTS[@]}"; do
        file="/etc/update-motd.d/${name}"
        if [[ -x $file ]]; then
            chmod -x "$file"
            if ! grep -Fqx "$name" "$disabled_file" 2>/dev/null; then
                printf '%s\n' "$name" >> "$disabled_file"
            fi
            log "Desactivado ${name} (se restaurará al desinstalar)"
        fi
    done

    if [[ -s $disabled_file ]]; then
        sort -u -o "$disabled_file" "$disabled_file"
    else
        rm -f "$disabled_file"
    fi
}

restore_disabled_scripts() {
    local name file
    local disabled_file="${STATE_DIR}/disabled-scripts"

    if [[ ! -f $disabled_file ]]; then
        return
    fi

    while IFS= read -r name; do
        [[ -n $name ]] || continue
        if [[ ! $name =~ ^[A-Za-z0-9._-]+$ ]]; then
            warn "Entrada inválida en ${disabled_file}: ${name}"
            continue
        fi
        file="/etc/update-motd.d/${name}"
        if [[ -f $file ]]; then
            chmod +x "$file"
            log "Reactivado ${name}"
        fi
    done < "$disabled_file"
}

# ─────────────────────────────────────────────────────────────────────────────
# Instalación
# ─────────────────────────────────────────────────────────────────────────────
install_motd() {
    local backup="${STATE_DIR}/previous-${MOTD_FILENAME}"

    resolve_source
    prepare_source

    install -d -m 0755 "$STATE_DIR"

    if [[ -e $MOTD_TARGET ]] && ! grep -Fqx "$MARKER" "$MOTD_TARGET" 2>/dev/null; then
        if (( FORCE == 0 )); then
            die "Ya existe ${MOTD_TARGET} y no fue creado por este instalador. Usa --force para respaldarlo y reemplazarlo."
        fi
        if [[ ! -e $backup ]]; then
            cp -a -- "$MOTD_TARGET" "$backup"
            printf 'yes\n' > "${STATE_DIR}/previous-exists"
            warn "Copia de seguridad creada: ${backup}"
        fi
    fi

    install -m 0755 "$SOURCE" "$MOTD_TARGET"
    if ! grep -Fqx "$MARKER" "$MOTD_TARGET"; then
        die "La instalación no se completó correctamente"
    fi
    ok "MOTD instalado en ${MOTD_TARGET}"

    if (( CLEAN_DEFAULTS )); then
        disable_noisy_scripts
    else
        warn "Se conservan los mensajes estándar de Ubuntu (--keep-defaults)"
    fi

    if command -v update-motd >/dev/null 2>&1; then
        update-motd --force >/dev/null 2>&1 || true
    fi

    printf '\n'
    log "Vista previa:"
    printf '\n'

    if [[ -n ${SUDO_USER:-} && ${SUDO_USER} != "root" ]] && command -v sudo >/dev/null 2>&1; then
        sudo -u "$SUDO_USER" -- "$MOTD_TARGET" || true
    else
        "$MOTD_TARGET" || true
    fi

    printf '\n'
    ok "Instalación completada. Se aplicará en el próximo inicio de sesión SSH."
    log "Prueba manual: ${MOTD_TARGET}"
    log "Desinstalar:   sudo bash install.sh --uninstall"
}

# ─────────────────────────────────────────────────────────────────────────────
# Desinstalación
# ─────────────────────────────────────────────────────────────────────────────
uninstall_motd() {
    local backup="${STATE_DIR}/previous-${MOTD_FILENAME}"
    local found=0

    if [[ -e $MOTD_TARGET ]] && ! grep -Fqx "$MARKER" "$MOTD_TARGET" 2>/dev/null && (( FORCE == 0 )); then
        die "El archivo ${MOTD_TARGET} no parece ser de este instalador. Usa --force si realmente quieres eliminarlo."
    fi

    if [[ -e $MOTD_TARGET ]]; then
        found=1
        rm -f -- "$MOTD_TARGET"
        ok "Eliminado ${MOTD_TARGET}"
    fi

    if [[ -f $backup ]]; then
        if [[ ! -e $MOTD_TARGET ]]; then
            mv -- "$backup" "$MOTD_TARGET"
            ok "Restaurado el ${MOTD_FILENAME} anterior desde la copia de seguridad"
        else
            warn "No se restaura la copia anterior porque ${MOTD_TARGET} sigue existiendo"
        fi
        rm -f "${STATE_DIR}/previous-exists"
    fi

    restore_disabled_scripts
    rm -f "${STATE_DIR}/disabled-scripts"
    rmdir "$STATE_DIR" 2>/dev/null || true

    if (( found == 0 )) && [[ ! -d $STATE_DIR ]]; then
        log "No había una instalación de MINER AI MOTD."
    else
        ok "Desinstalación completada."
        log "Se aplicará en el próximo inicio de sesión SSH."
    fi
}

if [[ $ACTION == "uninstall" ]]; then
    uninstall_motd
else
    install_motd
fi
