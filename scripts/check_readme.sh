#!/usr/bin/env bash

repo="$1"
success=1

if [[ ! -f "$repo/README.md" ]]; then
	echo "ERROR => No README.md found in your project"
	success=0
fi

if [[ ! -s "$repo/README.md" ]]; then
	echo "ERROR => The README.md must not be empty"
	success=0
fi

if echo "$repo" | grep -q "app-boilerplate"; then
	echo "Readme check skipped for Boilerplate"
else
	if grep -q -i "^#.*boilerplate" "$repo/README.md"; then
		echo "ERROR => The README.md should mention your application, not boilerplate"
		success=0
	fi
fi

if [[ success -eq 1 ]]; then
	echo "SUCCESS => Customization from Boilerplate is compliant"
else
	echo "FAILURE =>"
	echo "cat \"$repo/README.md\""
	cat "$repo/README.md"
	return 1
fi
