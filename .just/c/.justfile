# .justfile contains commands to be run by the `just` command line tool.
# https://just.systems/man/en/

workspace-path := "/workspace"
terraform-log-level := "INFO"
aws-profile := "calypso-dev-us"
terragrunt-flags := "--terragrunt-non-interactive --terragrunt-no-color"
terrform-state-bucket := "nonprod-terraform-state-a3kgzd7g"
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

# Edit the current .justfile
edit:
  code {{justfile()}}


# Terragrunt - Run
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

# Terragrunt - Run all
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

# Terragrunt - Console with plan
tg-console-with-plan: (tg "console" terraform-log-level "-plan")

# Terragrunt - Debug using var file
[no-cd]
tg-debug-using-var-file command log-level=terraform-log-level:
  #!/bin/bash
  set -eo pipefail
  export TF_LOG={{log-level}}
  export TERRAGRUNT_LOG_LEVEL={{log-level}}
  terraform {{command}} -var-file=./terragrunt-debug.tfvars.json

# Create a new calypso dev container
create-calypso-dev-container name="calypso":
  just --justfile "${HOME}/.zsh-extra/.just/k/.justfile" create-dev-container-no-pull {{name}} {{name}} "3.12-tf-1.9.2-tfl-0.44.1"

# Terraform - Get state files from S3 bucket
tf-state-get:
  cd /workspace
  rm -rf /workspace/tf-state
  mkdir -p /workspace/tf-state
  aws s3 cp --recursive s3://{{terrform-state-bucket}} /workspace/tf-state

# Terrafform - List all state files in S3 bucket
tf-state-list:
  aws s3 ls s3://{{terrform-state-bucket}} --recursive

# Terragrunt - Clean terragrunt cache
tg-clean:
  find /workspace/calypso -type d -name ".terragrunt-cache" -exec rm -rf {} \;

# Terragrunt - List all terragrunt.hcl files
tg-list:
  find /workspace/calypso/environment-definitions . -name "terragrunt.hcl" | grep -v "\.terragrunt-cache"

# Terragrunt - Generate CD command and add to clipboard
tg-cd:
  just --justfile "{{justfile()}}" tg-list | fzf | xargs dirname | xargs echo cd | xclip -selection c

# Terrform - Create module
[no-cd]
tf-create-module name:
  mkdir -p {{name}}
  touch {{name}}/main.tf
  touch {{name}}/variables.tf
  touch {{name}}/outputs.tf
  touch {{name}}/providers.tf

# AWS SSO login
aws-sso-login:
  aws sso login

# Format all terraform and terragrunt files
format:
  #! /bin/bash
  set -eox pipefail
  cd /workspace/calypso
  terraform fmt -recursive
  terragrunt hclfmt

# Lint files
lint:
  #! /bin/bash
  set -eox pipefail
  cd /workspace/calypso
  terraform fmt -recursive -check
  terragrunt hclfmt --terragrunt-check

# Git - Tag branch
[no-cd]
git-branch-tag version:
  git tag -a {{version}} -m "Version {{version}}"
  git push origin {{version}}

# Git - Tag branch and force push
[no-cd]
git-branch-tag-force version:
  git push origin :refs/tags/{{version}}
  git tag -a {{version}} -m "Version {{version}}" -f
  git push origin {{version}}