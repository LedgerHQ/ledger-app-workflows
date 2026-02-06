# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
