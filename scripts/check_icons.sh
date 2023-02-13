#!/usr/bin/env bash

set -e

check_icon() (
    error=0
    file="$1"
    geometry="$2"
    content=$(identify -verbose "$file")

    if [[ "$geometry" != "no-check" ]]; then
        if ! echo "$content" | grep -q "Geometry: $geometry"; then
            echo "ERROR => Icon should have a $geometry geometry"
            error=1
        fi
    fi

    if echo "$content" | grep -q "Alpha"; then
        echo "ERROR => Icon should have no alpha channel"
        error=1
    fi

    if ! echo "$content" | grep -q "Colors: 2"; then
        echo "ERROR => Icon should have only 2 colors"
        error=1
    fi

    if ! echo "$content" | grep -q "0.*0.*0.*black"; then
        echo "ERROR => Icon should have the black color defined"
        error=1
    fi

    if ! echo "$content" | grep -q "255.*255.*255.*white"; then
        echo "ERROR => Icon should have the white color defined"
        error=1
    fi

    if [[ error -eq 0 ]]; then
        echo "SUCCESS => Icon \"$file\" is compliant"
    else
        echo "FAILURE =>"
        echo "identify -verbose \"$file\""
        echo "$content"
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
        if [[ "$md5sum" == "1603e6b90d3ae4afa9e3667008363705" || "$md5sum" == "d14ded9f690020fd878074393fa5bf2d" ]]; then
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
    iconname_makefile=$(grep -Rl --include="*Makefile*" "^[[:blank:]]*ICONNAME" "$repo")
    grep "ICONNAME" "$iconname_makefile" | grep "$device_name" | cut -f2 -d'=' | sed 's/^[ \t]*//;s/[ \t]*$//'
)

main() (
    repo="$1"
    repo_name="$2"
    error=0

    nanos_icon_file="$repo/$(get_icon_from_makefile "$repo" "nanos")"
    nanox_icon_file="$repo/$(get_icon_from_makefile "$repo" "nanox")"

    if echo "$repo_name" | grep -q "app-boilerplate"; then
        echo "Icon uniqueness check skipped for Boilerplate"
    else
        check_is_not_boilerplate_icon "$nanos_icon_file" || error=1
        check_is_not_boilerplate_icon "$nanox_icon_file" || error=1
    fi

    check_icon "$nanos_icon_file" "16x16" || error=1
    check_icon "$nanox_icon_file" "14x14" || error=1

    while IFS= read -r -d '' file; do
        check_icon "$file" "no-check" || error=1
    done < <(find "$repo/glyphs/" -type f -print0)

    return "$error"
)

main "$@"
