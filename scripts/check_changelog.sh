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

main() (
    repo="$1"
    base_ref="$2"
    head_ref="${3:-HEAD}"

    # Look for any tracked CHANGELOG* file (CHANGELOG, CHANGELOG.md, CHANGELOG.rst, ...)
    changelog_files=$(git -C "${repo}" ls-files | grep -E '(^|/)CHANGELOG[^/]*$' || true)

    if [[ -z "${changelog_files}" ]]; then
        log_warning "No CHANGELOG file found in the repository, changelog check skipped"
        return 0
    fi

    # When no base reference is provided (local run), try to guess it
    if [[ -z "${base_ref}" ]]; then
        if ! base_ref=$(guess_base_ref "${repo}"); then
            log_warning "Could not determine the base branch, changelog check skipped"
            return 0
        fi
        log_info "No base reference provided, comparing against '${base_ref}'"
    fi

    # Nothing to compare if base and head point to the same commit (e.g. run on the base branch)
    if [[ "$(git -C "${repo}" rev-parse "${base_ref}")" == "$(git -C "${repo}" rev-parse "${head_ref}")" ]]; then
        log_warning "Head and base references are identical, changelog check skipped"
        return 0
    fi

    # List of files modified since the merge-base between base and head
    changed_files=$(git -C "${repo}" diff --name-only "${base_ref}...${head_ref}")

    while read -r changelog; do
        if grep -qxF "${changelog}" <<< "${changed_files}"; then
            log_success "CHANGELOG file '${changelog}' was updated"
            return 0
        fi
    done <<< "${changelog_files}"

    log_error "A CHANGELOG file exists but was not updated:"
    while read -r changelog; do
        log_error_no_header "  - ${changelog}"
    done <<< "${changelog_files}"
    log_error_no_header "Please document your changes in the CHANGELOG."
    log_error_no_header "If this PR does not require a CHANGELOG entry, add the 'no_changelog' label to bypass this check."
    return 1
)

main "$@"
