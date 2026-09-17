#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

APP_NAME=template

read -sp "BOARD SSH PASSWORD/PASSPHRASE: " PSK
echo

REMOTE_USER=debian
REMOTE_HOST=192.168.0.113
REMOTE_DIR=/home/debian/template

DO_CLEAN=0
DO_DEPLOY=0
DO_RUN=0

MODE="debug"

usage() {
    cat <<'USAGE'
usage: build.sh [debug|release] [clean] [--deploy] [--run]

  debug         configure with the Debug preset (default)
  release       configure with the Release preset
  clean         remove this preset's build directory first
  --deploy      rsync the binary to the board after a successful build
  --run         deploy, then execute it on the board over ssh
  -h, --help    show this help

Target settings come from REMOTE_USER, REMOTE_HOST and REMOTE_DIR.
USAGE
}

for arg in "$@"; do
    case "$arg" in
        debug)     MODE="debug" ;;
        release)   MODE="release" ;;
        clean)     DO_CLEAN=1 ;;
        --deploy)  DO_DEPLOY=1 ;;
        --run)     DO_RUN=1; DO_DEPLOY=1 ;;
        -h|--help) usage; exit 0 ;;
        *)
            echo "error: unknown argument '${arg}'" >&2
            usage >&2
            exit 2
            ;;
    esac
done

setup_askpass() {
    ASKPASS_HELPER="$(mktemp -t build-askpass.XXXXXXXX)"
    trap 'rm -f "${ASKPASS_HELPER}"' EXIT INT TERM
    cat > "${ASKPASS_HELPER}" <<'HELPER'
#!/usr/bin/env bash
printf '%s\n' "${BUILD_PSK}"
HELPER
    chmod 700 "${ASKPASS_HELPER}"
    export BUILD_PSK="${PSK}"
    export SSH_ASKPASS="${ASKPASS_HELPER}"
    export SSH_ASKPASS_REQUIRE=force
}

BUILD_DIR="build/${MODE}"

if [ "${DO_CLEAN}" -eq 1 ]; then
    echo "cleaning ${BUILD_DIR}"
    rm -rf "${BUILD_DIR}"
fi

mkdir -p "${BUILD_DIR}"

GO_FLAGS=(-o "${BUILD_DIR}/${APP_NAME}")
if [ "${MODE}" = "debug" ]; then
    # DISABLE OPTIMIZATIONS FOR DELVE DEBUG
    GO_FLAGS+=(-gcflags="all=-N -l")
else
    # STRIP SYMBOLS + NO DWARF => SMALL BINARIES
    GO_FLAGS+=(-ldflags="-s -w")
fi

GOOS=linux GOARCH=riscv64 go build "${GO_FLAGS[@]}"

echo "built: ${BUILD_DIR}/${APP_NAME}"

if [ "${DO_DEPLOY}" -eq 1 ] && [ -n "${PSK}" ]; then
    setup_askpass
fi

if [ "${DO_DEPLOY}" -eq 1 ]; then
    echo "deploying to ${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_DIR}/"
    if ! rsync -avz "${BUILD_DIR}/${APP_NAME}" "${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_DIR}/"; then
        echo >&2
        exit 1
    fi
fi

if [ "${DO_RUN}" -eq 1 ]; then
    echo "running ${REMOTE_DIR}/${APP_NAME} on ${REMOTE_HOST}"
    ssh "${REMOTE_USER}@${REMOTE_HOST}" "echo && ${REMOTE_DIR}/${APP_NAME} && echo"
fi