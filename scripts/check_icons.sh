#!/usr/bin/env bash

check_icon() {
	success=1
	file="$1"
	geometry="$2"
	content=$(identify -verbose "$file")

	if [[ "$geometry" != "no-check" ]]; then
		if ! echo "$content" | grep -q "Geometry: $geometry"; then
			echo "ERROR => Icon should have a $geometry geometry"
			success=0
		fi
	fi

	if echo "$content" | grep -q "Alpha"; then
		echo "ERROR => Icon should have no alpha channel"
		success=0
	fi

	if ! echo "$content" | grep -q "Colors: 2"; then
		echo "ERROR => Icon should have only 2 colors"
		success=0
	fi

	if ! echo "$content" | grep -q "0.*0.*0.*black"; then
		echo "ERROR => Icon should have the black color defined"
		success=0
	fi

	if ! echo "$content" | grep -q "255.*255.*255.*white"; then
		echo "ERROR => Icon should have the white color defined"
		success=0
	fi

	if [[ success -eq 1 ]]; then
		echo "SUCCESS => Icon \"$file\" is compliant"
	else
		echo "FAILURE =>"
		echo "identify -verbose \"$file\""
		echo "$content"
		return 1
	fi

}

get_icon_from_makefile () {
	cat "$1/Makefile" | grep "ICONNAME" | grep "$2" | cut -f2 -d'=' | sed 's/^[ \t]*//;s/[ \t]*$//'
}

repo="$1"

nanos_icon_file="$repo/$(get_icon_from_makefile "$repo" "nanos")"
nanox_icon_file="$repo/$(get_icon_from_makefile "$repo" "nanox")"

check_icon "$nanos_icon_file" "16x16"
check_icon "$nanox_icon_file" "14x14"

find "$repo/glyphs/" -type f -print0 | while IFS= read -r -d '' file; do check_icon "$file" "no-check"; done
