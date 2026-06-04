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
#   coverage.xml                     : Cobertura report (PR coverage comment)
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
# test passed.
#
# --rc geninfo_unexecuted_blocks=1: gcov 14 reports unexecuted blocks on
# non-branch lines that still carry a non-zero hit count.
# This rc resets those blocks to zero -- it fixes the data at the source,
# as lcov itself recommends, rather than masking the inconsistency.
#
# --ignore-errors inconsistent: gcov 14 also produces data the rc above cannot
# fix, where a function is hit while no line it contains is. lcov 2.x
# enables check_data_consistency by default and only demotes this to a WARNING
# when *writing* a tracefile, but treats it as a FATAL error when *reading* one
# back. The inconsistency is carried over into every derived tracefile, so each
# step that re-reads one (--add-tracefile merge, --remove filtering, genhtml
# rendering) hits it in turn and needs the flag.
#
# --ignore-errors gcov: a compiled-but-unexercised translation unit can yield a
# .gcno with no matching .gcda ("GCOV did not produce any data"); harmless.
#
# Each category is listed twice on purpose: the first occurrence demotes the
# fatal error to a (non-fatal) warning, the second suppresses the warning
# message as well (lcov convention) to keep the step logs clean. None of this
# changes the coverage numbers.
lcov --branch-coverage --rc geninfo_unexecuted_blocks=1 --ignore-errors negative,negative,gcov,gcov,inconsistent,inconsistent --directory . -b "${build_dir}" --capture --initial -o coverage.base
lcov --branch-coverage --rc geninfo_unexecuted_blocks=1 --ignore-errors negative,negative,gcov,gcov,inconsistent,inconsistent --directory . -b "${build_dir}" --capture -o coverage.capture
lcov --branch-coverage --ignore-errors inconsistent,inconsistent --directory . -b "${build_dir}" --add-tracefile coverage.base --add-tracefile coverage.capture -o coverage.info
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
# --ignore-errors unused: the exclusion list is deliberately defensive and
# generic (/usr/*, /opt/*, plus app-specific COVERAGE_EXCLUDE_PATHS). A given
# app/build legitimately may not compile anything under one of those paths, so
# the pattern matches nothing. lcov 2.x treats an unused exclude pattern as a
# fatal error (exit 25) -- harmless here, so it must not break the step.
# Categories doubled to also silence the warning text (see capture step above).
lcov --branch-coverage --ignore-errors inconsistent,inconsistent,unused,unused --directory . -b "${build_dir}" --remove coverage.info "${remove_patterns[@]}" -o coverage.info
gh_endgroup

gh_group "Rendering HTML report"
# Render the filtered tracefile as a browsable HTML report under coverage/,
# which the workflow then uploads as the "code-coverage" artifact.
genhtml --branch-coverage --ignore-errors inconsistent,inconsistent coverage.info -o coverage
gh_endgroup

gh_group "Generating Cobertura report"
# Convert the filtered tracefile to Cobertura XML (coverage.xml) for tooling
# that does not read lcov -- here, the PR coverage-comment jobs. lcov_cobertura
# is installed by a workflow step; the conversion is best-effort so a missing
# dependency or a failure never drops the HTML report or the Codecov upload
# (the surrounding `set -e` would otherwise abort).
# -b makes the XML source paths relative to the repo root for readable output.
cobertura_base="${GITHUB_WORKSPACE:-$(realpath .)}"
if command -v lcov_cobertura >/dev/null; then
    lcov_cobertura coverage.info -b "${cobertura_base}" -o coverage.xml \
        || log_warning "lcov_cobertura failed; coverage.xml not generated"
else
    log_warning "lcov_cobertura not installed; coverage.xml not generated"
fi
gh_endgroup
