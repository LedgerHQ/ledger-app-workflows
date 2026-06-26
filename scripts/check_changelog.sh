#!/usr/bin/env bash

set -e

# shellcheck source=/dev/null
source "$(dirname "$0")/logger.sh"

# Determine the reference to diff against (base branch).
# In CI, the caller provides the PR base SHA explicitly.
# Locally, we try to guess the default branch the current work will be merged into.
guess_base_ref() {
    local repo="$1"
    local candidate

    # Default remote branch (e.g. 'origin/main') as set by 'git clone'
    if candidate=$(git -C "${repo}" symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null); then
        echo "${candidate}"
        return 0
    fi

    # Fallback to the usual default branch names
    for candidate in origin/main origin/master main master; do
        if git -C "${repo}" rev-parse --verify --quiet "${candidate}^{commit}" >/dev/null; then
            echo "${candidate}"
            return 0
        fi
    done

    return 1
}

# Detect whether the application version definition was touched by the diff.
# The IS_RUST environment variable (true/false) selects the relevant file type.
version_changed() {
    local repo="$1" base="$2" head="$3"

    if [[ "${IS_RUST:-}" != true ]]; then
        # C apps: APPVERSION / APPVERSION_M / APPVERSION_N / APPVERSION_P (Makefile, *.mk)
        git -C "${repo}" diff "${base}...${head}" -- '*Makefile*' '*.mk' \
            | grep -qE '^[+-][[:space:]]*APPVERSION(_[MNP])?[[:space:]]*[:?]?='
    else
        # Rust apps: top-level 'version = ...' in a Cargo.toml
        git -C "${repo}" diff "${base}...${head}" -- '*Cargo.toml' \
            | grep -qE '^[+-]version[[:space:]]*='
    fi
}

# Expose the verdict to the CI (GitHub Actions step output)
set_output() {
    [[ -n "${GITHUB_OUTPUT:-}" ]] && echo "$1=$2" >> "${GITHUB_OUTPUT}"
    return 0
}

# Emit the human-readable report on every available channel:
#  - stdout (console: local VSCode extension and CI logs)
#  - GitHub Actions job summary (pull_request events only)
report() {
    local message="$1"

    echo -e "${message}"

    if [[ -n "${GITHUB_STEP_SUMMARY:-}" && "${GITHUB_EVENT_NAME:-}" == "pull_request" ]]; then
        { echo "### Changelog check"; echo ""; echo "${message}"; } >> "${GITHUB_STEP_SUMMARY}"
    fi
}

main() (
    repo="$1"
    base_ref="$2"
    head_ref="${3:-HEAD}"

    # Look for any tracked CHANGELOG* file (CHANGELOG, CHANGELOG.md, CHANGELOG.rst, ...)
    changelog_files=$(git -C "${repo}" ls-files | grep -E '(^|/)CHANGELOG[^/]*$' || true)

    if [[ -z "${changelog_files}" ]]; then
        set_output "verdict" "skip"
        report "ℹ️ No CHANGELOG file found in the repository, changelog check skipped."
        return 0
    fi

    # When no base reference is provided (local run), try to guess it
    if [[ -z "${base_ref}" ]]; then
        if ! base_ref=$(guess_base_ref "${repo}"); then
            set_output "verdict" "skip"
            report "ℹ️ Could not determine the base branch, changelog check skipped."
            return 0
        fi
        log_info "No base reference provided, comparing against '${base_ref}'"
    fi

    # Nothing to compare if base and head point to the same commit (e.g. run on the base branch)
    if [[ "$(git -C "${repo}" rev-parse "${base_ref}")" == "$(git -C "${repo}" rev-parse "${head_ref}")" ]]; then
        set_output "verdict" "skip"
        report "ℹ️ Head and base references are identical, changelog check skipped."
        return 0
    fi

    # List of files modified since the merge-base between base and head
    changed_files=$(git -C "${repo}" diff --name-only "${base_ref}...${head_ref}")

    # Is any CHANGELOG file part of the modified files?
    changelog_updated=false
    while read -r changelog; do
        if grep -qxF "${changelog}" <<< "${changed_files}"; then
            changelog_updated=true
            break
        fi
    done <<< "${changelog_files}"

    if [[ "${changelog_updated}" == true ]]; then
        set_output "verdict" "ok"
        report "✅ CHANGELOG was updated in this change."
        return 0
    fi

    if version_changed "${repo}" "${base_ref}" "${head_ref}"; then
        # Version bumped without documenting it: this is a blocking error in CI
        set_output "verdict" "hard"
        report "❌ The application version was changed but the CHANGELOG was **not** updated.
A version bump must be documented in the CHANGELOG."
        is_github_actions && echo "::error::App version changed but CHANGELOG was not updated"
        return 0
    fi

    # CHANGELOG not updated, but no version bump: informational only (typo fixes, snapshots, ...)
    set_output "verdict" "soft"
    report "⚠️ CHANGELOG was not updated by this change.
If this change is user-facing, please add a CHANGELOG entry. This is **not blocking** (no app version change detected)."
    is_github_actions && echo "::warning::CHANGELOG was not updated by this change"
    return 0
)

main "$@"
