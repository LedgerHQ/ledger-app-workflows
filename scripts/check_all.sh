#!/usr/bin/env bash
#
# script to run Guideline_enforcer checks
#

exeName=$(readlink -f "$0")
dirName=$(dirname "${exeName}")

# shellcheck source=/dev/null
source "${dirName}/logger.sh"

VERBOSE=false
IS_RUST=false

# All available checks ('manifest' must be the first one)
ALL_CHECKS="manifest icons app_load_params makefile readme scan"

#===============================================================================
#
#     help - Prints script help and usage
#
#===============================================================================
# shellcheck disable=SC2154  # var is referenced but not assigned
help() {
    local err="$1"

    [[ -n "${err}" ]] && log_error "${err}"

    echo
    echo "Usage: ${exeName} <options>"
    echo
    echo "Options:"
    echo
    echo "  -c <check>  : Requested check from (${ALL_CHECKS}). Default is all."
    echo "  -d <dir>    : Database directory"
    echo "  -a <dir>    : Application directory"
    echo "  -b <dir>    : Application build directory"
    echo "  -m <file>   : Manifest (file or directory)"
    echo "  -t <device> : Targeted device"
    echo "  -r          : Rust application"
    echo "  -v          : Verbose mode"
    echo "  -h          : Displays this help"
    echo
    exit 1
}

#===============================================================================
#
#     Parsing parameters
#
#===============================================================================

while getopts ":a:b:c:d:m:t:rvh" opt; do
    case ${opt} in
        a)  APP_DIR=${OPTARG}   ;;
        b)  BUILD_DIR=${OPTARG} ;;
        c)  REQUESTED_CHECK=${OPTARG} ;;
        d)  DATABASE_DIR=${OPTARG} ;;
        m)  MANIFEST=${OPTARG}  ;;
        t)  TARGET=${OPTARG}    ;;
        r)  IS_RUST=true ;;
        v)  VERBOSE=true ;;
        h)  help ;;

        \?) echo "Unknown option: -${OPTARG}" >&2; exit 1;;
        : ) echo "Missing option argument for -${OPTARG}" >&2; exit 1;;
        * ) echo "Unimplemented option: -${OPTARG}" >&2; exit 1;;
    esac
done

#===============================================================================
#
#     Checking parameters
#
#===============================================================================

# Check if the requested check is valid
if [[ -n ${REQUESTED_CHECK} ]]; then
    [[ $(wc -w <<< "${REQUESTED_CHECK}") -ne 1 ]] && help "Too many checks requested!"
    [[ ! "${ALL_CHECKS}" =~ ${REQUESTED_CHECK} ]] && help "Unknown check: ${REQUESTED_CHECK}"
fi
if [[ (-z ${REQUESTED_CHECK}) || ("${REQUESTED_CHECK}" =~ (manifest|scan)) ]]; then
    # Check BUILD_DIR environment variable
    [[ -z ${BUILD_DIR} ]] && help "Missing mandatory parameter 'Build directory'!"
fi

if [[ "${REQUESTED_CHECK}" != app_load_params ]]; then
    # Check if APP_DIR is given in parameter
    [[ -z "${APP_DIR}" ]] && help "Missing mandatory parameter 'Application directory'!"
    # Check if REPO_NAME is given in parameter
    REPO_NAME=$(basename "$(git -C "${APP_DIR}" remote get-url origin)")
    REPO_NAME=${REPO_NAME%%.*}
fi

# Init verbose options
make_option=(-j -C "${APP_DIR}/${BUILD_DIR}")
if [[ ${VERBOSE} == false ]]; then
    make_option+=(-s --no-print-directory)
    verbose_mode=(-q)
fi

# Check if TARGET is already setup
if [[ (-z ${TARGET}) && ("${REQUESTED_CHECK}" =~ (manifest|scan)) ]]; then
    TARGET=$(make "${make_option[@]}" listinfo 2>/dev/null | grep -w TARGET | cut -d'=' -f2)
fi

# Check if MANIFEST is given in parameter
if [[ -z ${MANIFEST} ]]; then
    if [[ -z ${TARGET} ]]; then
        MANIFEST_FILE="/tmp/manifests/manifest.json"
    else
        MANIFEST_FILE="/tmp/manifests/manifest_${TARGET}.json"
    fi
    MANIFEST_DIR=$(dirname "${MANIFEST_FILE}")
    # Remove the directory if it already exists
    [[ -d "${MANIFEST_DIR}" ]] && rm -rf "${MANIFEST_DIR}"
    mkdir -p "${MANIFEST_DIR}"
else
    if [[ -d "${MANIFEST}" ]]; then
        MANIFEST_FILE="${MANIFEST}/manifest.json"
    else
        MANIFEST_FILE="${MANIFEST}"
    fi
    MANIFEST_DIR=$(dirname "${MANIFEST_FILE}")
fi

if [[ (-z ${REQUESTED_CHECK}) || ("${REQUESTED_CHECK}" == app_load_params) ]]; then
    if [[ -z "${DATABASE_DIR}" ]]; then
        # Check if DATABASE_DIR is already present
        DATABASE_DIR="/tmp/ledger-app-database"
        git clone "${verbose_mode[@]}" https://github.com/LedgerHQ/ledger-app-database.git "${DATABASE_DIR}"
    fi
fi

#===============================================================================
#
#     log functions
#
#===============================================================================
BG_TITLE="\e[48;6;3;1;44m"
FG_TITLE="\e[38;5;44m"

(( STEP=1 ))
log_step() {
    echo
    _log_colored_line "$BG_WARNING" "[STEP ${STEP}]: " "$FG_WARNING" "$1"
    (( STEP++ ))
}

log_title() {
    echo
    _log_colored_line "$BG_TITLE" "Starting: " "$FG_TITLE" "$1"
}

#===============================================================================
#
#     step function
#
#===============================================================================

call_step() {
    local step="$1"

    case ${step} in
        "manifest")
            if [[ "${IS_RUST}" == true ]]; then
                COMMAND="(cd ${APP_DIR} && python ${dirName}/cargo_metadata_dump.py --device ${TARGET} --app_build_path ${BUILD_DIR} --json_path ${MANIFEST_FILE})"
            else
                COMMAND="(cd ${APP_DIR} && python ${dirName}/makefile_dump.py --app_build_path ${BUILD_DIR} --json_path ${MANIFEST_FILE})"
            fi
            ;;
        "icons")
            COMMAND="${dirName}/check_icons.sh ${APP_DIR} ${REPO_NAME} ${MANIFEST_DIR}"
            ;;
        "app_load_params")
            COMMAND="python ${DATABASE_DIR}/scripts/app_load_params_check.py --database_path ${DATABASE_DIR}/app-load-params-db.json --app_manifests_path ${MANIFEST_DIR}"
            ;;
        "makefile")
            COMMAND="${dirName}/check_makefile.sh ${APP_DIR} ${REPO_NAME} ${MANIFEST_DIR}"
            ;;
        "readme")
            COMMAND="${dirName}/check_readme.sh ${APP_DIR} ${REPO_NAME}"
            ;;
        "scan")
            if [[ "${IS_RUST}" == true ]]; then
                COMMAND="(cd ${APP_DIR}/${BUILD_DIR} && cargo +$RUST_NIGHTLY clippy --target ${TARGET/nanosp/nanosplus} -- -Dwarnings)"
            else
                COMMAND="make ${make_option[*]} ENABLE_SDK_WERROR=1 scan-build 2>/dev/null"
            fi
            ;;
        * ) echo "Unimplemented step: ${step}" >&2; exit 1;;
    esac

    if [[ "${step}" == manifest ]]; then
        log_step "Get ${step}"
    else
        log_step "Check ${step}"
    fi

    [[ "${VERBOSE}" == true ]] && echo "Running: ${COMMAND}"
    eval "${COMMAND}"
    err=$?
    if [[ ${err} -ne 0 ]]; then
        log_error "Check ${step} failed"
        exit 1
    fi
}

#===============================================================================
#
#     Main
#
#===============================================================================

if [[ -z "${TARGET}" ]]; then
    log_title "Running Guideline_enforcer checks"
else
    log_title "Running Guideline_enforcer checks for '${TARGET}'"
fi

if [[ -z ${REQUESTED_CHECK} ]]; then
    REQUESTED_CHECK="${ALL_CHECKS}"
else
    # 1st mandatory step to retrieve the app configuration if directory is empty
    if [[ ("${REQUESTED_CHECK}" =~ (icons|app_load_params|makefile) ) && ( ! $( ls -A "${MANIFEST_DIR}")) ]]; then
        call_step "manifest"
    fi
fi

# Run requested checks
for check in ${REQUESTED_CHECK}; do
    call_step "${check}"
done

echo
if [[ -z "${TARGET}" ]]; then
    log_success "Successfully ran Guideline_enforcer checks"
else
    log_success "Successfully ran Guideline_enforcer checks for '${TARGET}'"
fi
