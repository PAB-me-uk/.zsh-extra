# .justfile contains commands to be run by the `just` command line tool.
# https://just.systems/man/en/

workspace-path := "/workspace"
terraform-log-level := "INFO"
aws-profile := "calypso-dev-us"
terragrunt-flags := "--terragrunt-non-interactive --terragrunt-no-color"
terrform-state-bucket := "nonprod-terraform-state-a3kgzd7g"
plugin-cache-dir := "/home/dev/terraform.d/plugin-cache"
repo-parent-dir := "/workspace/calypso"
self := "just --justfile '" + justfile() + "'"

export AWS_PROFILE := aws-profile
export TF_CLI_ARGS := "-no-color"
export TF_PLUGIN_CACHE_DIR := plugin-cache-dir
# export TF_PLUGIN_CACHE_MAY_BREAK_DEPENDENCY_LOCK_FILE := "0"

# Default recipe, runs if you just type `just`.
[private]
default:
  just --list --color always | less -R

# Edit the current .justfile
edit:
  code {{justfile()}}

# Terragrunt - Run
[no-cd]
tg command log-level=terraform-log-level extra-args="": switch-source-to-absolute-path && switch-source-to-git
  #!/bin/bash
  set -eo pipefail
  log_file=/tmp/{{command}}$(pwd | sed 's/\//-/g').log
  export TF_LOG={{log-level}}
  export TERRAGRUNT_LOG_LEVEL={{log-level}}
  mkdir -p {{plugin-cache-dir}}
  if [[ "{{log-level}}" == "DEBUG" ]]; then
    terragrunt {{command}} {{terragrunt-flags}} --terragrunt-debug 2>&1 | tee ${log_file}
  else
    terragrunt {{command}} {{terragrunt-flags}} {{extra-args}} --terragrunt-debug 2>&1 | tee ${log_file}
  fi
  echo "Logged to ${log_file}"

# Terragrunt - Run all
[no-cd]
tg-run-all command log-level=terraform-log-level extra-args="": switch-source-to-absolute-path && switch-source-to-git
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
  #! /bin/bash
  find {{repo-parent-dir}} -type d -name ".terragrunt-cache" -exec rm -rf {} \;
  find {{repo-parent-dir}} -type d -name ".terraform" -exec rm -rf {} \;
  find {{repo-parent-dir}} -type d -name "_plan_files" -exec rm -rf {} \;
  find {{repo-parent-dir}} -type f -name "terragrunt-debug.tfvars.json" -exec rm -rf {} \;

# Terragrunt - List all terragrunt.hcl files
tg-list:
  find {{repo-parent-dir}}/environment-definitions . -name "terragrunt.hcl" -not -path "*/.terragrunt-cache/*" | sort

# Terragrunt - List all terragrunt.hcl files printing relative paths
tg-list-relative:
  find {{repo-parent-dir}}/environment-definitions . -name "terragrunt.hcl" -not -path "*/.terragrunt-cache/*" -printf "%P\n" | sort

# Terragrunt - List all hcl files printing relative paths
tg-list-relative-hcl:
  find {{repo-parent-dir}}/environment-definitions . -name "*.hcl" -not -path "*/.terragrunt-cache/*" -not -name ".terraform.lock.hcl" -printf "%P\n" | sort

# Terragrunt - Generate CD command and add to clipboard
tg-cd:
  {{self}} tg-list | fzf | xargs dirname | xargs echo cd | xclip -selection c

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
  cd {{repo-parent-dir}}
  terraform fmt -recursive
  terragrunt hclfmt

# Lint files
lint:
  #! /bin/bash
  set -oex pipefail
  cd {{repo-parent-dir}}
  terragrunt hclfmt --terragrunt-check
  terraform fmt -recursive -check
  tflint --recursive
  cd {{repo-parent-dir}}/environment-definitions
  tfsec --exclude-downloaded-modules
  cd {{repo-parent-dir}}/platform_components
  tfsec --exclude-downloaded-modules
  cd {{repo-parent-dir}}/terraform-modules
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
  #! /bin/bash
  set -eox pipefail
  grep -qF 'export AWS_PROFILE=calypso-dev-us' ~/.zshrc || echo '\nexport AWS_PROFILE=calypso-dev-us' >> ~/.zshrc
  code --install-extension fredwangwang.vscode-hcl-format
  code --install-extension moshfeu.compare-folders
  code --install-extension ms-azure-devops.azure-pipelines
  sudo apt install -y xclip
  dc install-terraform 1.9.2
  dc install-terragrunt 0.66.9
  code --install-extension ms-python.python
  code --install-extension tamasfe.even-better-toml
  code --install-extension ms-python.mypy-type-checker
  code --install-extension charliermarsh.ruff
  code --install-extension ms-azuretools.vscode-docker
  code --install-extension elagil.pre-commit-helper
  code --install-extension databricks.databricks
  code --install-extension redhat.vscode-yaml

# Switch source references to absolute path
switch-source-to-absolute-path:
  #! /bin/bash
  set -eo pipefail
  REPOS_PARENT_DIR={{repo-parent-dir}}
  cd ${REPOS_PARENT_DIR}
  find \( -name "*.tf" -o -name "*.hcl" \) -exec sed -i -E "s|^(\s+)source(\s+)=(\s+)\"git::ssh://git@ssh.dev.azure.com/v3/texthelp-ltd/Data%20Hub/([^?]+)([^\"]+).*$|\1source\2=\3\"${REPOS_PARENT_DIR}/\4\" # \5|g" {} \;

# Switch source references to git
switch-source-to-git:
  #! /bin/bash
  set -eo pipefail
  REPOS_PARENT_DIR={{repo-parent-dir}}
  cd ${REPOS_PARENT_DIR}
  find \( -name "*.tf" -o -name "*.hcl" \) -exec sed -i -E "s|^(\s+)source(\s+)=(\s+)\"${REPOS_PARENT_DIR}/([^\"]+)[^?]*(.*)$|\1source\2=\3\"git::ssh://git@ssh.dev.azure.com/v3/texthelp-ltd/Data%20Hub/\4\5\"|g" {} \;

[no-cd]
tg-dev-plan-original:
  cd /workspace/terragrunt-original
  go run main.go run-all init --terragrunt-non-interactive --terragrunt-working-dir {{repo-parent-dir}}/environment-definitions/nonprod/na/projects/datahub/dev-na/us-east-2/databricks
  # go run main.go run-all plan --terragrunt-non-interactive --terragrunt-out-dir /tmp/plan-files --terragrunt-working-dir {{repo-parent-dir}}/environment-definitions/nonprod/na/projects/datahub/dev-na/us-east-2/databricks
  # go run main.go run-all plan --terragrunt-non-interactive --terragrunt-out-dir ./plan-files --terragrunt-working-dir {{repo-parent-dir}}/environment-definitions/nonprod/na/projects/datahub/dev-na/us-east-2/databricks
  # go run main.go run-all plan --terragrunt-non-interactive --terragrunt-out-dir /tmp/plan-files --terragrunt-working-dir ../calypso/environment-definitions/nonprod/na/projects/datahub/dev-na/us-east-2/databricks
  # go run main.go run-all plan --terragrunt-non-interactive --terragrunt-out-dir /tmp/plan-files --terragrunt-working-dir ../calypso/environment-definitions/nonprod/na/projects/datahub/dev-na/us-east-2/databricks

[no-cd]
tg-dev-plan:
  go run /workspace/terragrunt/main.go run-all init --terragrunt-non-interactive --terragrunt-out-dir /tmp/plan-files --terragrunt-working-dir {{repo-parent-dir}}/environment-definitions/nonprod/na/projects/datahub/dev-na/us-east-2/databricks
  go run /workspace/terragrunt/main.go run-all plan --terragrunt-non-interactive --terragrunt-out-dir /tmp/plan-files --terragrunt-working-dir {{repo-parent-dir}}/environment-definitions/nonprod/na/projects/datahub/dev-na/us-east-2/databricks

[no-cd]
tg-dev-plan-exe:
  /workspace/terragrunt/terragrunt run-all plan --terragrunt-non-interactive --terragrunt-out-dir /tmp/plan-files
  # --terragrunt-working-dir {{repo-parent-dir}}/environment-definitions/nonprod/na/projects/datahub/dev-na/us-east-2/databricks

# [no-cd]
# tg-dev-test-1:
#   /workspace/terragrunt-original/terragrunt
default-profile := "workspace-primary-dev-na"
default-databricks-warehouse_id := "0df16878fb746ed5" # primary-serverless-dev-na (ID: 0df16878fb746ed5)
[no-cd]
execute-sql sql_statement profile=default-profile:
  #! /bin/bash
  set -eo pipefail
  echo {{profile}}
  databricks api post "/api/2.0/sql/statements" \
  --profile {{profile}} \
  --json '{
    "warehouse_id": "{{default-databricks-warehouse_id}}",
    "statement": "{{sql_statement}}"
  }' | tee 'sql-execution-response.json'
  jq . 'sql-execution-response.json'
  statement_id=$(jq -r .statement_id 'sql-execution-response.json')
  echo "Statement ID: ${statement_id}"
  c check-sql statement_id profile={{profile}}

# Execute SQL statement (c execute-sql "$(cat | tr '\n' ' ')" for multiline paste the CTRL+D)

execute-sql-as-runner sql_statement: (execute-sql sql_statement "workspace-primary-dev-na-sp-dev-na-runner")

[no-cd]
check-sql statement_id profile=default-profile:
  #! /bin/bash
  set -eo pipefail
  while :; do
    state=$(databricks api get "/api/2.0/sql/statements/{{statement_id}}" --profile {{profile}} | jq .status.state)
    echo "State: ${state}"
    if [[ "${state}" == "\"RUNNING\"" ]]; then
      sleep 10
    else
      break
    fi
  done

[no-cd]
databricks-bundle:
  databricks bundle deploy --target personal_dev --profile default

sql-file-inject-parameters sql-file:
  #! /workspace/.python/3.11/bin/python
  import sys
  sys.path.append('.')
  from lib.databricks_helper import inject_parameters_into_sql_file
  inject_parameters_into_sql_file('{{sql-file}}')

sql-file-inject-parameters-to-clipboard:
  {{self}} sql-file-inject-parameters "$({{self}} sql-file-fzf)" | xclip -selection clipboard

sql-file-fzf:
  find {{repo-parent-dir}}/data-pipelines/sql -name "*.sql" | sort | fzf

create-temp-job-for-sql-task sql-file:
  #! /workspace/.python/3.11/bin/python
  import sys
  sys.path.append('.')
  from lib.databricks_helper import create_temp_job_for_sql_task
  create_temp_job_for_sql_task('{{sql-file}}')

test:
  echo {{self}}