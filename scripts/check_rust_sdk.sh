#!/usr/bin/env bash
#
# script to check the Rust SDK crates version
#

set -e

exeName=$(readlink -f "$0")
dirName=$(dirname "${exeName}")

# shellcheck source=/dev/null
source "${dirName}/logger.sh"

if [ -z "$1" ]; then
    log_error "Please provide the path to the application build directory"
    exit 1
fi

cd "$1"
# Check that current nightly version is the same as the one set in $RUST_NIGHTLY
if [ -n "$RUST_NIGHTLY" ]; then
    current_nightly_version=$(rustup show active-toolchain | awk '{print $1}' | grep -oE 'nightly-[0-9]{4}-[0-9]{2}-[0-9]{2}')
    if [[ "$current_nightly_version" != "$RUST_NIGHTLY" ]]; then
        log_error "Current Rust nightly version is $current_nightly_version whereas $RUST_NIGHTLY is required;"
        log_error "Please update the Rust toolchain in the rust-toolchain.toml file."
        exit 1
    fi
fi
# Get the list of dependencies and filter the Rust SDK crates
all_crates=$(cargo tree --depth 2 --prefix none | awk '{print $1}' | sort -u)
for crate in "ledger_device_sdk"; do
    if echo "$all_crates" | grep -q "^$crate$"; then
        curr_version=$(cargo tree -p $crate | grep -oE "$crate v[0-9]+\.[0-9]+\.[0-9]+" | awk '{print $2}' | sed 's/^v//')
        latest_version=$(cargo search $crate --limit 1 | grep -oE "$crate = \"[0-9]+\.[0-9]+\.[0-9]+\"" | awk -F '"' '{print $2}')
        if [[ "${latest_version}" != "${curr_version}" ]]; then
            log_error "$crate : version is $curr_version whereas $latest_version is available; please update!"
            log_error "Application is always built with the latest versions of the Rust SDK crates"
            log_error "Don't forget to activate dependabot in your repository settings to automatically update the Rust SDK dependencies"
            log_error "see https://github.com/LedgerHQ/app-boilerplate-rust/blob/main/.github/dependabot.yml"
            exit 1
        fi
    fi
done


