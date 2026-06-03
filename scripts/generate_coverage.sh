#!/usr/bin/env bash
#
# Capture, filter and render the unit-test code coverage.
#
# Must be run from the unit-test working directory (the one containing build/).
#
# Produces, in that directory:
#   coverage.base / coverage.capture : intermediate lcov tracefiles
#   coverage.info                    : final filtered tracefile (Codecov upload,
#                                      job summary)
#   coverage/                        : HTML report (uploaded as artifact)
#
# Inputs (environment):
#   TEST_DIRECTORY         : path of the unit-test sources, always excluded
#   COVERAGE_EXCLUDE_PATHS : extra space-separated lcov glob patterns to exclude
#

set -e

# shellcheck source=/dev/null
source "$(dirname "$0")/logger.sh"

build_dir="$(realpath build/)"

gh_group "Capturing coverage"
# Coverage is captured in three steps:
#   1. --initial baseline (coverage.base): every instrumented line at 0 hits, so
#      files that were compiled but never exercised still show up in the report.
#   2. post-test capture (coverage.capture): the actual hit counts after tests.
#   3. merge of both (coverage.info): the baseline guarantees untested files are
#      counted as 0% rather than silently dropped.
#
# --ignore-errors negative: gcov 14 occasionally emits negative branch-taken
# counts in instrumented .gcda files (upstream gcov regression). lcov 2.x
# rejects them as a fatal error and breaks the coverage step even though every
# test passed. Suppress only on the capture commands -- merge/remove operate on
# the already captured .info files so they can't hit this path.
lcov --branch-coverage --ignore-errors negative --directory . -b "${build_dir}" --capture --initial -o coverage.base
lcov --branch-coverage --ignore-errors negative --directory . -b "${build_dir}" --capture -o coverage.capture
lcov --branch-coverage --directory . -b "${build_dir}" --add-tracefile coverage.base --add-tracefile coverage.capture -o coverage.info
gh_endgroup

gh_group "Filtering coverage"
# Build the exclusion list: the test directory, system headers and container-provided paths are always dropped;
# extra app-specific patterns (submodules, ...) come from the COVERAGE_EXCLUDE_PATHS input.
#'set -f' disables shell globbing so the '*' in the patterns reach lcov verbatim
# instead of being expanded against the cwd.
set -f
remove_patterns=("*/${TEST_DIRECTORY:-}/*" "/usr/*" "/opt/*")
# shellcheck disable=SC2206
remove_patterns+=(${COVERAGE_EXCLUDE_PATHS:-})
set +f
log_info "Excluding patterns: ${remove_patterns[*]}"
lcov --branch-coverage --directory . -b "${build_dir}" --remove coverage.info "${remove_patterns[@]}" -o coverage.info
gh_endgroup

gh_group "Rendering HTML report"
# Render the filtered tracefile as a browsable HTML report under coverage/,
# which the workflow then uploads as the "code-coverage" artifact.
genhtml --branch-coverage coverage.info -o coverage
gh_endgroup
