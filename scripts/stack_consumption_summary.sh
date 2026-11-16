#!/usr/bin/env bash
#
# Handle the stack consumption summaries printed by Ragger (`--get-stack-consumption`):
#   merge <output> <summary>...   merge the summaries of several test groups into a single one
#   step-summary <summary> <label> write a summary into the GitHub job step summary
#

set -euo pipefail

# Per-test lines, as printed by Ragger: "<bytes> bytes  <test id>"
TEST_LINE_REGEX='^[[:space:]]*[0-9]+ bytes[[:space:]]+[^[:space:]]'

help() {
    echo "Usage:"
    echo "  $(basename "$0") merge <output> <summary>..."
    echo "  $(basename "$0") step-summary <summary> <label>"
    exit 1
}

merge() {
    local output="$1"
    shift
    local tests
    tests=$(grep -hE "${TEST_LINE_REGEX}" "$@" | sort -k3 || true)
    if [ -z "${tests}" ]; then
        echo "No stack consumption data found in: $*"
        return 0
    fi
    {
        echo "==================== stack consumption summary ===================="
        echo "${tests}"
        echo "${tests}" | awk '$1 + 0 > max || worst == "" { max = $1 + 0; worst = $3 }
            END { printf "-------------------- worst case: %d bytes  (%s) --------------------\n", max, worst }'
    } > "${output}"
}

step_summary() {
    local summary="$1"
    local label="$2"
    # Worst case line, then the per-test detail in a collapsible block
    {
        tail -n1 "${summary}"
        echo ""
        echo "<details>"
        echo "<summary>Stack consumption per test (${label})</summary>"
        echo ""
        echo "| Test | Stack |"
        echo "|------|--------------:|"
        grep -E "${TEST_LINE_REGEX}" "${summary}" |
            sed -r -e 's/^/| /' -e 's/$/ |/' -e 's/([[:digit:]]+ bytes)\s+(\S+)/\2 | \1 |/'
        echo ""
        echo "</details>"
    } >> "${GITHUB_STEP_SUMMARY}"
}

[ $# -ge 1 ] || help
command="$1"
shift
case "${command}" in
    merge)
        [ $# -ge 2 ] || help
        merge "$@"
        ;;
    step-summary)
        [ $# -eq 2 ] || help
        step_summary "$@"
        ;;
    *)
        help
        ;;
esac
