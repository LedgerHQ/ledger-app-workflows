#!/usr/bin/env bash
#
# Install apt packages with retry on lock contention and transient failures.
#

set -euo pipefail

exeName=$(readlink -f "$0")
dirName=$(dirname "${exeName}")

# shellcheck source=/dev/null
source "${dirName}/logger.sh"

MAX_RETRIES=3
LOCK_TIMEOUT=60
RETRY_DELAY=30
SKIP_UPDATE=false
NO_RECOMMENDS=false

help() {
    local err="${1:-}"
    [[ -n "${err}" ]] && log_error "${err}"
    echo
    echo "Usage: $(basename "${exeName}") [OPTIONS] <package>..."
    echo
    echo "  Install apt packages with retry on lock contention and transient failures."
    echo "  Automatically uses sudo when not running as root."
    echo
    echo "Options:"
    echo "  -n          Skip apt-get update (just install)"
    echo "  -r <N>      Max attempts (default: ${MAX_RETRIES})"
    echo "  -t <N>      DPkg lock timeout per attempt, in seconds (default: ${LOCK_TIMEOUT})"
    echo "  -d <N>      Delay between retries, in seconds (default: ${RETRY_DELAY})"
    echo "  -R          Pass --no-install-recommends to apt-get install"
    echo "  -h          Show this help"
    echo
    exit 1
}

while getopts ":nr:t:d:Rh" opt; do
    case ${opt} in
        n)  SKIP_UPDATE=true ;;
        r)  MAX_RETRIES="${OPTARG}" ;;
        t)  LOCK_TIMEOUT="${OPTARG}" ;;
        d)  RETRY_DELAY="${OPTARG}" ;;
        R)  NO_RECOMMENDS=true ;;
        h)  help ;;
        \?) help "Unknown option: -${OPTARG}" ;;
        : ) help "Missing argument for -${OPTARG}" ;;
    esac
done
shift $((OPTIND - 1))

[[ $# -eq 0 ]] && help "No packages specified"

SUDO=""
if [ "$(id -u)" -ne 0 ] && command -v sudo >/dev/null 2>&1; then
    SUDO="sudo"
fi

# Stop background apt services that may hold the dpkg lock on CI runners.
${SUDO} systemctl stop unattended-upgrades apt-daily.service apt-daily-upgrade.service 2>/dev/null || true

apt_run() {
    local attempt=1
    until ${SUDO} apt-get -o DPkg::Lock::Timeout="${LOCK_TIMEOUT}" "$@"; do
        if [ "${attempt}" -ge "${MAX_RETRIES}" ]; then
            log_error "apt-get $* failed after ${attempt} attempt(s)"
            return 1
        fi
        log_warning "apt-get attempt ${attempt}/${MAX_RETRIES} failed, retrying in ${RETRY_DELAY}s..."
        attempt=$((attempt + 1))
        sleep "${RETRY_DELAY}"
    done
}

if [[ "${SKIP_UPDATE}" == false ]]; then
    apt_run update
fi

INSTALL_OPTS=(-y)
[[ "${NO_RECOMMENDS}" == true ]] && INSTALL_OPTS+=(--no-install-recommends)
apt_run install "${INSTALL_OPTS[@]}" "$@"
