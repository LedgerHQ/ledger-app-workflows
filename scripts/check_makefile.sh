#!/usr/bin/env bash

set -e

main() (
    repo="$1"
    repo_name="$2"

    error=0

    # Find the main Makefile of the app
    makefile=$(grep -Rl --include="*Makefile*" "^[[:blank:]]*APPNAME" "$repo")

    if echo "$repo_name" | grep -q "app-boilerplate"; then
        echo "APPNAME and VARIANT checks skipped for Boilerplate"
    else
        while IFS= read -r line; do
            if echo "$line" | grep -q -i "boilerplate"; then
                echo "ERROR => APPNAME should refer to your application's name, not boilerplate"
                error=1
            fi
        done < <(grep "^[[:blank:]]*APPNAME" "$makefile")

        if grep "echo VARIANTS" "$makefile" | grep -q "BOL"; then
            echo "ERROR => VARIANT name should refer to your coin ticker, not boilerplate's BOL"
            error=1
        fi
    fi

    if grep -q "HAVE_BOLOS_UX" "$makefile"; then
        echo "ERROR => The Makefile contains an outdated flag 'HAVE_BOLOS_UX'"
        error=1
    fi

    if ! grep -q "^listvariants:" "$makefile"; then
        echo "ERROR => The Makefile does not contain the 'listvariants' rule"
        error=1
    fi

    if [[ error -eq 0 ]]; then
        echo "SUCCESS => Makefile \"$makefile\" is compliant"
    else
        echo "FAILURE =>"
        echo "cat \"$makefile\""
        cat "$makefile"
    fi

    return "$error"
)

main "$@"
