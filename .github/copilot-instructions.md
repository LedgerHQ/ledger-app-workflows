# Copilot Instructions for .github/workflows

This repository contains reusable GitHub Actions workflows for building, testing, and deploying applications across our organization. To ensure consistency and efficiency, follow these guidelines when using GitHub Copilot to create or update workflow files.

## Communication Guidelines

**When uncertain or lacking knowledge:**
- If you have low confidence in how to complete a task, **state this explicitly** before attempting
- If you lack necessary information about APIs, patterns, or implementation details, **ask for clarification** rather than guessing
- If you don't know the correct approach, **say so** - do not waste time and API tokens on trial-and-error attempts
- It is better to admit "I don't know the API for this" than guess

## General Guidelines

- All workflow files are located in `.github/workflows/` and use the `.yml` extension.
- Workflows should be reusable via `workflow_call` and accept relevant inputs and secrets.
- Use descriptive names for workflows, jobs, and steps.
- Prefer organization-wide actions and Docker images when possible.
- Always include proper error handling and clear output for each step.
- These workflows rely on bash scripts located in the `scripts/` directory, so ensure that any new scripts are added there and referenced correctly in the workflow files.
- .pre-commit hooks are set up to validate workflow files before they are committed, so ensure that your workflow files pass validation checks.

## Workflow Structure

- Start each workflow with a clear `name` and `on` trigger.
- Use `jobs` to separate build, test, and deploy stages.
- Use `uses:` for reusable workflows and `run:` for custom shell commands.
- Use appropriate permissions for each job to limit access to necessary resources.
- Document required inputs and outputs in the workflow file.

## Best Practices

- Keep workflows modular and DRY (Don't Repeat Yourself).
- Use matrix builds for multi-platform or multi-version testing.
- Store secrets in GitHub Secrets and reference them securely.
- Add comments to explain complex steps or logic.
- Make sure to use latest versions of actions and dependencies to benefit from improvements and security patches.

## Example Snippet

```yaml
name: Reusable Build Workflow
on:
  workflow_call:
    inputs:
      app_name:
        required: true
        type: string
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Build ${{ inputs.app_name }}
        run: make build
```
