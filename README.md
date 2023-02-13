# Re-usable workflows for Ledger embedded applications

This project contains several reusable Github workflows meant to be included in Ledger embedded applications repositories.

Several of them are mandatory in order to ensure a level of quality and standardisation among all applications.
The mandatory workflows must pass for an application to be deployed on the Ledger store. 

Others are optional and are provided here to help developers create their own application for Ledger devices.

## Description of available workflows

- `app_compliance.yml`\
	This workflow is mandatory, itwill call several child reusable workflows.
	- `_check_icons.yml`\
		will ensure that the icons and glyphs used in your app will be displayable on the device.
	- `_check_makefile.yml`\
		will ensure that your Makefile is up to date and compatible with our deployment scripts.
	- `_check_readme.yml`\
		will ensure that your README is up to date.
	- `_check_clang_static_analyzer.yml`\
		will ensure that your application can compile and will perform quality checks.

- `build.yml` \
This workflow will perform a build and upload the artifact containing the compiled application.
This workflow is optional and is meant to help developers have their own CI.

- `ragger_tests.yml`\
This workflow will download the compiled application and run the tests using the ragger testing framework.
This workflow is optional and is meant to help developers have their own tests.

- `linter.yml` \
This workflow will perform linting checks on the application using DoozyX/clang-format-lint-action. 
This workflow is mandatory, however the content of the `.clang-format` file is not.

## Usage

Please see an exemple on how to use the reusable workflows in the `app-boilerplate` repository.
We will always keep the `app-boilerplate` repository complete and up-to-date in terms of workflows.
https://github.com/LedgerHQ/app-boilerplate
