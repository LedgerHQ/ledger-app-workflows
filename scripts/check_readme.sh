#!/usr/bin/env bash

set -e

# shellcheck source=scripts/logger.sh
source "$(dirname "$0")/logger.sh"

main() (
    error=0
    repo="$1"
    repo_name="$2"

    if [[ ! -f "$repo/README.md" ]]; then
        log_error "No README.md found in your project"
        error=1
    fi

    if [[ ! -s "$repo/README.md" ]]; then
        log_error "The README.md must not be empty"
        error=1
    fi

    if echo "$repo_name" | grep -q "app.*boilerplate"; then
        log_warning "Readme check skipped for Boilerplate"
    else
        if grep -q -i "^#.*boilerplate" "$repo/README.md"; then
            log_error "The README.md should mention your application, not boilerplate"
            error=1
        fi
    fi

    if [[ error -eq 0 ]]; then
        log_success "Readme customization is sufficient"
    else
        log_error_no_header "At least one error has been found"
        log_error_no_header "To check the Readme content, run \"cat '$repo/README.md'\""
    fi

    return "$error"
)

main "$@"
