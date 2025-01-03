# .justfile contains commands to be run by the `just` command line tool.
# https://just.systems/man/en/

workspace-path := "/workspace"
terraform-log-level := "INFO"
aws-profile := "calypso-dev-na"
terragrunt-flags := "--terragrunt-non-interactive --terragrunt-no-color"
terrform-state-bucket := "nonprod-terraform-state-a3kgzd7g"
plugin-cache-dir := "/home/dev/terraform.d/plugin-cache"
repo-parent-dir := "/workspace/calypso"
self := "just --justfile '" + justfile() + "'"

export AWS_PROFILE := aws-profile
export TF_CLI_ARGS := "-no-color"
export TF_PLUGIN_CACHE_DIR := plugin-cache-dir
export DATABRICKS_CONFIG_PROFILE := "default"
# export TF_PLUGIN_CACHE_MAY_BREAK_DEPENDENCY_LOCK_FILE := "0"

# Default recipe, runs if you just type `just`.
[private]
default:
  just --list --color always | less -R

# Edit the current .justfile
edit:
  code {{justfile()}}

edit-databricks-helper:
  code /home/dev/.zsh-extra/.just/c/lib/databricks_helper.py

edit-fivetran-helper:
  code /home/dev/.zsh-extra/.just/c/lib/fivetran_helper.py

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
  grep -qF 'export AWS_PROFILE=calypso-dev-na' ~/.zshrc || echo '\nexport AWS_PROFILE=calypso-dev-na' >> ~/.zshrc
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
  pip install --upgrade pip
  pip install databricks-sdk==0.36.0


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
default-databricks-warehouse-id-us := "0df16878fb746ed5" # primary-serverless-dev-na (ID: 0df16878fb746ed5)
default-databricks-warehouse-id-eu := "e5665095820b5883"

[no-cd]
execute-sql sql_statement region profile warehouse-id:
  #! /bin/bash
  set -eox pipefail
  databricks api post "/api/2.0/sql/statements" \
  --target personal_dev_{{region}} \
  --profile {{profile}} \
  --json '{
    "warehouse_id": "{{warehouse-id}}",
    "statement": "{{sql_statement}}"
  }' | tee 'sql-execution-response.json'
  jq . 'sql-execution-response.json'
  statement_id=$(jq -r .statement_id 'sql-execution-response.json')
  echo "Statement ID: ${statement_id}"
  c check-sql statement_id {{region}}

# Execute SQL statement (c execute-sql-as-runner "$(cat | tr '\n' ' ')" for multiline paste the CTRL+D)

execute-sql-as-runner-us sql_statement: (execute-sql sql_statement "na" "workspace-primary-dev-na-sp-dev-na-runner" default-databricks-warehouse-id-us)
execute-sql-as-runner-eu sql_statement: (execute-sql sql_statement "eu" "workspace-primary-dev-eu-sp-dev-eu-runner" default-databricks-warehouse-id-eu)

[no-cd]
check-sql statement_id region:
  #! /bin/bash
  set -eo pipefail
  while :; do
    state=$(databricks api get "/api/2.0/sql/statements/{{statement_id}}" --target personal_dev_{{region}} --profile default-{{region}} | jq .status.state)
    echo "State: ${state}"
    if [[ "${state}" == "\"RUNNING\"" ]]; then
      sleep 10
    else
      break
    fi
  done

[no-cd]
databricks-bundle region:
  databricks bundle deploy --target personal_dev_{{region}} --profile default-{{region}} --auto-approve

sql-file-fzf:
  #! /bin/bash
  last_select_store_file="  "
  last_selected=""
  if [ -f "${last_select_store_file}" ]; then
    last_selected=$(cat "${last_select_store_file}")
  fi
  selected=$(find {{repo-parent-dir}}/data-pipelines/sql -name "*.sql" | sort | fzf --query="$last_selected")
  echo "${selected}" > "${last_select_store_file}"
  echo "${selected}"

databricks-jobs-fzf region:
  #! /bin/bash
  last_select_store_file="/tmp/fzf-last-selected-databricks-job"
  last_selected=""
  if [ -f "${last_select_store_file}" ]; then
    last_selected=$(cat "${last_select_store_file}")
  fi
  selected=$(databricks jobs list --target personal_dev_{{region}} --profile default-{{region}} | awk '{print substr($0, index($0,$2))}' | grep p_burridge | sort | fzf --query="$last_selected")
  echo "${selected}" | tee "${last_select_store_file}"

sql-file-inject-parameters region sql-file:
  #! /workspace/.python/3.11/bin/python
  import sys
  sys.path.append('.')
  from lib.databricks_helper import inject_parameters_into_sql_file
  inject_parameters_into_sql_file('{{region}}', '{{sql-file}}')

sql-file-inject-parameters-to-clipboard region:
  {{self}} sql-file-inject-parameters "{{region}}" "$({{self}} sql-file-fzf)" | xclip -selection clipboard

[private]
sql-file-get-parameters-internal region sql-file:
  #! /workspace/.python/3.11/bin/python
  import sys
  import json
  sys.path.append('.')
  from lib.databricks_helper import find_parameters_for_sql_task
  print(json.dumps(find_parameters_for_sql_task('{{region}}', '{{sql-file}}'), indent=2))

[no-cd]
sql-file-get-parameters region:
  {{self}} sql-file-get-parameters-internal {{region}} "$({{self}} sql-file-fzf)"

sql-file-create-temp-job region sql-file:
  #! /workspace/.python/3.11/bin/python
  import sys
  sys.path.append('.')
  from lib.databricks_helper import create_temp_job_for_sql_task
  create_temp_job_for_sql_task('{{region}}', '{{sql-file}}')

[private]
sql-file-get-identifier-internal region sql-file:
  #! /workspace/.python/3.11/bin/python
  import sys
  sys.path.append('.')
  from lib.databricks_helper import get_identifier_from_sql_file
  get_identifier_from_sql_file('{{region}}', '{{sql-file}}')

sql-file-identifier region:
  {{self}} sql-file-get-identifier-internal "{{region}}" "$({{self}} sql-file-fzf)" | xclip -selection clipboard
  echo "Added to clipboard"

[no-cd, private]
sql-file-prepare-internal sql-file:
  #! /bin/bash
  set -eo pipefail
  grep -v '\%sql' {{sql-file}} | \
  grep -v '\[REPLACEMENT\]' | \
  sed 's|\-\- \[ORIGINAL\]||g' > /tmp/sql-file-prepared.sql
  mv /tmp/sql-file-prepared.sql {{sql-file}}
  pdm sqlfluff_fix_file {{sql-file}} || true
  pdm sqlfluff_check_file {{sql-file}}

[no-cd, private]
databricks-execute-job-by-name-internal region job-name:
  #! /bin/bash
  set -eox pipefail
  echo "Job Name: {{job-name}}"
  if [ -z "{{job-name}}" ]; then
    echo "Variable job-name is empty, exiting."
    exit 1
  fi
  job_id=$(databricks jobs list --name '{{job-name}}_{{region}}' --target 'personal_dev_{{region}}' --profile 'default-{{region}}' | awk '{print $1}')
  echo "JobID: ${job_id}"
  databricks jobs run-now --timeout 2h --target personal_dev_{{region}} --profile default-{{region}} ${job_id}

[no-cd, private]
sql-file-execute-internal region sql-file: (sql-file-prepare-internal sql-file) (sql-file-create-temp-job region sql-file) (databricks-bundle region) (databricks-execute-job-by-name-internal region "[dev p_burridge] temp_job_personal_dev")

[no-cd]
sql-file-execute region:
  {{self}} sql-file-execute-internal {{region}} "$({{self}} sql-file-fzf)"

[no-cd, private]
databricks-execute-job-by-name region job-name: (databricks-bundle region) (databricks-execute-job-by-name-internal region job-name)
  echo "Job Name (final): {{job-name}}"

[no-cd]
databricks-execute-job region:
  {{self}} databricks-execute-job-by-name "{{region}}" "$({{self}} databricks-jobs-fzf {{region}})"

databricks-get-env-schema-prefix region:
  #! /bin/bash
  set -eo pipefail
  user=$(databricks current-user me --target personal_dev_{{region}} --profile default-{{region}}
  surname=$(echo ${user} | jq -r .name.familyName | tr '[:upper:]' '[:lower:]')
  forename=$(echo ${user} | jq -r .name.givenName | tr '[:upper:]' '[:lower:]')
  echo "${forename:0:1}_${surname}_"

databricks-get-bundle region:
  databricks fs cp --target personal_dev_{{region}} --profile default-{{region}} -r dbfs:/Workspace/Users/p.burridge@texthelp.com/.bundle /workspace/databricks-files/

databricks-ls region extra:
  databricks fs ls --target personal_dev_{{region}} --profile default-{{region}} dbfs:/{{extra}}

# fivetran-list-groups: (fivetran-api-get "groups")
fivetran-list-connectors:
  #! /workspace/.python/3.11/bin/python
  import sys
  sys.path.append('.')
  from lib.fivetran_helper import list_connectors
  list_connectors()

fivetran-list-columns connector-name table-name:
  #! /workspace/.python/3.11/bin/python
  import sys
  sys.path.append('.')
  from lib.fivetran_helper import get_table_columns
  get_table_columns("{{connector-name}}", "{{table-name}}")

fivetran-get-schema connector-name:
  #! /workspace/.python/3.11/bin/python
  import sys
  sys.path.append('.')
  from lib.fivetran_helper import get_connector_schema
  get_connector_schema("{{connector-name}}")

fivetran-get-schema-raw connector-name:
  #! /workspace/.python/3.11/bin/python
  import sys
  sys.path.append('.')
  from lib.fivetran_helper import get_connector_schema_raw
  get_connector_schema_raw("{{connector-name}}")

set dotenv-load
# set dotenv-required

test:
  echo "ABC=${ABC}"