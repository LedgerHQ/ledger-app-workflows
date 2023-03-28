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
        "nanosp")
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
        log_error "Icon '$file' for '$device' should have a '$geometry' geometry"
        error=1
    else
        log_success "Icon '$file' for '$device' has a '$geometry' geometry"
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

get_icon_from_makefile() (
    repo="$1"
    device_name="$2"

    # Get the Makefile that contains the ICONNAME definitions, copy it and remove its includes and logs
    iconname_makefile=$(grep -Rl --exclude-dir="deps" --include="*Makefile*" "^[[:blank:]]*ICONNAME" "$repo" | head -n 1)
    if [[ -z "$iconname_makefile" ]]; then
        >&2 log_error "No Makefile with ICONNAME definition found"
        return 1
    fi
    tmp_makefile="/tmp/iconname_makefile.mk"
    cp "$iconname_makefile" "$tmp_makefile"
    sed -i "/^include/d" "$tmp_makefile"
    sed -i "/^\$(info/d" "$tmp_makefile"
    sed -i "/^\$(error/d" "$tmp_makefile"

    echo "include $tmp_makefile" > "$repo/Makefile_dumper.mk"
    echo "dump_ICONNAME:" >> "$repo/Makefile_dumper.mk"
    echo -e "\t@echo \$(ICONNAME)" >> "$repo/Makefile_dumper.mk"

    target_name="TARGET_$(echo "$device_name" | sed 's,nanosp,nanos2,g' | tr "[:lower:]" "[:upper:]")"
    icon=$(make BOLOS_SDK="none" TARGET_NAME="$target_name" --no-print-directory -C "$repo" -f "Makefile_dumper.mk" dump_ICONNAME)
    if [[ -z "$icon" ]]; then
        >&2 log_error "No icon found for '$device_name'"
        return 1
    fi

    icon_name="$(basename "$icon")"
    find "$repo" -type f -name "$icon_name" | head -n1
)

check_icon() (
    error=0
    repo="$1"
    repo_name="$2"
    device="$3"

    file="$(get_icon_from_makefile "$repo" "$device")"
    if [[ ! -f "$file" ]]; then
        log_error "Icon file '$file' not found for '$device'"
        return 1
    fi

    if echo "$repo_name" | grep -q "app-boilerplate"; then
        log_warning "Skipping icon uniqueness check for Boilerplate"
    else
        check_is_not_boilerplate_icon "$file" || error=1
    fi

    check_geometry "$file" "$device" || error=1

    check_glyph "$file" || error=1

    return "$error"
)

main() (
    repo="$1"
    repo_name="$2"
    target_devices="$3"

    error=0

    # Read in two times to strip delimiters first and spaces and empty elements second
    IFS=',[]"' read -r -a devices_array <<< "$target_devices"
    IFS=' ' read -r -a devices_array <<< "${devices_array[@]}"
    for device in "${devices_array[@]}"; do
        check_icon "$repo" "$repo_name" "$device" || error=1
    done

    # Scan all .gif or .bmp files in sub directories containing the word "glyph"
    while IFS= read -r -d '' file; do
        check_glyph "$file" || error=1
    done < <(find "$repo" -path '*glyph*' \( -name '*.bmp' -o -name '*.gif' \) -type f -print0)

    if [[ "$error" -eq 1 ]]; then
        log_error_no_header "At least one error has been found. Please refer to the documentation for how to design graphical elements"
        log_error_no_header "https://developers.ledger.com/docs/embedded-app/design-requirements/"
    fi
    return "$error"
)

main "$@"
