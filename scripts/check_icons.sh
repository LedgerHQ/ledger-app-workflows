#!/usr/bin/env bash

set -e

# shellcheck source=/dev/null
source "$(dirname "$0")/logger.sh"


check_geometry() (
    file="$1"
    device="$2"
    kind="$3"   # "icon" or "glyph": icons and glyphs don't share the same geometry constraints

    # Icons must have a single exact geometry per device, while glyphs are
    # allowed to match any value of a per-device set.
    case "${kind}" in
        icon)
            case "${device}" in
                nanos)
                    geometries="16x16"
                    ;;
                nanox | nanos2)
                    geometries="14x14"
                    ;;
                stax | apex | apex_m | apex_p)
                    geometries="32x32"
                    ;;
                flex)
                    geometries="40x40"
                    ;;
                *)
                    log_error "Device '${device}' not recognized"
                    return 1
                    ;;
            esac
            ;;
        glyph)
            case "${device}" in
                nanos)
                    geometries="16x16"
                    ;;
                nanox | nanos2)
                    geometries="14x14 16x16"
                    ;;
                apex | apex_m | apex_p)
                    geometries="24x24 32x32 48x48"
                    ;;
                flex)
                    geometries="40x40 64x64"
                    ;;
                stax)
                    geometries="32x32 64x64"
                    ;;
                *)
                    log_error "Device '${device}' not recognized"
                    return 1
                    ;;
            esac
            ;;
        *)
            log_error "Geometry kind '${kind}' not recognized"
            return 1
            ;;
    esac

    # Check if the file matches at least one of the expected geometries
    actual_geometry=$(identify -format "%wx%h" "${file}")

    for geometry in ${geometries}; do
        if [[ "${actual_geometry}" == "${geometry}" ]]; then
            log_success "${kind} '${file}' used for '${device}' has a correct '${geometry}' geometry"
            return 0
        fi
    done

    # If we get here, no geometry matched
    log_error "${kind} '${file}' used for '${device}' should have one of these geometries: ${geometries}, but has '${actual_geometry}'"
    return 1
)

check_glyph() (
    error=0
    file="$1"
    device="$2"
    kind="${3:-glyph}"   # geometry kind to check: "icon" or "glyph"

    log_info "Checking glyph file '${file}'"

    extension=$(basename "${file}" | cut -d'.' -f2)
    if [[ "${extension}" != "gif" && "${extension}" != "bmp" && "${extension}" != "png" ]]; then
        log_error "Glyph extension should be '.gif', '.bmp', or '.png', not '.${extension}'";
        return 1
    fi

    content=$(identify -verbose "${file}")

    if echo "${content}" | grep -q "Alpha"; then
        log_error "Glyph should have no alpha channel"
        error=1
    fi

    # Determine whether the device's screen only supports monochrome.
    # Nano and Apex screens are monochrome only, while Stax and Flex also support grayscale.
    # The device name itself is validated by check_geometry.
    case "${device}" in
        nanos | nanox | nanos2 | apex | apex_m | apex_p)
            monochrome=1
            ;;
        *)
            monochrome=0
            ;;
    esac

    # Monochrome picture
    if echo "${content}" | grep -q "Type: Bilevel"; then
        log_info "Monochrome image type"
        if ! echo "${content}" | grep -q "Colors: 2"; then
            log_error "Glyph should have only 2 colors"
            error=1
        fi

        # get the color lines
        color_lines=$(echo "${content}" | grep -A3 "Colors: " | tail -n -2)

        if ! echo "${color_lines}" | grep -q " #000000 "; then
            log_error "Glyph should have the black color defined"
            error=1
        fi

        if ! echo "${color_lines}" | grep -q " #FFFFFF "; then
            log_error "Glyph should have the white color defined"
            error=1
        fi

        # Be somewhat tolerant to different possible wordings for depth "1 bit" "1-bit" "8/1 bit" etc
        if ! echo "${content}" | grep -q "Depth: \(8/\)\?1.bit"; then
            log_error "Glyph should have 1 bit depth"
            error=1
        fi

    # Grayscale picture
    elif echo "${content}" | grep -q "Type: Grayscale"; then
        log_info "Grayscale image type"

        # If device only has monochrome screens: grayscale is not allowed
        if [[ "${monochrome}" -eq 1 ]]; then
            log_error "${kind} '${file}' used for '${device}' must be monochrome, not grayscale"
            error=1
        fi

        # Use rev + cut f1 trick to grab last word ie the value of field 'Colors'
        colors_nb=$(echo "${content}" | grep "Colors: " | rev | cut -d' ' -f1 | rev)
        if [[ "${colors_nb}" -gt 16 ]]; then
            log_error "4bpp glyphs can't have more than 16 colors, ${colors_nb} found"
            error=1
        fi

        # Be somewhat tolerant to different possible wordings for depth "8 bit" "8-bit" "8/8 bit" etc
        if ! echo "${content}" | grep -q "Depth: \(8/\)\?8.bit"; then
            log_error "Glyph should have 8 bits depth"
            error=1
        fi

    else
        log_error "Glyph should be Monochrome or Grayscale"
        error=1
    fi

    check_geometry "${file}" "${device}" "${kind}" || error=1

    if [[ "${error}" -eq 0 ]]; then
        log_success "Glyph '${file}' is compliant"
    else
        log_error_no_header "To check the glyph content, run \"identify -verbose '${file}'\""
    fi

    return "${error}"
)

check_is_not_boilerplate_icon() (
    file="$1"

    if echo "${file}" | grep -q "boilerplate"; then
        log_error "A custom menu icon must be provided, not boilerplate icon '${file}'"
        return 1
    else
        md5sum=$(md5sum "${file}" | cut -f1 -d' ')
        if [[ "${md5sum}" == "c818a2ac5d4e36bb333c3f8f07a42f03" || "${md5sum}" == "a905db408ef828bd200a0603a5a7c64a" || "${md5sum}" == "fbe4d9f0512224bb3e139189e21e4541" ]]; then
            log_error "A custom menu icon must be provided, not renamed boilerplate icon '${file}'"
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

    if echo "${repo_name}" | grep -q "app.*boilerplate"; then
        log_warning "Skipping icon uniqueness check for Boilerplate"
    else
        check_is_not_boilerplate_icon "${file}" || error=1
    fi

    check_glyph "${file}" "${device}" "icon" || error=1

    return "${error}"
)

main() (
    icon_errors=0
    glyph_errors=0
    icons_count=0
    glyphs_count=0
    repo="$1"
    repo_name="$2"
    manifests_dir="$3"
    target="$4"

    declare -A icons_and_devices
    declare -A glyphs_and_devices

    # Parse all manifest files
    if [[ -n "${target}" ]]; then
        manifests_list="${manifests_dir}/manifest_${target}.json"
    else
        manifests_list=$(find "${manifests_dir}" -type f -name "*.json")
    fi
    while IFS= read -r manifest; do
        gh_group "  Checking manifest ${manifest}"
        log_info "Checking manifest ${manifest}"

        build_directory="$(cat "${manifest}" | jq ".BUILD_DIRECTORY" | sed 's/"//g')"
        # Remove leading './' if present
        build_directory=$(echo "${build_directory}" | sed 's,^./,,g')
        log_info "Build directory is ${build_directory}"

        # Parse all variants of each manifest to grab all icons and glyphs
        variants_list=$(cat "${manifest}" | jq ".VARIANTS | keys[]")
        while IFS= read -r variant; do
            log_info "Checking variant ${variant}"

            # Get the icon and the device used for this variant, we'll check later
            device="$(cat "${manifest}" | jq ".VARIANTS.${variant}.TARGET" | sed 's/"//g')"
            icon="$(cat "${manifest}" | jq ".VARIANTS.${variant}.ICONNAME" | sed 's/"//g')"
            # If the icon path is absolute, convert it to a relative path from build_directory
            icon=$(echo "${icon}" | sed "s,^/.*/${build_directory}/,,g")
            # Store the couple icon/device as key of an associative array to auto remove duplicates from variants
            icons_and_devices["${icon};${device}"]=1

            # Get the glyphs used for this variant, we'll check later otherwise we would check many times each file
            glyphs="$(cat "${manifest}" | jq ".VARIANTS.${variant}.GLYPH_FILES" | sed 's/"//g')"
            for glyph in $glyphs; do
                # If the glyph path is absolute, convert it to a relative path from build_directory
                # It can be the case for Stax where the ICONNAME is put in the GLYPH_FILES
                glyph=$(echo "${glyph}" | sed "s,^/.*/${build_directory}/,,g")
                # Store the couple glyph/device to check geometry later
                glyphs_and_devices["${glyph};${device}"]=1
            done
        done < <(echo "${variants_list}")
        gh_endgroup

    done < <(echo "${manifests_list}")

    log_info "All manifests checked"

    gh_group "  Checking icons"
    # Check each icon
    for icon_and_device in "${!icons_and_devices[@]}"; do
        icons_count=$((icons_count + 1))
        icon="$(echo "${icon_and_device}" | cut -d';' -f1)"
        device="$(echo "${icon_and_device}" | cut -d';' -f2)"
        img_file="${repo}/${build_directory}/${icon}"
        if ! [[ -f "${img_file}" ]]; then
            log_error "Icon file '${img_file}' Doesn't exist!"
            icon_errors=$((icon_errors + 1))
            continue
        fi
        check_icon "${repo_name}" "${device}" "${img_file}" || icon_errors=$((icon_errors + 1))
    done
    gh_endgroup

    gh_group "  Checking glyphs"
    # Check each glyph with its associated device(s)
    for glyph_and_device in "${!glyphs_and_devices[@]}"; do
        glyph="$(echo "${glyph_and_device}" | cut -d';' -f1)"
        device="$(echo "${glyph_and_device}" | cut -d';' -f2)"
        # Skip SDK glyphs
        if [[ "${glyph}" != "/opt/"*"-secure-sdk/"* ]]; then
            glyphs_count=$((glyphs_count + 1))
            img_file="${repo}/${build_directory}/${glyph}"
            if ! [[ -f "${img_file}" ]]; then
                log_error "Glyph file '${img_file}' Doesn't exist!"
                glyph_errors=$((glyph_errors + 1))
                continue
            fi
            check_glyph "${img_file}" "${device}" "glyph" || glyph_errors=$((glyph_errors + 1))
        fi
    done
    gh_endgroup

    total_errors=$((icon_errors + glyph_errors))
    if [[ "${total_errors}" -ne 0 ]]; then
        log_error_no_header "${total_errors} error(s) found:"
        [[ "${icon_errors}" -ne 0 ]] && log_error_no_header "  -> ${icon_errors} in icons (out of ${icons_count} checked)"
        [[ "${glyph_errors}" -ne 0 ]] && log_error_no_header "  -> ${glyph_errors} in glyphs (out of ${glyphs_count} checked)"
        log_error_no_header "Please refer to the documentation for how to design graphical elements"
        log_error_no_header "https://developers.ledger.com/docs/embedded-app/design-requirements/"
        return 1
    fi

    log_success "All graphical elements are compliant: ${icons_count} icon(s) and ${glyphs_count} glyph(s) checked"
    return 0
)

main "$@"
