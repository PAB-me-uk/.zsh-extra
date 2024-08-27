# .justfile contains commands to be run by the `just` command line tool.
# https://just.systems/man/en/

workspace-path := "/workspace"
terraform-log-level := "INFO"
aws-profile := "calypso-dev-us"
terragrunt-flags := "--terragrunt-non-interactive --terragrunt-no-color"
export AWS_PROFILE := aws-profile

export TF_CLI_ARGS := "-no-color"

# Default recipe, runs if you just type `just`.
[private]
default:
  just --list --color always | less -R

# Install dependencies
# install:
#   echo "Installing dependencies..."
#   gh auth login
#   gh extension install https://github.com/nektos/gh-act

# lint:
#   echo "Linting..."
#   sudo -E /bin/bash -c "time gh act -W '.github/workflows/tf-checks.yaml'"

[no-cd]
tg command log-level=terraform-log-level extra-args="":
  #!/bin/bash
  set -eo pipefail
  export TF_LOG={{log-level}}
  export TERRAGRUNT_LOG_LEVEL={{log-level}}
  if [[ "{{log-level}}" == "DEBUG" ]]; then
    time terragrunt {{command}} {{terragrunt-flags}} --terragrunt-debug
  else
    time terragrunt {{command}} {{terragrunt-flags}} {{extra-args}}
  fi

[no-cd]
tg-run-all command log-level=terraform-log-level extra-args="":
  #!/bin/bash
  set -eo pipefail
  export TF_LOG={{log-level}}
  export TERRAGRUNT_LOG_LEVEL={{log-level}}
  if [[ "{{log-level}}" == "DEBUG" ]]; then
    time terragrunt {{terragrunt-flags}} run-all {{command}} --terragrunt-debug
  else
    time terragrunt {{terragrunt-flags}} run-all {{command}} {{extra-args}}
  fi

tg-console-with-plan: (tg "console" terraform-log-level "-plan")

[no-cd]
tg-debug-using-var-file command log-level=terraform-log-level:
  #!/bin/bash
  set -eo pipefail
  export TF_LOG={{log-level}}
  export TERRAGRUNT_LOG_LEVEL={{log-level}}
  terraform {{command}} -var-file=./terragrunt-debug.tfvars.json

create-calypso-dev-container name="calypso":
  just --justfile "${HOME}/.zsh-extra/.just/k/.justfile" create-dev-container-no-pull {{name}} {{name}} "3.12-tf-1.9.2-tfl-0.44.1"

tf-state-get:
  mkdir -p /workspace/tf-state
  aws s3 cp --recursive s3://nonprod-terraform-state-a3kgzd7g /workspace/tf-state

tf-state-list:
  aws s3 ls s3://nonprod-terraform-state-a3kgzd7g --recursive

tg-clean:
  find /workspace/calypso -type d -name ".terragrunt-cache" -exec rm -rf {} \;

aws-sso-login:
  aws sso login

