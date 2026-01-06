# Reusable workflows for Ledger embedded applications

This project contains several reusable Github workflows meant to be included in Ledger embedded applications repositories.

Several of them are mandatory in order to ensure a level of quality and standardisation among all applications.
The mandatory workflows must pass for an application to be deployed on the Ledger store.

Others are optional and are provided here to help developers create their own application for Ledger devices.

The workflows are based on the application manifest `ledger_app.toml`, which should be present at the root of the repo.
Having a correct and valid manifest is mandatory.

## Description of available workflows

- `reusable_guidelines_enforcer.yml`\
  This workflow is mandatory, it will call several child reusable workflows.
  - `_check_icons.yml`\
    will ensure that the icons and glyphs used in your app will be displayable on the device.
  - `_check_makefile.yml`\
    will ensure that your Makefile is up to date and compatible with our deployment scripts.
    It will also check that it does not contain production-incompatible flags (e.g. DEBUG=1).
  - `_check_readme.yml`\
    will ensure that your README is up to date.
  - `_check_clang_static_analyzer.yml`\
    will ensure that your application can compile and will perform quality checks.
  - `_check_app_load_params.yml`\
    will perform some checks of your application parameters vs the `ledger-app-database` config.


- `reusable_add_tag.yml` \
this workflow will automate the creation of tags which versions are listed in `CHANGELOG.md`. It can also automate the creation and update of specific tag (e.g. `v1` in this repo).

- `reusable_build.yml` \
This workflow is mandatory, it will perform a build and upload the artifact containing the compiled application. It guarantees that the app will be buildable in the deployment environment.

- `reusable_ragger_tests.yml`\
This workflow will download the compiled application and run the tests using the ragger testing framework.
This workflow is highly recommended and is meant to help developers have their own tests.

- `reusable_lint.yml` \
This workflow will perform linting checks on the application. \
For C application, `clang-format` is used, and the content of the `.clang-format` file can be customized. \
For Rust application, `cargo fmt` is used.

- `reusable_python_checks.yml` \
This workflow will check python formatting and linting. \
For the linters, it supports either `pylint` or `flake8`. \
For the Types checking, it supports `mypy`. \
This workflow is optional, but recommended.

- `reusable_yaml_lint.yml` \
This workflow will check yaml formatting and linting. \
A `.yamllint.yml` at the root of the repository can be customized. \
This workflow is optional, but recommended.

- `reusable_spell_checks.yml` \
This workflow will run misspelling checks on your code, using `codespell`. \
This workflow is optional, but recommended.

- `reusable_codeql_checks.yml` \
This workflow will analyze your application, using `CodeQL`. \
This workflow is optional, but recommended.

- `reusable_swap_tests.yml` \
This workflow will run Swap functional tests using `app-exchange`.

- `reusable_unit_tests.yml` \
This workflow will run the application unit-tests with Codecov coverage.
The results will be uploaded to codecov.io. \
This workflow is optional, but recommended.

- `reusable_pypi_deployment.yml` \
This workflow will build, check and deploy a Python package. This workflow is optional and is meant
to help developers to deploy application Python clients on `Ledger Jfrog` and `pypi.org`.

- `reusable_check_ethereum_sdk.yml` \
This workflow will check the `ethereum-plugin-sdk` submodule is up-to-date. \
This only apply for concerned applications.

- `reusable_doc_generation.yml` \
This workflow will generate the documentation, based on `doxygen`.

- `reusable_clusterfuzz_tests.yml` \
This workflow will run the application CI fuzzers, based on `ClusterFuzzLite`.

## Example

Please see an example on how to use the reusable workflows in the [`app-boilerplate`](https://github.com/LedgerHQ/app-boilerplate)
repository. We will always keep it complete and up-to-date in terms of workflows.

## Usage

Please refer to [docs](docs/usage.md) for details on the parameters for each workflow
