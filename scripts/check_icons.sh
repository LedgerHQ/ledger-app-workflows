#!/usr/bin/env bash

set -e

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
            echo "ERROR => Device '$device' not recognized"
            return 1
            ;;
    esac

    if ! identify -verbose "$file" | grep -q "Geometry: $geometry"; then
        echo "ERROR => Icon '$file' for '$device' should have a '$geometry' geometry"
        error=1
    else
        echo "SUCCESS => Icon '$file' for '$device' has a '$geometry' geometry"
    fi

    return "$error"
)

check_glyph() (
    error=0
    file="$1"

    echo "INFO => Checking glyph file '$file'"

    extension=$(basename "$file" | cut -d'.' -f2)
    if [[ "$extension" != "gif" && "$extension" != "bmp" ]]; then
        echo "ERROR => Glyph extension should be .gif or .bmp, not '.$extension'";
        return 1
    fi

    content=$(identify -verbose "$file")

    if echo "$content" | grep -q "Alpha"; then
        echo "ERROR => Glyph should have no alpha channel"
        error=1
    fi

    if [[ "$extension" == "gif" ]]; then
        if ! echo "$content" | grep -q "Colors: 2"; then
            echo "ERROR => Glyph should have only 2 colors"
            error=1
        fi

        if ! echo "$content" | grep -q "0.*0.*0.*black"; then
            echo "ERROR => Glyph should have the black color defined"
            error=1
        fi

        if ! echo "$content" | grep -q "255.*255.*255.*white"; then
            echo "ERROR => Glyph should have the white color defined"
            error=1
        fi
    else
        if ! echo "$content" | grep -q "Depth: 1 bits-per-pixel component"; then
            echo "ERROR => Glyph should 1 bit depth"
            error=1
        fi
    fi

    if [[ error -eq 0 ]]; then
        echo "SUCCESS => Glyph '$file' is compliant"
    else
        echo "FAILURE => run \"identify -verbose '$file'\""
    fi

    return "$error"
)

check_is_not_boilerplate_icon() (
    file="$1"

    if echo "$file" | grep -q "boilerplate"; then
        echo "ERROR => A custom menu icon must be provided, not boilerplate icon '$file'"
        return 1
    else
        md5sum=$(md5sum "$file" | cut -f1 -d' ')
        if [[ "$md5sum" == "c818a2ac5d4e36bb333c3f8f07a42f03" || "$md5sum" == "a905db408ef828bd200a0603a5a7c64a" || "$md5sum" == "fbe4d9f0512224bb3e139189e21e4541" ]]; then
            echo "ERROR => A custom menu icon must be provided, not renamed boilerplate icon '$file'"
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
    iconname_makefile=$(grep -Rl --include="*Makefile*" "^[[:blank:]]*ICONNAME" "$repo")
    if [[ -z "$iconname_makefile" ]]; then
        >&2 echo "ERROR => No Makefile with ICONNAME definition found"
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

    target_name="TARGET_${device_name^^}"
    icon=$(make BOLOS_SDK="none" TARGET_NAME="$target_name" --no-print-directory -C "$repo" -f "Makefile_dumper.mk" dump_ICONNAME)
    if [[ -z "$icon" ]]; then
        >&2 echo "ERROR => No icon found for '$device_name'"
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
        echo "ERROR => Icon file '$file' not found for '$device'"
        return 1
    fi

    if echo "$repo_name" | grep -q "app-boilerplate"; then
        echo "INFO => Skipping icon uniqueness check for Boilerplate"
    else
        check_is_not_boilerplate_icon "$file" || error=1
    fi

    check_geometry "$file" "$device" || error=1

    check_glyph "$file" || error=1
)

main() (
    repo="$1"
    repo_name="$2"
    error=0

    check_icon "$repo" "$repo_name" "nanos" || error=1
    check_icon "$repo" "$repo_name" "nanox" || error=1
    check_icon "$repo" "$repo_name" "nanos2" || error=1
    check_icon "$repo" "$repo_name" "stax" || error=1

    glyph_src_dir_name="glyphs"
    custom_glyph_src_dir_name=$(grep -R --include="*Makefile*" "^[[:blank:]]*GLYPH_SRC_DIR" "$repo" | cut -d'=' -f2 | sed 's/^[ \t]*//;s/[ \t]*$//')
    if [[ -n "$custom_glyph_src_dir_name" ]]; then
        glyph_src_dir_name="$custom_glyph_src_dir_name"
    fi
    glyph_src_dir="$(find "$repo" -name "$glyph_src_dir_name" -type d)"
    if [[ ! -d "$glyph_src_dir" ]]; then
        echo "ERROR => Glyph source directory '$glyph_src_dir' not found"
    fi

    while IFS= read -r -d '' file; do
        check_glyph "$file" || error=1
    done < <(find "$glyph_src_dir/" -type f -print0)

    if [[ "$error" -eq 1 ]]; then
        echo "At least one error has been found. Please refer to the documentation for how to design graphical elements"
        echo "https://developers.ledger.com/docs/embedded-app/design-requirements/"
    fi
    return "$error"
)

main "$@"
