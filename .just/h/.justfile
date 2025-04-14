# .justfile contains commands to be run by the `just` command line tool.
# https://just.systems/man/en/

workspace-path := "/workspace"
terraform-log-level := "INFO"
terragrunt-flags := "--terragrunt-non-interactive --terragrunt-no-color"
plugin-cache-dir := "/home/dev/terraform.d/plugin-cache"
repo-parent-dir := "/workspace"
self := "just --justfile '" + justfile() + "'"
default-databricks-profile := "reporting"
default-databricks-target := "personal_dev"

export TF_CLI_ARGS := "-no-color"
export TF_PLUGIN_CACHE_DIR := plugin-cache-dir
# export DATABRICKS_CONFIG_PROFILE := "??????????" # Causes clash with ARM_ envars (Azure Auth)
# export TF_PLUGIN_CACHE_MAY_BREAK_DEPENDENCY_LOCK_FILE := "0"

# Default recipe, runs if you just type `just`.
[private]
default:
  just --list --color always | less -R

# Edit the current .justfile
edit:
  code {{justfile()}}

edit-databricks-helper:
  code /home/dev/.zsh-extra/.just/h/lib/databricks_helper.py

# Edit the current .justfile
edit-env:
  code {{justfile_directory()}}/.env

### Terragrunt

# Terragrunt - Run
[no-cd]
tg command log-level=terraform-log-level extra-args="":
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

# Terragrunt - Delete cache directories and plan files.
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
# lint:
#   #! /bin/bash
#   set -oex pipefail
#   cd {{repo-parent-dir}}
#   terragrunt hclfmt --terragrunt-check
#   terraform fmt -recursive -check
#   tflint --recursive
#   cd {{repo-parent-dir}}/environment-definitions
#   tfsec --exclude-downloaded-modules
#   cd {{repo-parent-dir}}/platform_components
#   tfsec --exclude-downloaded-modules
#   cd {{repo-parent-dir}}/terraform-modules
#   tfsec --exclude-downloaded-modules

# Install dependencies
install:
  #! /bin/bash
  set -eox pipefail
  grep -qF 'export AWS_PROFILE=calypso-dev-na' ~/.zshrc || echo '\nexport AWS_PROFILE=calypso-dev-na' >> ~/.zshrc
  code --install-extension fredwangwang.vscode-hcl-format
  code --install-extension moshfeu.compare-folders
  code --install-extension ms-azure-devops.azure-pipelines
  sudo apt install -y xclip
  # dc install-terraform 1.9.2
  # dc install-terragrunt 0.66.9
  code --install-extension ms-python.python
  code --install-extension tamasfe.even-better-toml
  code --install-extension ms-python.mypy-type-checker
  code --install-extension charliermarsh.ruff
  code --install-extension ms-azuretools.vscode-docker
  code --install-extension elagil.pre-commit-helper
  code --install-extension databricks.databricks
  code --install-extension redhat.vscode-yaml
  pip install --upgrade pip
  pip install databricks-sdk==0.36.0
  sudo apt install -y wget apt-transport-https gpg
  wget -qO - https://packages.adoptium.net/artifactory/api/gpg/key/public | gpg --dearmor | sudo tee /etc/apt/trusted.gpg.d/adoptium.gpg > /dev/null
  echo "deb https://packages.adoptium.net/artifactory/deb $(awk -F= '/^VERSION_CODENAME/{print$2}' /etc/os-release) main" | sudo tee /etc/apt/sources.list.d/adoptium.list
  sudo apt update # update if you haven't already
  sudo apt install temurin-11-jdk -y
  sudo apt autoremove -y

[private]
sql-file-fzf:
  #! /bin/bash
  last_select_store_file="  "
  last_selected=""
  if [ -f "${last_select_store_file}" ]; then
    last_selected=$(cat "${last_select_store_file}")
  fi
  selected=$(find {{repo-parent-dir}}/internal-reporting-pipelines/sql -name "*.sql" | sort | fzf --query="$last_selected")
  echo "${selected}" > "${last_select_store_file}"
  echo "${selected}"


### Databricks

# Databricks bundle deployment
[no-cd]
databricks-bundle command='deploy':
  #! /bin/bash
  unset "${!ARM_@}" # Fix Error: validate: more than one authorization method configured: azure and oauth.
  cd /workspace/internal-reporting-pipelines/resources
  databricks bundle {{command}} --target personal_dev --profile {{default-databricks-profile}} --auto-approve

default-databricks-warehouse-id := "95c8d9ccb931f33c"

[no-cd,private]
databricks-execute-sql sql_statement target profile warehouse-id:
  #! /bin/bash
  set -eox pipefail
  unset "${!ARM_@}" # Fix Error: validate: more than one authorization method configured: azure and oauth.
  cd /workspace/internal-reporting-pipelines/resources
  databricks api post "/api/2.0/sql/statements" \
  --target {{target}} \
  --profile {{profile}} \
  --json '{
    "warehouse_id": "{{warehouse-id}}",
    "statement": "{{sql_statement}}"
  }' | tee 'sql-execution-response.json'
  jq . 'sql-execution-response.json'
  statement_id=$(jq -r .statement_id 'sql-execution-response.json')
  echo "Statement ID: ${statement_id}"

[no-cd]
databricks-check-sql statement_id target profile:
  #! /bin/bash
  set -eo pipefail
  unset "${!ARM_@}" # Fix Error: validate: more than one authorization method configured: azure and oauth.
  cd /workspace/internal-reporting-pipelines/resources
  while :; do
    state=$(databricks api get "/api/2.0/sql/statements/{{statement_id}}" --target {{target}} --profile {{profile}} | jq .status.state)
    echo "State: ${state}"
    if [[ "${state}" == "\"RUNNING\"" ]]; then
      sleep 10
    else
      break
    fi
  done

[no-cd]
databricks-get-schema-prefix target='personal_dev':
  #! /bin/bash
  set -eo pipefail
  unset "${!ARM_@}" # Fix Error: validate: more than one authorization method configured: azure and oauth.
  cd /workspace/internal-reporting-pipelines/resources
  user=$(databricks current-user me --target {{target}} --profile {{default-databricks-profile}})
  surname=$(echo ${user} | jq -r .name.familyName | tr '[:upper:]' '[:lower:]')
  forename=$(echo ${user} | jq -r .name.givenName | tr '[:upper:]' '[:lower:]')
  # echo "${forename:0:1}_${surname}_"
  echo "${forename}_${surname}_"

# Execute multiline SQL statement
# h databricks-execute-sql-as-fivetran-connector-sp "$(cat | tr '\n' ' ')"
# Paste SQL then press CTRL+D

databricks-execute-sql-as-fivetran-connector-sp sql_statement: (databricks-execute-sql sql_statement "reporting" "reporting-as-fivetran-connector-sp" default-databricks-warehouse-id)
databricks-check-sql-as-fivetran-connector-sp statement_id: (databricks-check-sql statement_id "reporting" "reporting-as-fivetran-connector-sp")

databricks-execute-sql-as-hummingbird-sp-prd sql_statement: (databricks-execute-sql sql_statement "reporting" "reporting-as-hummingbird-sp-prd" default-databricks-warehouse-id)
databricks-check-sql-as-hummingbird-sp-prd statement_id: (databricks-check-sql statement_id "reporting" "reporting-as-hummingbird-sp-prd")


### Job execution

databricks-jobs-fzf target=default-databricks-target:
  #! /bin/bash
  set -eo pipefail
  unset "${!ARM_@}"
  last_select_store_file="/tmp/fzf-last-selected-databricks-job"
  last_selected=""
  if [ -f "${last_select_store_file}" ]; then
    last_selected=$(cat "${last_select_store_file}")
  fi
  selected=$(databricks jobs list --target {{target}} --profile {{default-databricks-profile}} | awk '{print substr($0, index($0,$2))}' | grep paul_burridge | sort | fzf --query="$last_selected")
  echo "${selected}" | tee "${last_select_store_file}"

[no-cd, private]
databricks-execute-job-by-name-internal job-name target=default-databricks-target:
  #! /bin/bash
  set -eo pipefail
  unset "${!ARM_@}"
  echo "Job Name: {{job-name}}"
  if [ -z "{{job-name}}" ]; then
    echo "Variable job-name is empty, exiting."
    exit 1
  fi
  job_id=$(databricks jobs list --name '{{job-name}}' --target {{target}} --profile {{default-databricks-profile}} | awk '{print $1}')
  echo "JobID: ${job_id}"
  if [ -z "${job_id}" ]; then
    echo "Failed to identify job id, exiting."
    exit 1
  fi
  databricks jobs run-now --timeout 2h --target {{target}} --profile {{default-databricks-profile}} ${job_id}

[no-cd, private]
databricks-execute-job-by-name job-name target: (databricks-execute-job-by-name-internal job-name target)
  echo "Job Name (final): {{job-name}}"

[no-cd]
databricks-execute-job target=default-databricks-target:
  {{self}} databricks-execute-job-by-name "$({{self}} databricks-jobs-fzf {{target}})" "{{target}}"

### SQL File

sql-file-inject-parameters target sql-file:
  #! /workspace/.python/3.11/bin/python
  import sys
  sys.path.append('.')
  from lib.databricks_helper import inject_parameters_into_sql_file
  inject_parameters_into_sql_file('{{target}}', '{{sql-file}}')

sql-file-inject-parameters-to-clipboard target=default-databricks-target:
  {{self}} sql-file-inject-parameters "{{target}}" "$({{self}} sql-file-fzf)" | xclip -selection clipboard

### MISC


set dotenv-load
# set dotenv-required

# Display environment
env:
  env | sort
