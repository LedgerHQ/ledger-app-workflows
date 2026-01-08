# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.91.1] - 2026-01-08

### Fixed

- Override nightly version when building Rust apps

## [1.91.0] - 2026-01-07

### Added

- `config/forbidden-flags.json` : file that keeps track of compilation flags that shall not be used for production.
- Step in reusable workflow `_check_makefile.yml` that checks none of these flags are merged to production branches.

## [1.90.1] - 2025-12-29

### Fixed

- Change concurrency name to avoid conflicts

## [1.90.0] - 2025-12-15

### Added

- CHANGELOG.md
- reusable workflow `reusable_add_tag.yml` enabling the automation of tags creation.
