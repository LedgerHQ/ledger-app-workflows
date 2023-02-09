#!/usr/bin/env bash

set -e

repo="$1"
repo_name="$2"

success=1

# Find the main Makefile of the app
makefile=$(grep -Rl --include="*Makefile*" "^[[:blank:]]*APPNAME" "$repo")

if echo "$repo_name" | grep -q "app-boilerplate"; then
	echo "APPNAME and VARIANT checks skipped for Boilerplate"
else
	while IFS= read -r line; do
		if echo $line | grep -q -i "boilerplate"; then
			echo "ERROR => APPNAME should refer to your application's name, not boilerplate"
			success=0
		fi
	done < <(grep "^[[:blank:]]*APPNAME" "$makefile")

	if grep "echo VARIANTS" "$makefile" | grep -q "BOL"; then
		echo "ERROR => VARIANT name should refer to your coin ticker, not boilerplate's BOL"
		success=0
	fi
fi

if cat "$makefile" | grep -q "HAVE_BOLOS_UX"; then
	echo "ERROR => The Makefile contains an outdated flag 'HAVE_BOLOS_UX'"
	success=0
fi

if ! cat "$makefile" | grep -q "^listvariants:"; then
	echo "ERROR => The Makefile does not contain the 'listvariants' rule"
	success=0
fi

if [[ success -eq 1 ]]; then
	echo "SUCCESS => Makefile \"$makefile\" is compliant"
else
	echo "FAILURE =>"
	echo "cat \"$makefile\""
	cat "$makefile"
	exit 1
fi
