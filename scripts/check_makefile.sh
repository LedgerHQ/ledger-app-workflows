#!/usr/bin/env bash

set -e

# shellcheck source=scripts/logger.sh
source "$(dirname "$0")/logger.sh"

main() (
    error=0
    repo="$1"
    repo_name="$2"
    manifests_dir="$3"
    target="$4"

    declare -A variants_array
    declare -A appnames_array
    declare -A is_allowed_makefile_array

    if [[ "$repo_name" == "app-boilerplate" || "$repo_name" == "app-plugin-boilerplate" ]]; then
        is_boilerplate=true
    else
        is_boilerplate=false
    fi

    # Parse all manifest files
    if [[ -n "${target}" ]]; then
        manifests_list="${manifests_dir}/manifest_${target}.json"
    else
        manifests_list=$(find "$manifests_dir" -type f -name "*.json")
    fi
    while IFS= read -r manifest; do
        log_info "Checking manifest $manifest"

        # Parse all variants of each manifest to grab all appnames and variants
        variants_list=$(cat "$manifest" | jq ".VARIANTS | keys[]" | sed 's/"//g')
        while IFS= read -r variant; do
            log_info "Checking variant $variant"
            appname="$(cat "$manifest" | jq ".VARIANTS.\"$variant\".APPNAME" | sed 's/"//g')"

            # Store the variant as key of an associative array to auto remove duplicates from variants
            variants_array["$variant"]=1
            appnames_array["$appname"]=1
        done < <(echo "$variants_list")

        is_allowed_makefile=$(jq -r '.IS_ALLOWED_MAKEFILE' "$manifest")
        is_allowed_makefile_array["$manifest"]=$is_allowed_makefile
    done < <(echo "$manifests_list")

    log_info "All manifests checked"

    # Check each appname
    for appname in "${!appnames_array[@]}"; do
        if "$is_boilerplate"; then
            log_success "APPNAME '$appname' is valid for Boilerplate"
        else
            if [[ "$appname" == "boilerplate" || "$appname" == "Boilerplate" ]]; then
                log_error "APPNAME should refer to your application's name, not '$appname'"
                error=1
            else
                log_success "APPNAME name '$appname' is valid"
            fi
        fi
    done

    # Check each variant
    for variant in "${!variants_array[@]}"; do
        if "$is_boilerplate"; then
            log_success "VARIANT name '$variant' is valid for Boilerplate"
        else
            if [[ "$variant" == "BOL" || "$variant" == "boilerplate" || "$variant" == "Boilerplate" ]]; then
                log_error "VARIANT name should refer to your coin ticker, not boilerplate's '$variant'"
                error=1
            else
                log_success "VARIANT name '$variant' is valid"
            fi
        fi
    done

    # check if makefile included in the app makefile is allowed (bypass for rust apps - empty array)
    for manifest in "${!is_allowed_makefile_array[@]}"; do
        if [ "${is_allowed_makefile_array[$manifest]}" == "false" ]; then
            log_error "Makefile $manifest is not standard."
            log_error "Please refer to the Boilerplate app makefile available here : https://github.com/LedgerHQ/app-boilerplate/blob/master/Makefile"
            error=1
        else
            log_success "Makefile $manifest is standard"
        fi
    done

    if grep -qRl --include="*Makefile*" "HAVE_BOLOS_UX" "$repo"; then
        log_error "The Makefile contains an outdated flag 'HAVE_BOLOS_UX'"
        error=1
    fi

    if [[ error -eq 0 ]]; then
        log_success "The Makefile is compliant"
    else
        log_error_no_header "At least one error has been found"
        log_error_no_header "Please check the Makefile content"
    fi
    return "$error"
)

main "$@"
