# .justfile contains commands to be run by the `just` command line tool.
# https://just.systems/man/en/

workspace-path := "/workspace"
project-name := "databricks-infrastructure"
terraform-log-level := "INFO"

# Default recipe, runs if you just type `just`.
[private]
default:
  just --list --color always | less -R

# Install dependencies
install:
  echo "Installing dependencies..."
  gh auth login
  gh extension install https://github.com/nektos/gh-act

lint:
  echo "Linting..."
  sudo -E /bin/bash -c "time gh act -W '.github/workflows/tf-checks.yaml'"

[no-cd]
terragrunt command log-level=terraform-log-level extra-args="":
  #!/bin/bash
  set -eo pipefail
  export TF_LOG={{log-level}}
  export TERRAGRUNT_LOG_LEVEL={{log-level}}
  eval "$(lpass show --notes databricks.com | awk '(! /^[ \t]*#/) && (! /^$/) { print "export", $0 }')"
  env | grep '^TF_VAR_' | cut -d '=' -f 1 | awk '{print $0 " is set"}'
  if [[ "{{log-level}}" == "DEBUG" ]]; then
    time terragrunt {{command}} --terragrunt-debug
  else
    time terragrunt {{command}} {{extra-args}}
  fi

terragrunt-console-with-plan: (terragrunt "console" terraform-log-level "-plan")

[no-cd]
debug-using-terragrunt-var-file command log-level=terraform-log-level:
  #!/bin/bash
  set -eo pipefail
  export TF_LOG={{log-level}}
  export TERRAGRUNT_LOG_LEVEL={{log-level}}
  eval "$(lpass show --notes databricks.com | awk '(! /^[ \t]*#/) && (! /^$/) { print "export", $0 }')"
  env | grep '^TF_VAR_' | cut -d '=' -f 1 | awk '{print $0 " is set"}'
  terraform {{command}} -var-file=./terragrunt-debug.tfvars.json

create-calypso-dev-container name="calypso":
  just --justfile "${HOME}/.zsh-extra/.just/k/.justfile" create-dev-container-no-pull {{name}} {{name}} "3.12-tf-1.9.2-tfl-0.44.1"