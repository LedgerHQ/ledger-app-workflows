#!/usr/bin/env bash

set -e

# shellcheck source=scripts/logger.sh
source "$(dirname "$0")/logger.sh"

check_geometry() (
    error=0
    file="$1"
    device="$2"

    case "$device" in
        "nanos")
            geometry="16x16"
            ;;
        "nanox")
            geometry="14x14"
            ;;
        "nanos2")
            geometry="14x14"
            ;;
        "stax")
            geometry="32x32"
            ;;
        *)
            log_error "Device '$device' not recognized"
            return 1
            ;;
    esac

    if ! identify -verbose "$file" | grep -q "Geometry: $geometry"; then
        log_error "Icon '$file' used for '$device' should have a '$geometry' geometry"
        error=1
    else
        log_success "Icon '$file' used for '$device' has a correct '$geometry' geometry"
    fi

    return "$error"
)

check_glyph() (
    error=0
    file="$1"

    log_info "Checking glyph file '$file'"

    extension=$(basename "$file" | cut -d'.' -f2)
    if [[ "$extension" != "gif" && "$extension" != "bmp" ]]; then
        log_error "Glyph extension should be .gif or .bmp, not '.$extension'";
        return 1
    fi

    content=$(identify -verbose "$file")

    if echo "$content" | grep -q "Alpha"; then
        log_error "Glyph should have no alpha channel"
        error=1
    fi

    if ! echo "$content" | grep -q "Colors: 2"; then
        log_error "Glyph should have only 2 colors"
        error=1
    fi

    if ! echo "$content" | grep -q "0.*0.*0.*black"; then
        log_error "Glyph should have the black color defined"
        error=1
    fi

    if ! echo "$content" | grep -q "255.*255.*255.*white"; then
        log_error "Glyph should have the white color defined"
        error=1
    fi

    # Be somewhat tolerant to different possible wordings for depth "1 bit" "1-bit" "8/1 bit" etc
    if ! echo "$content" | grep -q "Depth: \(8/\)\?1.bit"; then
        log_error "Glyph should have 1 bit depth"
        error=1
    fi

    if [[ error -eq 0 ]]; then
        log_success "Glyph '$file' is compliant"
    else
        log_error_no_header "To check the glyph content, run \"identify -verbose '$file'\""
    fi

    return "$error"
)

check_is_not_boilerplate_icon() (
    file="$1"

    if echo "$file" | grep -q "boilerplate"; then
        log_error "A custom menu icon must be provided, not boilerplate icon '$file'"
        return 1
    else
        md5sum=$(md5sum "$file" | cut -f1 -d' ')
        if [[ "$md5sum" == "c818a2ac5d4e36bb333c3f8f07a42f03" || "$md5sum" == "a905db408ef828bd200a0603a5a7c64a" || "$md5sum" == "fbe4d9f0512224bb3e139189e21e4541" ]]; then
            log_error "A custom menu icon must be provided, not renamed boilerplate icon '$file'"
            return 1
        else
            return 0
        fi
    fi
)

check_icon() (
    error=0
    repo_name="$1"
    device="$2"
    file="$3"

    if echo "$repo_name" | grep -q "app.*boilerplate"; then
        log_warning "Skipping icon uniqueness check for Boilerplate"
    else
        check_is_not_boilerplate_icon "$file" || error=1
    fi

    check_geometry "$file" "$device" || error=1

    check_glyph "$file" || error=1

    return "$error"
)

main() (
    error=0
    repo="$1"
    repo_name="$2"
    manifests_dir="$3"

    all_glyph_files=""
    declare -A icons_and_devices

    # Parse all manifest files
    manifests_list=$(find "$manifests_dir" -type f -name "*.json")
    while IFS= read -r manifest; do
        log_info "Checking manifest $manifest"

        build_directory="$(cat "$manifest" | jq ".BUILD_DIRECTORY" | sed 's/"//g')"
        # Remove leading './' if present
        build_directory=$(echo "$build_directory" | sed 's,^./,,g')
        log_info "Build directory is $build_directory"

        # Parse all variants of each manifest to grab all icons and glyphs
        variants_list=$(cat "$manifest" | jq ".VARIANTS | keys[]")
        while IFS= read -r variant; do
            log_info "Checking variant $variant"

            # Get the icon and the device used for this variant, we'll check later
            device="$(cat "$manifest" | jq ".VARIANTS.$variant.TARGET" | sed 's/"//g')"
            icon="$(cat "$manifest" | jq ".VARIANTS.$variant.ICONNAME" | sed 's/"//g')"
            # If the icon path is absolute, resolve it locally
            icon=$(echo "$icon" | sed "s,^/.*/$build_directory/,./$build_directory/,g")
            # Store the couple icon/device as key of an associative array to auto remove duplicates from variants
            icons_and_devices["$icon;$device"]=1

            # Get the glyphs used for this variant, we'll check later otherwise we would check many times each file
            all_glyph_files+="$(cat "$manifest" | jq ".VARIANTS.$variant.GLYPH_FILES" | sed 's/"//g') "
        done < <(echo "$variants_list")

    done < <(echo "$manifests_list")

    log_info "All manifests checked"

    # Check each icon
    for icon_and_device in "${!icons_and_devices[@]}"; do
        icon="$(echo "$icon_and_device" | cut -d';' -f1)"
        device="$(echo "$icon_and_device" | cut -d';' -f2)"
        check_icon "$repo_name" "$device" "$repo/$icon" || error=1
    done

    # As we scanned for all devices and all variants, we can have a lot of duplicates for glyphs. Filter out duplicates and empty lines
    all_glyph_files_no_duplicates="$(echo "$all_glyph_files" | tr ' ' '\n' | sort -u | grep .)"
    while IFS= read -r file; do
        # Skip SDK glyphs
        if [[ "$file" != "/opt/"*"-secure-sdk/"* ]]; then
            check_glyph "$repo/$build_directory/$file" || error=1
        fi
    done < <(echo "$all_glyph_files_no_duplicates")

    if [[ "$error" -eq 1 ]]; then
        log_error_no_header "At least one error has been found. Please refer to the documentation for how to design graphical elements"
        log_error_no_header "https://developers.ledger.com/docs/embedded-app/design-requirements/"
    fi
    return "$error"
)

main "$@"
