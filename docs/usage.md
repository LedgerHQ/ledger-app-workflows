# Reusable workflows usage

This page lists the parameters used by the different workflows.

All these reusable workflows are intended to be called from application repositories like:

```yml
jobs:
  job_name:
    name: Executing my reusable workflow
    uses: LedgerHQ/ledger-app-workflows/.github/workflows/reusable_<name>.yml@vx
    with:
      parameter1: parameter_value
```

## Reusable Build

In order to build an App, this workflow can use the following input parameters:

| Parameter                    | Required | Default value             | Comment                                                                                                     |
| ---------------------------- | -------- | ------------------------- | ----------------------------------------------------------------------------------------------------------- |
| app_repository               | ❌       | `github.repository`       | The GIT repository to build                                                                                 |
| app_branch_name              | ❌       | `github.ref`              | The GIT branch to build                                                                                     |
| flags                        | ❌       |                           | Additional compilation flags                                                                                |
| use_case                     | ❌       |                           | The use case to build the application for                                                                   |
| upload_app_binaries_artifact | ❌       |                           | The name of the artifact containing the built app binaries                                                  |
| upload_as_lib_artifact       | ❌       |                           | Prefixes for the built app binaries                                                                         |
| run_for_devices              | ❌       | *ALL*                     | The list of device(s) on which the CI will run                                                              |
| builder                      | ❌       | `ledger-app-builder-lite` | The docker image to build the application in                                                                |
| sdk_reference                | ❌       |                           | A SDK reference to checkout before building the app                                                         |
| cargo_ledger_build_args      | ❌       |                           | Additional arguments to pass to the cargo                                                                   |
| build_comparison             | ❌       | `false`                   | Whether to build the target branch and report ELF size diffs on PRs                                         |
| enable_stack_consumption     | ❌       | `false`                   | Enable stack consumption tracking (`DEBUG_OS_STACK_CONSUMPTION=1` for C, `--features stack_usage` for Rust) |

In addition, the following secret can be used:

| Parameter | Required | Default value | Comment                                 |
| --------- | -------- | ------------- | --------------------------------------- |
| token     | ❌       |               | A token passed from the caller workflow |

## Reusable App Release

This workflow builds the application for all compatible devices and creates a GitHub release with ELF binaries attached.
Release notes are automatically extracted from `CHANGELOG.md`.

| Parameter      | Required | Default value             | Comment                                      |
| -------------- | -------- | ------------------------- | -------------------------------------------- |
| app_repository | ❌       | `github.repository`       | The GIT repository to release                |
| app_ref_name   | ❌       | `github.ref_name`         | The GIT reference to build                   |
| builder        | ❌       | `ledger-app-builder-lite` | The docker image to build the application in |

The workflow also checks before building that the tag being released matches the latest version in `CHANGELOG.md` (for C apps) or the version in `Cargo.toml` (for Rust apps).

In addition, the following secret can be used:

| Parameter | Required | Default value | Comment                                 |
| --------- | -------- | ------------- | --------------------------------------- |
| token     | ❌       |               | A token passed from the caller workflow |

## Reusable Ragger tests

In order to test an App, this workflow can use the following input parameters:

| Parameter                            | Required | Default value            | Comment                                                                                                                           |
| ------------------------------------ | -------- | ------------------------ | --------------------------------------------------------------------------------------------------------------------------------- |
| app_repository                       | ❌       | `github.repository`      | The GIT repository to test                                                                                                        |
| app_branch_name                      | ❌       | `github.ref`             | The GIT branch to test                                                                                                            |
| test_dir                             | ❌       | `ledger_app.toml` config | The directory where the Python tests are stored                                                                                   |
| download_app_binaries_artifact       | ✅       |                          | The name of the artifact containing the app binaries to be tested                                                                 |
| additional_app_binaries_artifact     | ❌       |                          | The name of the artifact containing the additional app binaries                                                                   |
| additional_app_binaries_artifact_dir | ❌       |                          | The directory where the additional app binaries will be downloaded                                                                |
| lib_binaries_artifact                | ❌       |                          | The name of the artifact containing the library binaries                                                                          |
| lib_binaries_artifact_dir            | ❌       |                          | The directory where the additional lib binaries will be downloaded                                                                |
| run_for_devices                      | ❌       | *ALL*                    | The list of device(s) on which the CI will run                                                                                    |
| upload_snapshots_on_failure          | ❌       | `true`                   | Enable or disable upload of tests snapshots if the job fails                                                                      |
| regenerate_snapshots                 | ❌       | `false`                  | Clean snapshots, regenerate them, commit the changes in a branch, and open a PR                                                   |
| test_filter                          | ❌       |                          | Specify an expression which implements a substring match on the test names                                                        |
| test_options                         | ❌       |                          | Specify optional parameters to be passed to the running test                                                                      |
| container_image                      | ❌       |                          | Optional container image to run the ragger_tests job                                                                              |
| capture_file                         | ❌       |                          | Optional file name to capture pytest logs into an artifact                                                                        |
| post_stack_consumption               | ❌       | `false`                  | Post a stack consumption summary on PRs. Requires `reusable_build` with `enable_stack_consumption` and `build_comparison` enabled |

In addition, the following secret can be used:

| Parameter           | Required | Default value | Comment                                 |
| ------------------- | -------- | ------------- | --------------------------------------- |
| secret_test_options | ❌       |               | A token passed from the caller workflow |

## Reusable Ragger tests coverage

This workflow measures the firmware C code coverage exercised by the Ragger functional tests: it builds the application with debug symbols, then runs the Ragger tests with coverage tracing enabled, producing an lcov file and an HTML report as the `coverage-<device>` artifact(s). When a Codecov token is provided, the lcov file is also uploaded to codecov.io under the `functionaltests` flag.

It can use the following input parameters:

| Parameter        | Required | Default value             | Comment                                                                           |
| ---------------- | -------- | ------------------------- | --------------------------------------------------------------------------------- |
| app_repository   | ❌       | `github.repository`       | The GIT repository to test                                                        |
| app_branch_name  | ❌       | `github.ref`              | The GIT branch to test                                                            |
| flags            | ❌       | `DEBUG=1`                 | Compilation flags. Must produce an ELF with debug symbols                         |
| run_for_devices  | ❌       | *ALL*                     | The list of device(s) on which the CI will run                                    |
| builder          | ❌       | `ledger-app-builder-lite` | The docker image to build the application in                                      |
| sdk_reference    | ❌       |                           | A SDK reference to checkout before building the app                               |
| test_filter      | ❌       |                           | Specify an expression which implements a substring match on the test names        |
| test_options     | ❌       |                           | Specify optional parameters to be passed to the running test                      |
| coverage_exclude | ❌       |                           | Comma-separated source paths to exclude from coverage (e.g. a vendored submodule) |
| container_image  | ❌       |                           | Optional container image to run the ragger tests                                  |

In addition, the following secrets can be used:

| Parameter           | Required | Default value | Comment                                                                                              |
| ------------------- | -------- | ------------- | ---------------------------------------------------------------------------------------------------- |
| token               | ❌       |               | A token passed from the caller workflow (used to checkout/build the app)                             |
| secret_test_options | ❌       |               | A string of secret options to be given to pytest                                                     |
| codecov_token       | ❌       |               | Codecov token; if provided, the lcov file is uploaded to codecov.io under the `functionaltests` flag |

## Reusable Memory Profiling

This workflow bundles the whole memory profiling pipeline: it builds the application with memory profiling enabled, runs the Ragger functional tests while capturing the Speculos output, then processes the captured logs with the SDK `valground` tool to detect memory leaks (the job fails if a leak is reported).

It can use the following input parameters:

| Parameter       | Required | Default value                | Comment                                                                    |
| --------------- | -------- | ---------------------------- | -------------------------------------------------------------------------- |
| app_repository  | ❌       | `github.repository`          | The GIT repository to test                                                 |
| app_branch_name | ❌       | `github.ref`                 | The GIT branch to test                                                     |
| flags           | ❌       | `DEBUG=1 MEMORY_PROFILING=1` | Compilation flags. Must enable at least `DEBUG=1 MEMORY_PROFILING=1`       |
| run_for_devices | ❌       | *ALL*                        | The list of device(s) on which the CI will run                             |
| builder         | ❌       | `ledger-app-builder-lite`    | The docker image to build the application in                               |
| sdk_reference   | ❌       |                              | A SDK reference to checkout before building the app                        |
| test_filter     | ❌       |                              | Specify an expression which implements a substring match on the test names |
| test_options    | ❌       |                              | Specify optional parameters to be passed to the running test               |

In addition, the following secrets can be used:

| Parameter           | Required | Default value | Comment                                          |
| ------------------- | -------- | ------------- | ------------------------------------------------ |
| token               | ❌       |               | A token passed from the caller workflow          |
| secret_test_options | ❌       |               | A string of secret options to be given to pytest |

## Reusable Guideline Enforcer

In order to check an App, this workflow can use the following input parameters:

| Parameter       | Required | Default value       | Comment                                        |
| --------------- | -------- | ------------------- | ---------------------------------------------- |
| app_repository  | ❌       | `github.repository` | The GIT repository to build                    |
| run_for_devices | ❌       | *ALL*               | The list of device(s) on which the CI will run |

In addition, the following secret can be used:

| Parameter | Required | Default value | Comment                                           |
| --------- | -------- | ------------- | ------------------------------------------------- |
| git_token | ❌       |               | A token used as authentication for GIT operations |

On pull requests, if the repository owns a `CHANGELOG` file, this workflow checks whether it has been
updated by the PR. The verdict is always recorded in the job summary, and the check is **not blocking
by default**:

- if the `CHANGELOG` is updated, the check passes ;
- if the `CHANGELOG` is **not** updated, a warning annotation is emitted but the workflow does **not**
  fail (typo fixes, snapshot updates, ...) ;
- if the PR **changes the application version** (`APPVERSION*` in the `Makefile` for C apps, or the
  package `version` in `Cargo.toml` for Rust apps) **without** updating the `CHANGELOG`, the check
  **fails**: a version bump must always be documented.

| CHANGELOG present | updated | version changed | verdict | Local (VSCode) | CI                                    |
| ----------------- | ------- | --------------- | ------- | -------------- | ------------------------------------- |
| no                | –       | –               | `skip`  | ℹ️ status      | ℹ️ job summary                        |
| yes               | yes     | –               | `ok`    | ✅ status      | ✅ job summary                        |
| yes               | no      | no              | `soft`  | ⚠️ status      | ⚠️ job summary + annotation           |
| yes               | no      | yes             | `hard`  | ❌ status      | ❌ job summary + annotation + failure |

This check can be entirely bypassed by adding the `no_changelog` label to the PR. The label is read
from the triggering event, so adding it does not, by itself, re-trigger the workflow: if the check
already ran, push a new commit so a fresh run picks up the label (or make the caller workflow listen
to the `labeled` pull-request activity type).

This check is also part of `check_all.sh` and can be run locally with `check_all.sh -c changelog`.
When run locally it is purely informational (it never fails) and compares the current branch against
the default branch (`origin/HEAD`, falling back to `origin/main`/`origin/master`).

## Reusable Lint

In order to check an App, this workflow can use the following input parameters:

| Parameter  | Required | Default value | Comment                                                          |
| ---------- | -------- | ------------- | ---------------------------------------------------------------- |
| source     | ✅       |               | The source directory to lint (space-separated list is supported) |
| version    | ❌       | 14            | ⚠️ **DEPRECATED** - The `clang-format` version to use            |
| extensions | ❌       | `h,c,proto`   | ⚠️ **DEPRECATED** - The file extensions to lint, comma-separated |

## Reusable Python Checks

In order to check an App, this workflow can use the following input parameters:

| Parameter             | Required | Default value       | Comment                                                                              |
| --------------------- | -------- | ------------------- | ------------------------------------------------------------------------------------ |
| app_repository        | ❌       | `github.repository` | The GIT repository to build                                                          |
| app_branch_name       | ❌       | `github.ref`        | The GIT branch to build                                                              |
| run_linter            | ❌       |                     | ⚠️ **DEPRECATED** - When set, runs the legacy linter (`pylint`, `flake8`, `yapf` or `black`) instead of `ruff` |
| run_type_check        | ✅       | `false`             | Whether to run mypy type check                                                       |
| run_security_check    | ❌       | `false`             | Whether to run bandit security check                                                 |
| bandit_severity_level | ❌       |                     | Minimum bandit severity level to report (`all`, `low`, `medium` or `high`)           |
| bandit_non_blocking   | ❌       | `false`             | Whether the bandit check should never fail the workflow                              |
| req_directory         | ❌       |                     | The directory containing the `requirements.txt`                                      |
| setup_directory       | ❌       |                     | The directory containing the `setup.cfg`                                             |
| src_directory         | ✅       |                     | The directory containing the python sources to check (relative to `setup_directory`) |
| additional_packages   | ❌       |                     | Additional packages to install                                                       |

## Reusable Yaml Lint

In order to check an App, this workflow can use the following input parameters:

| Parameter   | Required | Default value | Comment        |
| ----------- | -------- | ------------- | -------------- |
| file_or_dir | ❌       | `.`           | Files to check |

## Reusable Spell Checks

In order to check an App, this workflow can use the following input parameters:

| Parameter         | Required | Default value       | Comment                                                 |
| ----------------- | -------- | ------------------- | ------------------------------------------------------- |
| app_repository    | ❌       | `github.repository` | The GIT repository to check                             |
| app_branch_name   | ❌       | `github.ref`        | The GIT branch to check                                 |
| check_filenames   | ❌       | `true`              | Whether to check filenames for misspellings             |
| ignore_words_list | ❌       |                     | Comma-separated list of words to ignore                 |
| ignore_words_file | ❌       |                     | Path to a file containing words to ignore               |
| src_path          | ❌       |                     | Comma-separated list of paths to check for misspellings |
| skip_path         | ❌       |                     | Comma-separated list of paths to skip for misspellings  |

## Reusable CodeQL Checks

In order to build an App, this workflow can use the following input parameters:

| Parameter       | Required | Default value             | Comment                                        |
| --------------- | -------- | ------------------------- | ---------------------------------------------- |
| app_repository  | ❌       | `github.repository`       | The GIT repository to build                    |
| app_branch_name | ❌       | `github.ref`              | The GIT branch to build                        |
| run_for_devices | ❌       | *ALL*                     | The list of device(s) on which the CI will run |
| builder         | ❌       | `ledger-app-builder-lite` | The docker image to build the application in   |
| flags           | ❌       |                           | Additional compilation flags                   |

For this workflow, it is important to also set the secrets for called workflow. For example:

```yml
jobs:
  analyse:
    name: Call Ledger CodeQL analysis
    uses: LedgerHQ/ledger-app-workflows/.github/workflows/reusable_codeql_checks.yml@v1
    secrets: inherit
```

## Reusable Unit Tests

In order to test an App, this workflow can use the following input parameters:

| Parameter              | Required | Default value             | Comment                                                                                                                           |
| ---------------------- | -------- | ------------------------- | --------------------------------------------------------------------------------------------------------------------------------- |
| app_repository         | ❌       | `github.repository`       | The GIT repository to test                                                                                                        |
| app_branch_name        | ❌       | `github.ref`              | The GIT branch to test                                                                                                            |
| test_directory         | ❌       | Auto-detected             | ⚠️ **DEPRECATED** - Automatically read from `ledger_app.toml`                                                                     |
| builder                | ❌       | `ledger-app-builder-lite` | The docker image to build the application in                                                                                      |
| additional_packages    | ❌       |                           | Additional packages to install                                                                                                    |
| coverage_exclude_paths | ❌       |                           | Space-separated glob patterns to exclude from the coverage result (`/usr/*`, `/opt/*` and the test directory are always excluded) |
| enable_codecov         | ❌       | `true`                    | Whether to upload coverage to Codecov; `false` for repos that can't use it, e.g. internal (also skipped without `codecov_token`)  |
| use_cmake_ut_framework | ❌       | `false`                   | Use the CMake UT framework: tests run and coverage generated in a `build/` subdirectory (else directly in the test directory) |

In addition, the following secrets can be used:

| Parameter     | Required | Default value  | Comment                                                                                |
| ------------- | -------- | -------------- | -------------------------------------------------------------------------------------- |
| token         | ❌       | `github.token` | A token passed from the caller workflow; needed for private repositories or submodules |
| codecov_token | ❌       |                | The Codecov token used to authorize the coverage upload                                |

Pass only the secrets the workflow needs (preferred over `secrets: inherit`). On pull
requests, the workflow also posts a coverage comment and (optionally) publishes native
GitHub PR coverage; for these the calling job's token must grant the matching permissions,
otherwise they simply degrade (no comment / no native coverage) without failing the run:

```yml
jobs:
  job_unit_test:
    name: Call Ledger unit_test
    uses: LedgerHQ/ledger-app-workflows/.github/workflows/reusable_unit_tests.yml@v1
    # test_directory is deprecated and auto-detected from ledger_app.toml
    secrets:
      codecov_token: ${{ secrets.CODECOV_TOKEN }}
      token: ${{ secrets.GITHUB_TOKEN }}
    permissions:
      contents: read
      actions: write        # upload/download the coverage artifact
      pull-requests: write  # post the coverage comment on PRs
      code-quality: write   # native GitHub PR coverage (requires the repo's "Code Quality" feature)
```

The Codecov view (and its PR comment) can additionally be tuned per repository with a
`codecov.yml`, e.g. to exclude paths from Codecov itself:

```yml
ignore:
  - "tests"
```

## Reusable ClusterFuzzLite Tests

In order to test an App, this workflow can use the following input parameters:

| Parameter        | Required | Default value | Comment                                                                   |
| ---------------- | -------- | ------------- | ------------------------------------------------------------------------- |
| exec_mode        | ✅       |               | Execution mode: `github.event_name` (`pull_request`, `push`, `schedule`)' |
| seconds_pr       | ❌       | 300           | Fuzzing duration in seconds for Pull Requests                             |
| seconds_push     | ❌       | 600           | Fuzzing duration in seconds when push on branch                           |
| seconds_schedule | ❌       | 18000         | Fuzzing duration in seconds for scheduled tasks                           |

## Reusable Swap Tests

In order to test an App, this workflow can use the following input parameters:

| Parameter                      | Required | Default value       | Comment                                                                         |
| ------------------------------ | -------- | ------------------- | ------------------------------------------------------------------------------- |
| app_repository                 | ❌       | `github.repository` | The GIT repository to test                                                      |
| app_branch_name                | ❌       | `github.ref`        | The GIT branch to test                                                          |
| download_app_binaries_artifact | ❌       |                     | If not provided, the workflow will build the app to test                        |
| exchange_build_artifact        | ❌       |                     | If not provided, the workflow will build the `app-exchange` app                 |
| ethereum_build_artifact        | ❌       |                     | If not provided, the workflow will build the `app-ethereum` app                 |
| regenerate_snapshots           | ❌       | `false`             | Clean snapshots, regenerate them, commit the changes in a branch, and open a PR |

## Reusable pypi deployment

In order to deploy a package, this workflow can use the following input parameters:

| Parameter             | Required | Default value                | Comment                                                                                                                               |
| --------------------- | -------- | ---------------------------- | ------------------------------------------------------------------------------------------------------------------------------------- |
| repository_name       | ❌       | `github.repository`          | The GIT repository to deploy                                                                                                          |
| branch_name           | ❌       | `github.ref`                 | The GIT branch to deploy                                                                                                              |
| package_name          | ✅       |                              | The name of the package                                                                                                               |
| package_directory     | ❌       | `.`                          | The directory where the Python package lies                                                                                           |
| dry_run               | ❌       | `false`                      | Whether to run all pre-publishing steps but skips the actual publishing                                                               |
| publish               | ✅       | `true`                       | Whether the package should be published                                                                                               |
| release               | ❌       | `true`                       | Whether the package should be packaged as a release                                                                                   |
| runs_on               | ❌       | public-ledgerhq-shared-small | The python version to use within the container                                                                                        |
| container             | ❌       |                              | The container image that should be used to run the job                                                                                |
| python_version        | ❌       | `3.10`                       | The python version to use within the container                                                                                        |
| workspace_mark_safe   | ❌       | `false`                      | Mark the workspace as safe for git, needed for jobs running in containers with root UID                                               |
| docker_image_artifact | ❌       |                              | Name of a Docker image artifact (tar) built by a previous job to use as the execution container. Mutually exclusive with `container`. |

## Reusable crates deployment

In order to deploy a crate, this workflow can use the following input parameters:

| Parameter         | Required | Default value       | Comment                                                                 |
| ----------------- | -------- | ------------------- | ----------------------------------------------------------------------- |
| repository_name   | ❌       | `github.repository` | The GIT repository to deploy                                            |
| branch_name       | ❌       | `github.ref`        | The GIT branch to deploy                                                |
| package_directory | ❌       | `.`                 | The directory where the rust codebase lies                              |
| dry_run           | ❌       | `false`             | Whether to run all pre-publishing steps but skips the actual publishing |
| publish           | ✅       | `true`              | Whether the package should be published                                 |
| release           | ❌       | `true`              | Whether the package should be packaged as a release                     |

## Reusable docker deployment

In order to build and deploy a docker image, this workflow can use the following input parameters:

| Parameter           | Required | Default value       | Comment                                                                                               |
| ------------------- | -------- | ------------------- | ----------------------------------------------------------------------------------------------------- |
| app_repository      | ❌       | `github.repository` | The GIT repository to deploy                                                                          |
| app_ref             | ❌       | `github.ref`        | The GIT branch to deploy                                                                              |
| image_name          | ✅       |                     | The docker image name to build                                                                        |
| build_dir           | ❌       | `.`                 | The directory from where to perform the build                                                         |
| dockerfile_path     | ❌       | `./Dockerfile`      | The path to the dockerfile to build                                                                   |
| build_args          | ❌       |                     | Extra args to pass to docker build                                                                    |
| dry_run             | ❌       | `false`             | To perform a build but skip publishing steps                                                          |
| jfrog_instance      | ❌       |                     | hostname of the jfrog instance to deploy to                                                           |
| jfrog_registry_name | ❌       |                     | registry within the instance to publish to                                                            |
| runs_on             | ❌       | `ubuntu-latest`     | The type of runner to use                                                                             |
| outputs             | ❌       |                     | type and location of the output. Useful to test the built image in the same workflow it was built in. |

In addition, the following secret can be used:

| Parameter | Required | Default value | Comment                                      |
| --------- | -------- | ------------- | -------------------------------------------- |
| token     | ✅       |               | A token with access to the target repository |

## Reusable Check Ethereum SDK

No parameters for this workflow

## Reusable Documentation Generation

In order to check an App, this workflow can use the following input parameters:

| Parameter       | Required | Default value       | Comment                     |
| --------------- | -------- | ------------------- | --------------------------- |
| app_repository  | ❌       | `github.repository` | The GIT repository to clone |
| app_branch_name | ❌       | `github.ref`        | The GIT branch to clone     |
| doxy_file       | ❌       | `.doxygen/Doxyfile` | Doxygen configuration file  |

## Reusable NPM Deployment

In order to deploy an npm package, this workflow can use the following input parameters:

| Parameter         | Required | Default value                   | Comment                                                                         |
| ----------------- | -------- | ------------------------------- | ------------------------------------------------------------------------------- |
| app_repository    | ❌       | `github.repository`             | The GIT repository to deploy                                                    |
| app_ref_name      | ❌       | `github.ref`                    | The GIT reference to deploy                                                     |
| package_directory | ❌       | `.`                             | The directory where the npm packages lies (where the package.json can be found) |
| dry_run           | ❌       | `false`                         | If true, runs all pre-publishing steps but run `npm publish --dry-run`          |
| jfrog_registry    | ❌       | `embedded-apps-npm-prod-public` | The package registry where the package will be pushed                           |
