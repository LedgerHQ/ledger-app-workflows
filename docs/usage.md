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

| Parameter                    | Required | Default value             | Comment                                 |
| ---------------------------- | -------- | ------------------------- | --------------------------------------- |
| app_repository               | ❌       | `github.repository`       | The GIT repository to build |
| app_branch_name              | ❌       | `github.ref`              | The GIT branch to build |
| flags                        | ❌       |                           | Additional compilation flags |
| use_case                     | ❌       |                           | The use case to build the application for |
| upload_app_binaries_artifact | ❌       |                           | The name of the artifact containing the built app binaries |
| upload_as_lib_artifact       | ❌       |                           | Prefixes for the built app binaries |
| run_for_devices              | ❌       | *ALL*                     | The list of device(s) on which the CI will run |
| builder                      | ❌       | `ledger-app-builder-lite` | The docker image to build the application in |
| sdk_reference                | ❌       |                           | A SDK reference to checkout before building the app |
| cargo_ledger_build_args      | ❌       |                           | Additional arguments to pass to the cargo |

In addition, the following secret can be used:

| Parameter                    | Required | Default value             | Comment                                 |
| ---------------------------- | -------- | ------------------------- | --------------------------------------- |
| token                        | ❌       |                           | A token passed from the caller workflow |

## Reusable Ragger tests

In order to test an App, this workflow can use the following input parameters:

| Parameter                            | Required | Default value             | Comment                                 |
| ------------------------------------ | -------- | ------------------------- | --------------------------------------- |
| app_repository                       | ❌       | `github.repository`       | The GIT repository to test |
| app_branch_name                      | ❌       | `github.ref`              | The GIT branch to test |
| test_dir                             | ❌       | `ledger_app.toml` config  | The directory where the Python tests are stored |
| download_app_binaries_artifact       | ✅       |                           | The name of the artifact containing the app binaries to be tested |
| additional_app_binaries_artifact     | ❌       |                           | The name of the artifact containing the additional app binaries |
| additional_app_binaries_artifact_dir | ❌       |                           | The directory where the additional app binaries will be downloaded |
| lib_binaries_artifact                | ❌       |                           | The name of the artifact containing the library binaries |
| lib_binaries_artifact_dir            | ❌       |                           | The directory where the additional lib binaries will be downloaded |
| run_for_devices                      | ❌       | *ALL*                     | The list of device(s) on which the CI will run |
| upload_snapshots_on_failure          | ❌       | `true`                    | Enable or disable upload of tests snapshots if the job fails |
| regenerate_snapshots                 | ❌       | `false`                   | Clean snapshots, regenerate them, commit the changes in a branch, and open a PR |
| test_filter                          | ❌       |                           | Specify an expression which implements a substring match on the test names |
| test_options                         | ❌       |                           | Specify optional parameters to be passed to the running test |
| container_image                      | ❌       |                           | Optional container image to run the ragger_tests job |
| capture_file                         | ❌       |                           | Optional file name to capture pytest logs into an artifact |

In addition, the following secret can be used:

| Parameter                    | Required | Default value             | Comment                                 |
| ---------------------------- | -------- | ------------------------- | --------------------------------------- |
| secret_test_options          | ❌       |                           | A token passed from the caller workflow |

## Reusable Guideline Enforcer

In order to check an App, this workflow can use the following input parameters:

| Parameter                            | Required | Default value             | Comment                                 |
| ------------------------------------ | -------- | ------------------------- | --------------------------------------- |
| app_repository                       | ❌       | `github.repository`       | The GIT repository to build |
| run_for_devices                      | ❌       | *ALL*                     | The list of device(s) on which the CI will run |

In addition, the following secret can be used:

| Parameter                    | Required | Default value             | Comment                                 |
| ---------------------------- | -------- | ------------------------- | --------------------------------------- |
| git_token                    | ❌       |                           | A token used as authentication for GIT operations |

## Reusable Lint

In order to check an App, this workflow can use the following input parameters:

| Parameter                            | Required | Default value             | Comment                                 |
| ------------------------------------ | -------- | ------------------------- | --------------------------------------- |
| source                               | ✅       |                           | The source directory to lint |
| version                              | ❌       | 14                        | The `clang-format` version to use |
| extensions                           | ❌       | `h,c,proto`               | The file extensions to lint, comma-separated |

## Reusable Python Checks

In order to check an App, this workflow can use the following input parameters:

| Parameter                            | Required | Default value             | Comment                                 |
| ------------------------------------ | -------- | ------------------------- | --------------------------------------- |
| app_repository                       | ❌       | `github.repository`       | The GIT repository to build |
| app_branch_name                      | ❌       | `github.ref`              | The GIT branch to build |
| run_linter                           | ✅       |                           | Select the Linter to run (`pylint`, `flake8` or `yapf`) |
| run_type_check                       | ✅       | `false`                   | Whether to run mypy type check |
| req_directory                        | ❌       |                           | The directory containing the `requirements.txt` |
| setup_directory                      | ❌       |                           | The directory containing the `setup.cfg` |
| src_directory                        | ✅       |                           | The directory containing the python sources to check (relative to `setup_directory`) |
| additional_packages                  | ❌       |                           | Additional packages to install |

## Reusable Yaml Lint

In order to check an App, this workflow can use the following input parameters:

| Parameter                            | Required | Default value             | Comment                                 |
| ------------------------------------ | -------- | ------------------------- | --------------------------------------- |
| file_or_dir                          | ❌       | `.`                       | Files to check |

## Reusable Spell Checks

In order to check an App, this workflow can use the following input parameters:

| Parameter                            | Required | Default value             | Comment                                 |
| ------------------------------------ | -------- | ------------------------- | --------------------------------------- |
| app_repository                       | ❌       | `github.repository`       | The GIT repository to check |
| app_branch_name                      | ❌       | `github.ref`              | The GIT branch to check |
| check_filenames                      | ❌       | `true`                    | Whether to check filenames for misspellings|
| ignore_words_list                    | ❌       |                           | Comma-separated list of words to ignore |
| ignore_words_file                    | ❌       |                           | Path to a file containing words to ignore |
| src_path                             | ❌       |                           | Comma-separated list of paths to check for misspellings |

## Reusable CodeQL Checks

In order to build an App, this workflow can use the following input parameters:

| Parameter                    | Required | Default value             | Comment                                 |
| ---------------------------- | -------- | ------------------------- | --------------------------------------- |
| app_repository               | ❌       | `github.repository`       | The GIT repository to build |
| app_branch_name              | ❌       | `github.ref`              | The GIT branch to build |
| run_for_devices              | ❌       | *ALL*                     | The list of device(s) on which the CI will run |
| builder                      | ❌       | `ledger-app-builder-lite` | The docker image to build the application in |
| flags                        | ❌       |                           | Additional compilation flags |

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

| Parameter                            | Required | Default value             | Comment                                 |
| ------------------------------------ | -------- | ------------------------- | --------------------------------------- |
| app_repository                       | ❌       | `github.repository`       | The GIT repository to test |
| app_branch_name                      | ❌       | `github.ref`              | The GIT branch to test |
| test_directory                       | ✅       |                           | The directory containing the unit-tests to run |
| builder                              | ❌       | `ledger-app-builder-lite` | The docker image to build the application in |
| additional_packages                  | ❌       |                           | Additional packages to install |

For this workflow, it is important to also set the secrets for called workflow. For example:

```yml
jobs:
  job_unit_test:
    name: Call Ledger unit_test
    uses: LedgerHQ/ledger-app-workflows/.github/workflows/reusable_unit_tests.yml@v1
    secrets: inherit
    with:
      test_directory: tests/unit
```

## Reusable ClusterFuzzLite Tests

In order to test an App, this workflow can use the following input parameters:

| Parameter                            | Required | Default value             | Comment                                 |
| ------------------------------------ | -------- | ------------------------- | --------------------------------------- |
| exec_mode                            | ✅       |                           | Execution mode: `github.event_name` (`pull_request`, `push`, `schedule`)' |
| seconds_pr                           | ❌       | 300                       | Fuzzing duration in seconds for Pull Requests |
| seconds_push                         | ❌       | 600                       | Fuzzing duration in seconds when push on branch |
| seconds_schedule                     | ❌       | 18000                     | Fuzzing duration in seconds for scheduled tasks |

## Reusable Swap Tests

In order to test an App, this workflow can use the following input parameters:

| Parameter                            | Required | Default value             | Comment                                 |
| ------------------------------------ | -------- | ------------------------- | --------------------------------------- |
| app_repository                       | ❌       | `github.repository`       | The GIT repository to test |
| app_branch_name                      | ❌       | `github.ref`              | The GIT branch to test |
| download_app_binaries_artifact       | ❌       |                           | If not provided, the workflow will build the app to test |
| exchange_build_artifact              | ❌       |                           | If not provided, the workflow will build the `app-exchange` app |
| ethereum_build_artifact              | ❌       |                           | If not provided, the workflow will build the `app-ethereum` app |
| regenerate_snapshots                 | ❌       | `false`                   | Clean snapshots, regenerate them, commit the changes in a branch, and open a PR |

## Reusable pypi deployment

In order to deploy a package, this workflow can use the following input parameters:

| Parameter                            | Required | Default value             | Comment                                 |
| ------------------------------------ | -------- | ------------------------- | --------------------------------------- |
| repository_name                      | ❌       | `github.repository`       | The GIT repository to deploy |
| branch_name                          | ❌       | `github.ref`              | The GIT branch to deploy |
| container_image                      | ❌       | `ubuntu:24.04`            | The container image to use (in case extra deps are required) |
| package_name                         | ✅       |                           | The name of the package |
| package_directory                    | ❌       | `.`                       | The directory where the Python package lies |
| dry_run                              | ❌       | `false`                   | Whether to run all pre-publishing steps but skips the actual publishing |
| publish                              | ✅       | `true`                    | Whether the package should be published |
| release                              | ❌       | `true`                    | Whether the package should be packaged as a release |
| jfrog_deployment                     | ❌       | `false`                   | If the Python package should be pushed on `Ledger Jfrog` |

In addition, the following secret can be used:

| Parameter                    | Required | Default value             | Comment                                 |
| ---------------------------- | -------- | ------------------------- | --------------------------------------- |
| pypi_token                   | ✅       |                           | A token enabling to push a package on `pypi.org` |

## Reusable Check Ethereum SDK

No parameters for this workflow

## Reusable Documentation Generation

In order to check an App, this workflow can use the following input parameters:

| Parameter                    | Required | Default value             | Comment                                 |
| ---------------------------- | -------- | ------------------------- | --------------------------------------- |
| app_repository               | ❌       | `github.repository`       | The GIT repository to clone |
| app_branch_name              | ❌       | `github.ref`              | The GIT branch to clone |
| doxy_file                    | ❌       | `.doxygen/Doxyfile`       | Doxygen configuration file |

## Reusable NPM Deployment

In order to deploy an npm package, this workflow can use the following input parameters:

  | Parameter                    | Required | Default value                   | Comment                                                                         |
  | ---------------------------- | -------- | -------------------------       | ---------------------------------------                                         |
  | app_repository               | ❌       | `github.repository`             | The GIT repository to deploy                                                    |
  | app_ref_name                 | ❌       | `github.ref`                    | The GIT reference to deploy                                                     |
  | package_directory            | ❌       | `.`                             | The directory where the npm packages lies (where the package.json can be found) |
  | dry_run                      | ❌       | `false`                         | If true, runs all pre-publishing steps but run `npm publish --dry-run`          |
  | jfrog_deployment             | ❌       | `true`                          | Whether the npm package should be pushed on Ledger Jfrog or not.                |
  | jfrog_registry               | ❌       | `embedded-apps-npm-prod-public` | The package registry where the package will be pushed                           |
