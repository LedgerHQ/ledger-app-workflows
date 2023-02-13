#!/usr/bin/env bash

set -e

main() (
    repo="$1"
    repo_name="$2"
    error=0

    if [[ ! -f "$repo/README.md" ]]; then
        echo "ERROR => No README.md found in your project"
        error=1
    fi

    if [[ ! -s "$repo/README.md" ]]; then
        echo "ERROR => The README.md must not be empty"
        error=1
    fi

    if echo "$repo_name" | grep -q "app-boilerplate"; then
        echo "Readme check skipped for Boilerplate"
    else
        if grep -q -i "^#.*boilerplate" "$repo/README.md"; then
            echo "ERROR => The README.md should mention your application, not boilerplate"
            error=1
        fi
    fi

    if [[ error -eq 0 ]]; then
        echo "SUCCESS => Readme customization is sufficient"
    else
        echo "FAILURE =>"
        echo "cat \"$repo/README.md\""
        cat "$repo/README.md"
    fi

    return "$error"
)

main "$@"
