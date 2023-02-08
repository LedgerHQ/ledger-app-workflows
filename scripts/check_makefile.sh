#!/usr/bin/env bash

repo="$1"
success=1

makefile=$(grep -Rl --include="*Makefile*" "^[[:blank:]]*APPNAME" "$repo")

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
	return 1
fi
