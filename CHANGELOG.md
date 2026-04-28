# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.95.1] - 2026-04-28

### Changed

- `reusable_build.yml` : hotfix : do not fail if PR comment fails. Comments will fail in PR from external forks.
- `reusable_ragger_tests.yml` : same

## [1.95.0] - 2026-04-28

### Added

- `reusable_build.yml` : added option `build_comparison` for elf sections comment in prs.
- `reusable_build.yml` : added option `enable_stack_consumption` so `reusable_ragger_tests.yml` can use `--get-stack-consumption` for stack consumption comment in prs.
- `reusable_ragger_tests.yml` : added option `post_stack_consumption` for stack consumption comment in prs. requires `enable_stack_consumption == true` in `reusable_build.yml`.

## [1.94.27] - 2026-04-27

### Changed

- `reusable_app_release.yml` : Added `builder` input parameter. Added a version check step that verifies the tag matches the last changelog entry (C apps) or `Cargo.toml` version (Rust apps) before releasing.

## [1.94.26] - 2026-04-24

### Added

- `reusable_app_release.yml` : New reusable workflow to build the application for all compatible devices and create a GitHub release with ELF binaries attached. Release notes are automatically extracted from `CHANGELOG.md`.

## [1.94.25] - 2026-04-23

### Changed

- `reusable_crates_deployment.yml` : Fixing deployment for non nested workspaces

## [1.94.24] - 2026-04-16

### Changed

- `reusable_pypi_deployment.yml` : target new jfrog registry (embedded-apps-pypi-prod-public)

## [1.94.23] - 2026-04-13

### Changed

- `reusable_pypi_deployment.yml` : remove explicit deployment to pypi following jfrog/pypi sync

## [1.94.22] - 2026-04-09

### Fixed

- `reusable_pypi_deployment.yml` : fixed CHANGELOG version regex to correctly match multi-digit version segments (e.g. `12.34.56`)

## [1.94.21] - 2026-04-09

### Fixed

- Change permission of dist directory before signing

## [1.94.20] - 2026-03-31

### Changed

- Added DEBUG_OS_STACK_CONSUMPTION to forbidden flags

## [1.94.19] - 2026-03-27

### Added

- `reusable_pypi_deployment.yml` : added option `docker_image_artifact` to load a locally built Docker image from a previous job and use it as the execution container.

## [1.94.18] - 2026-03-26

### Changed

- `reusable_docker_deployment.yml` : changed login and push conditions

## [1.94.17] - 2026-03-25

### Added

- `reusable_pypi_deployment.yml` : added option workspace_mark_safe, needed for jobs running in containers with root UID.

## [1.94.16] - 2026-03-25

### Fixed

- Changed `==` to `=` in shell test for POSIX sh compatibility

## [1.94.15] - 2026-02-20

### Changed

- `reusable_spell_check.yml` : Add input parameter to support `skip` option.

## [1.94.14] - 2026-02-17

### Changed

- `reusable_docker_deployment.yml` : artifact retention period is set to 1 day for built images, as they are only needed for testing in subsequent steps and not for long term storage.

## [1.94.13] - 2026-02-17

### Changed

- `reusable_docker_deployment.yml` : adding optional output for built image to be tested in subsequent steps.

## [1.94.12] - 2026-02-06

### Changed

- Updated all actions references to latest major versions

## [1.94.11] - 2026-02-10

### Changed

- `reusable_unit_tests.yml` : test_directory is deprecated and overridden by `$(ledger-manifest -otu ledger-app-toml)`. To be removed eventually.

## [1.94.10] - 2026-02-06

### Fixed

- docker deployment : newlines in image list

## [1.94.9] - 2026-02-06

### Fixed

- `reusable_docker_deployment.yml` : jfrog image shall not be listed in test builds

## [1.94.8] - 2026-02-03

### Fixed

- `reusable_crates_deployment.yml` : move version check out of reusable

## [1.94.7] - 2026-02-03

### Fixed

- `reusable_crates_deployment.yml` : Fixed trace

## [1.94.6] - 2026-02-03

### Changed

- `reusable_pypi_deployment.yml` : sync with downstream changes.

## [1.94.5] - 2026-01-30

### Added

- skip existing not supported for twine upload to jfrog, only for pypi.

## [1.94.4] - 2026-01-30

### Added

- twine upload --skip-existing to avoid failing when package version already exists on pypi.

## [1.94.3] - 2026-01-30

### Fixed

- `reusable_pypi_deployment.yml` : for pypi deployment, ubuntu-latest runner is not in jfrog's whitelist

## [1.94.2] - 2026-01-30

### Fixed

- `reusable_pypi_deployment.yml` : fix case where images that do not derive from ubuntu which do not necessarily have sudo command
- `reusable_pypi_deployment.yml` : using github actions in a containerized runs the action in a sibling container, not the expected container

## [1.94.1] - 2026-01-30

### Added

- Adding parameter in `reusable_pypi_deployment.yml` to specify container to use.

## [1.94.0] - 2026-01-16

### Added

- adding `reusable_docker_deployment.yml` reusable workflow to deploy docker images to Jfrog and subsequently to ghcr.io.

## [1.93.2] - 2026-01-22

### Fixed

- `reusable_crates_deployment.yml` : on artifactory, credentials.toml is needed for cargo search.

## [1.93.1] - 2026-01-20

### Fixed

- missing index update in `reusable_unit_tests.yml`, causing UTs to fail in app repositories.

## [1.93.0] - 2026-01-16

### Added

- adding `reusable_crates_deployment.yml` reusable workflow to deploy Rust crates to Jfrog and subsequently to crates.io.

## [1.92.1] - 2026-01-16

### Fixed

- Adding missing -r for rust codebases in `_check_makefile.yml`

## [1.92.0] - 2026-01-13

### Added

- Reusable workflow `reusable_npm_deployment.yml` to deploy npm packages to Jfrog, and subsequently to npmjs.com.

## [1.91.3] - 2026-01-13

### Fixed

- Fixing check_makefile.sh having wrong path in a CI context.

## [1.91.2] - 2026-01-08

### Fixed

- Following 1.91.0, check that no forbidden rust flags are delivered.

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
