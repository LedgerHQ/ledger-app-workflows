#!/usr/bin/env bash

set -e

# shellcheck source=scripts/logger.sh
source "$(dirname "$0")/logger.sh"

main() (
    error=0
    repo="$1"
    repo_name="$2"

    # Find the main Makefile of the app
    makefile=$(grep -Rl --include="*Makefile*" "^[[:blank:]]*APPNAME" "$repo")

    if ! grep -q "^listvariants:" "$makefile"; then
        log_error "The Makefile does not contain the 'listvariants' rule"
        error=1
    fi

    if echo "$repo_name" | grep -q "app-boilerplate"; then
        log_warning "APPNAME and VARIANT checks skipped for Boilerplate"
    else
        while IFS= read -r line; do
            if echo "$line" | grep -q -i "boilerplate"; then
                log_error "APPNAME should refer to your application's name, not boilerplate"
                error=1
            fi
        done < <(grep "^[[:blank:]]*APPNAME" "$makefile")

        if grep "echo VARIANTS" "$makefile" | grep -q "BOL"; then
            log_error "VARIANT name should refer to your coin ticker, not boilerplate's BOL"
            error=1
        fi
    fi

    if grep -q "HAVE_BOLOS_UX" "$makefile"; then
        log_error "The Makefile contains an outdated flag 'HAVE_BOLOS_UX'"
        error=1
    fi

    if [[ error -eq 0 ]]; then
        log_success "Makefile \"$makefile\" is compliant"
    else
        log_error_no_header "At least one error has been found"
        log_error_no_header "To check the Makefile content, run \"cat '$makefile'\""
    fi

    return "$error"
)

main "$@"
