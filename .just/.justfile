# .justfile contains commands to be run by the `just` command line tool.
# https://just.systems/man/en/

# See https://github.com/casey/just/issues/936 for the issue with the `--just-file` flag
# and autocompletion

workspace-path := "/workspace"

# Default recipe, runs if you just type `just`.
[private]
default:
  just --list --color always | less -R

[no-cd] # Disable the default cd to the directory containing the justfile
pwd:
  pwd

## Code Related ##

# Compile all Python requirement files.
[no-cd]
pip-compile-all:
  find . -name "requirements.in" -exec bash -c 'dir=$(dirname {}); pip-compile --annotation-style=line --resolver=backtracking --generate-hashes --allow-unsafe --output-file="${dir}/requirements.txt" "${dir}/requirements.in"' \

## AWS Related ##

# List EC2 instances with their instance-id, name and state.
ec2-list-instances:
  aws ec2 describe-instances --query "Reservations[].Instances[].{Name: Tags[?Key==\`Name\`].Value | [0], InstanceId: InstanceId, State: State.Name, LaunchTime: LaunchTime}" | jq -c '.[]'

# List EC2 instances with their instance-id, name and state, filtered by state.
ec2-list-instances-with-state state:
  aws ec2 describe-instances --query "Reservations[].Instances[?State.Name=='{{state}}'].{Name: Tags[?Key==\`Name\`].Value | [0], InstanceId: InstanceId, State: State.Name, LaunchTime: LaunchTime}" | jq -c '.[] | select(length > 0)[]'

ec2-list-instances-with-state-not-equal-to state:
  aws ec2 describe-instances --query "Reservations[].Instances[?State.Name!='{{state}}'].{Name: Tags[?Key==\`Name\`].Value | [0], InstanceId: InstanceId, State: State.Name, LaunchTime: LaunchTime}" | jq -c '.[] | select(length > 0)[]'

# Start an SSM session with an EC2 instance.
ec2-ssm-session:
  #! /bin/bash
  instance_id=$(just ec2-list-instances-with-state running | sort | fzf | jq -r '.InstanceId')
  just ssm-session-start ${instance_id}

# Enable termination prevention for an EC2 instance.
ec2-termination-prevention-enable:
  #! /bin/bash
  instance_id=$(just ec2-list-instances-with-state-not-equal-to terminated | sort | fzf | jq -r '.InstanceId')
  aws ec2 modify-instance-attribute --instance-id ${instance_id} --disable-api-termination

# Disable termination prevention for an EC2 instance.
ec2-termination-prevention-disable:
  #! /bin/bash
  instance_id=$(just ec2-list-instances-with-state-not-equal-to terminated | sort | fzf | jq -r '.InstanceId')
  aws ec2 modify-instance-attribute --instance-id ${instance_id} --no-disable-api-termination

[private]
[confirm]
ec2-terminate-instance-by-instance_id instance_id:
  aws ec2 terminate-instances --instance-ids {{instance_id}}

# Terminate an EC2 instance.
ec2-terminate-instance:
  #! /bin/bash
  instance_id=$(just ec2-list-instances-with-state-not-equal-to terminated | sort | fzf | jq -r '.InstanceId')
  echo "Are you sure you want to terminate the instance with id ${instance_id}?"
  just ec2-terminate-instance-by-instance_id ${instance_id}

# List EC2 Image Builder pipelines.
ec2-image-builder-pipeline-list:
  @aws imagebuilder list-image-pipelines --query "imagePipelineList[].{Name: name, Arn: arn}"  | jq -c '.[]'

[private]
ec2-image-builder-pipeline-list-fzf:
  #! /bin/bash
  selected=$(just ec2-image-builder-pipeline-list | fzf)
  arn=$(echo "${selected}" | jq -r '.Arn')
  name=$(echo "${selected}" | jq -r '.Name')
  recipe_name=$(echo ${name} | sed "s/-pipeline$/-recipe/")
  log_group_name="/aws/imagebuilder/${recipe_name}"
  echo "${name},${arn},${log_group_name}"

# Execute an EC2 Image Builder pipeline and tail the logs.
ec2-image-builder-pipeline-run:
  #! /bin/bash
  IFS=',' read -r name arn log_group_name var3 <<< "$(just ec2-image-builder-pipeline-list-fzf)"
  aws imagebuilder start-image-pipeline-execution --image-pipeline-arn ${arn}
  just cloudwatch-tail-logs ${log_group_name}

# Tail the logs of an EC2 Image Builder pipeline.
ec2-image-builder-pipeline-tail-logs since_mins="0":
  #! /bin/bash
  IFS=',' read -r name arn log_group_name var3 <<< "$(just ec2-image-builder-pipeline-list-fzf)"
  just cloudwatch-tail-logs ${log_group_name} {{since_mins}}

# Tail a log group by name.
cloudwatch-tail-logs log-group-name since_mins="0":
  aws logs tail --follow --since {{since_mins}}m {{log-group-name}}

# Invoke a lambda function and tail the logs.
lambda-function-invoke function-name payload="{}": && (lambda-function-tail-logs function-name)
  aws lambda invoke --function-name {{function-name}} --payload '{{payload}}' /dev/stdout

# Tail the logs of a lambda function.
lambda-function-tail-logs function-name:
  aws logs tail /aws/lambda/{{function-name}} --follow --since 1m

# Set the desired count for all autoscaling groups.
asg-set-disired-counts-for-all count:
  aws autoscaling describe-auto-scaling-groups --query "AutoScalingGroups[].AutoScalingGroupName" --output text | tr '\t' '\n' | xargs -I {} aws autoscaling update-auto-scaling-group --auto-scaling-group-name {} --min-size {{count}} --desired-capacity {{count}}

# Start an SSM session with the given instance-id.
ssm-session-start instance-id:
  aws ssm start-session --target {{instance-id}}

# Get source image details
ami-get-details name-filter="CIS*Amazon Linux 2023*Benchmark*Level 1*" architecture="x86_64": # or arm64
  aws ec2 describe-images --owners aws-marketplace --filters 'Name=name,Values={{name-filter}}' 'Name=architecture,Values={{architecture}}' --query 'sort_by(Images, &CreationDate) [::-1][][CreationDate,Name,ImageId]'

secret-list:
  aws secretsmanager list-secrets --query "SecretList[].Name" | jq -rc '.[]'

secret-get-value:
  #! /bin/bash
  secret=$(just secret-list | sort | fzf)
  aws secretsmanager get-secret-value --secret-id ${secret} --query "SecretString" | jq -r '.'

# Create a dev container
create-dev-container container-name volume-name python-version extra-mounts="":
  docker run --rm -it --env HOST_USER_HOME="${HOME}" --mount type=bind,source=/var/run/docker.sock,target=/var/run/docker.sock pabuk/dev-python:{{python-version}} /bin/zsh -c "/home/dev/.local/bin/create-dev-container {{container-name}} {{volume-name}} {{python-version}} .zsh-extra {{extra-mounts}}"

# Create a dev container from local image (no pull)
create-dev-container-no-pull container-name volume-name python-version extra-mounts="":
  docker run --rm -it --env HOST_USER_HOME="${HOME}" --mount type=bind,source=/var/run/docker.sock,target=/var/run/docker.sock pabuk/dev-python:{{python-version}} /bin/zsh -c "NO_PULL=1 /home/dev/.local/bin/create-dev-container {{container-name}} {{volume-name}} {{python-version}} .zsh-extra {{extra-mounts}}"

create-databricks-dev-container: (create-dev-container-no-pull "databricks" "databricks" "3.12-tf-1.9.2-tfl-0.44.1")

stacks-list:
  aws cloudformation list-stacks --query "StackSummaries[].StackName" --no-paginate | jq -rc '.[]'

stacks-list-no-af:
  aws cloudformation list-stacks --query "StackSummaries[].StackName" --no-paginate | jq -rc '.[]' | grep -v "AccountFundamentals"

@stacks-list-resources-no-af:
  #! /bin/bash
  set -eo pipefail
  just stacks-list-no-af | while IFS= read -r stack_name; do
    echo "Stack: ${stack_name}"
    just stack-resources-list ${stack_name}
  done

@stack-resources-list stack-name:
  aws cloudformation list-stack-resources --stack-name {{stack-name}} --query "StackResourceSummaries[].{ResourceType: ResourceType, PhysicalResourceId: PhysicalResourceId}" | jq -c '.[]'

## Utility ##

# Convert seconds to HMS.
seconds-to-hms seconds:
  #!/bin/bash
  seconds={{seconds}}
  hours=$((seconds / 3600))
  minutes=$(( (seconds % 3600) / 60))
  seconds=$((seconds % 60))
  echo "H${hours}M${minutes}S${seconds}"

# Convert minutes to HM.
minutes-to-hm minutes:
  #!/bin/bash
  minutes={{minutes}}
  hours=$(((minutes % 3600) / 60))
  minutes=$((minutes % 60))
  echo "H${hours}M${minutes}"

# Backup WSL.
backup-wsl:
  #!/usr/bin/env bash
  set -e
  backup_root=/mnt/c/Users/paul.burridge/Backups
  backup_folder="${backup_root}/$(date +'%Y_%d_%m_%H_%M_%S')"
  echo "Backing up to ${backup_folder}"
  mkdir -p "${backup_folder}"
  cp -rv "${HOME}/.ssh" "${backup_folder}/"
  cp -rv "${HOME}/.aws" "${backup_folder}/"
  cp -rv "${HOME}/.zsh-extra" "${backup_folder}/"
  cp -rv "${HOME}/.gitconfig" "${backup_folder}/"
  cp -rv "${HOME}/.zshrc" "${backup_folder}/"
  cp -rv "/etc/wsl.conf" "${backup_folder}/"
  mkdir -p "${backup_folder}/DevBoxGlobal"
  cp -v "${HOME}/.local/share/devbox/global/default/devbox.json" "${backup_folder}/DevBoxGlobal/"
  cp -v "${HOME}/.local/share/devbox/global/default/devbox.lock" "${backup_folder}/DevBoxGlobal/"
  mkdir -p "${backup_folder}/VsCodeUserSettings"
  cp -v /mnt/c/Users/paul.burridge/AppData/Roaming/Code/User/keybindings.json "${backup_folder}/VsCodeUserSettings/"
  cp -v /mnt/c/Users/paul.burridge/AppData/Roaming/Code/User/settings.json "${backup_folder}/VsCodeUserSettings/"
  cp -rv "/mnt/c/Users/paul.burridge/AppData/Roaming/Code/User/snippets" "${backup_folder}/VsCodeUserSettings/"

devbox-refresh:
  eval "$(devbox global shellenv --recompute)"
