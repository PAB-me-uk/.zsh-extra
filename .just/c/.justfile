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

# Create a new Calypso dev container
create-calypso-dev-container name="calypso":
  # j build-image 3.12 "" "1.9.5" "0.53.0" "0.66.9" # in dev-docker-image repo
  just --justfile "${HOME}/.zsh-extra/.just/k/.justfile" create-dev-container-no-pull {{name}} {{name}} "3.12-tf-1.9.5-tfl-0.53.0-tg-0.66.9"

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
  find /workspace/calypso/environment-definitions . -name "terragrunt.hcl" -not -path "*/.terragrunt-cache/*"

# Terragrunt - List all terragrunt.hcl files printing relative paths
tg-list-relative:
  find /workspace/calypso/environment-definitions . -name "terragrunt.hcl" -not -path "*/.terragrunt-cache/*" -printf "%P\n"

# Terragrunt - List all hcl files printing relative paths
tg-list-relative-hcl:
  find /workspace/calypso/environment-definitions . -name "*.hcl" -not -path "*/.terragrunt-cache/*" -printf "%P\n"

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

# AWS SSO login
azure-sso-login:
  az login --use-device-code

# AWS SSO login
azure-sso-login-tenant-level:
  az login --use-device-code --allow-no-subscriptions

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
  terragrunt hclfmt --terragrunt-check
  terraform fmt -recursive -check
  tflint --recursive
  tfsec --exclude-downloaded-modules
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

# Install dependencies
install:
  grep -qF 'export AWS_PROFILE=calypso-dev-us' ~/.zshrc || echo '\nexport AWS_PROFILE=calypso-dev-us' >> ~/.zshrc
  code --install-extension fredwangwang.vscode-hcl-format
  code --install-extension moshfeu.compare-folders
  code --install-extension ms-azure-devops.azure-pipelines

# Install Terragrunt
install-terragrunt version:
  sudo wget -O /usr/local/bin/terragrunt -q https://github.com/gruntwork-io/terragrunt/releases/download/v{{version}}/terragrunt_linux_amd64
  sudo chmod +x /usr/local/bin/terragrunt
  terragrunt --version

# Install Terraform
install-terraform version:
  #! /bin/bash
  set -eox pipefail
  mkdir -p /tmp/install-terraform
  cd /tmp/install-terraform
  wget -O terraform.zip -q https://releases.hashicorp.com/terraform/{{version}}/terraform_{{version}}_linux_amd64.zip
                           #https://releases.hashicorp.com/terraform/1.9.2/terraform_1.9.2_linux_amd64.zip
  unzip -qo terraform.zip
  sudo mv -f terraform /usr/bin/
  sudo chmod +x /usr/bin/terraform
  rm -rf /tmp/install-terraform