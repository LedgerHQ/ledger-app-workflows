# Re-usable workflows for Ledger embedded applications

This project contains several reusable Github workflows meant to be included in Ledger embedded applications repositories.

Several of them are mandatory in order to ensure a level of quality and standardisation among all applications.
The mandatory workflows must pass for an application to be deployed on the Ledger store.

Others are optional and are provided here to help developers create their own application for Ledger devices.

Some of these workflows can be configured to run only on a specified subset of
the Ledger devices (via the `run_for_devices` option). The application will not
be deployed on the Ledger store for devices excluded from mandatory workflows.

## Description of available workflows

- `reusable_guidelines_enforcer.yml`\
	This workflow is **mandatory**. It will call several child reusable workflows.
	- `_check_icons.yml`\
		will ensure that the icons and glyphs used in your app will be displayable on the device.
	- `_check_makefile.yml`\
		will ensure that your Makefile is up to date and compatible with our deployment scripts.
	- `_check_readme.yml`\
		will ensure that your README is up to date.
	- `_check_clang_static_analyzer.yml`\
		will ensure that your application can compile and will perform quality checks.

- `reusable_build.yml` \
This workflow will perform a build and upload the artifact containing the compiled application.
This workflow is **optional**, as long as another workflow building the application exists.
It is meant to help developers have their own CI.

- `reusable_ragger_tests.yml`\
This workflow will download the compiled application and run the tests using the ragger testing framework.
This workflow is **optional**, as long as another workflow testing the application exists.
It is meant to help developers have their own tests.

- `reusable_lint.yml` \
This workflow will perform linting checks on the application using DoozyX/clang-format-lint-action.
This workflow is **mandatory**, however the content of the `.clang-format` file is not.

## Usage

Please see an example on how to use the reusable workflows in the `app-boilerplate` repository.
We will always keep the `app-boilerplate` repository complete and up-to-date in terms of workflows.
https://github.com/LedgerHQ/app-boilerplate
