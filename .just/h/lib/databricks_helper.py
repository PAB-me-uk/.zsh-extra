# %%
import json
import os
from copy import deepcopy
from functools import lru_cache

import git
import yaml
from databricks.sdk import WorkspaceClient


def get_git_root():
    git_repo = git.Repo(os.curdir, search_parent_directories=True)
    git_root = git_repo.git.rev_parse("--show-toplevel")
    return git_root


REPO_DIRECTORY = get_git_root()
RESOURCES_DIRECTORY = f"{REPO_DIRECTORY}/resources"
SQL_DIRECTORY = f"{REPO_DIRECTORY}/sql"
LEN_RESOURCES_DIRECTORY = len(RESOURCES_DIRECTORY)
TEMP_JOB_DIRECTORY = os.path.join(RESOURCES_DIRECTORY, "_temp_")
TARGET_PREFIX = "personal_dev"
DATABRICKS_PROFILE = "reporting"


@lru_cache()
def get_workspace_client(profile=DATABRICKS_PROFILE):
    return WorkspaceClient(profile=profile)


def list_jobs(profile=DATABRICKS_PROFILE):
    workspace_client = get_workspace_client(profile=profile)
    return workspace_client.jobs.list()


def get_schema_prefix(profile=DATABRICKS_PROFILE):
    workspace_client = get_workspace_client(profile)
    name = workspace_client.current_user.me().name
    return f"{name.given_name[0]}_{name.family_name}_".lower()


# next(list_jobs())
# %%


@lru_cache()
def load_databricks_configuration():
    return yaml.load(open(os.path.join(RESOURCES_DIRECTORY, "databricks.yml")), Loader=yaml.SafeLoader)


# def get_catalog_identifier(target):
#     configuration = load_databricks_configuration()
#     return configuration["targets"][target]["variables"]["ENV_CATALOG_IDENTIFIER"]


# def yield_job_definitions():
#     for path, _, files in os.walk(RESOURCES_DIRECTORY):
#         for file in files:
#             if file.endswith(".yml") and not path.endswith("_temp_"):
#                 contents = yaml.load(open(os.path.join(path, file)), Loader=yaml.SafeLoader)
#                 yield from contents.get("resources", {}).get("jobs", {}).items()


# def find_job_with_sql_task(sql_file):
#     end_of_sql_file_path = sql_file.split("/sql/")[-1]
#     print(end_of_sql_file_path)
#     jobs = yield_job_definitions()
#     for job_name, job in jobs:
#         print(job_name)
#         for task in job.get("tasks", []):
#             if "python_wheel_task" in task and task["python_wheel_task"][""]["path"].endswith(
#                 end_of_sql_file_path
#             ):
#                 return (job_name, job, task)


# def get_parameters_for_sql_task(target, job, task):
#     parameters = {
#         parameter["name"]: parameter["default"] for parameter in job.get("parameters", [])
#     } | task["sql_task"].get("parameters", {})
#     return {
#         key: value.replace("${var.ENV_CATALOG_IDENTIFIER}", get_catalog_identifier(target)).replace(
#             "${var.ENV_SCHEMA_PREFIX}", get_schema_prefix()
#         )
#         for key, value in parameters.items()
#     }


# def find_parameters_for_sql_task(target, sql_file):
#     job_name, job, task = find_job_with_sql_task(sql_file)
#     return get_parameters_for_sql_task(target, job, task)


# def create_temp_job_for_sql_task(target, sql_file):
#     job_name, job, task = find_job_with_sql_task(sql_file)
#     parameters = get_parameters_for_sql_task(target, job, task)
#     task = deepcopy(task)
#     if "depends_on" in task:
#         del task["depends_on"]
#     task["sql_task"]["parameters"] = parameters
#     task

#     structure = {
#         "resources": {
#             "jobs": {
#                 "temp_job": {
#                     "name": "temp_job_${bundle.target}",
#                     "permissions": [
#                         {
#                             "group_name": "SG-Databricks-Engineering-dev-na",
#                             "level": "CAN_MANAGE_RUN",
#                         }
#                     ],
#                     "tasks": [task],
#                 }
#             }
#         }
#     }
#     print(json.dumps(structure, indent=2))

#     os.makedirs(TEMP_JOB_DIRECTORY, exist_ok=True)
#     output_file = os.path.join(TEMP_JOB_DIRECTORY, "_temp_job.yml")
#     with open(output_file, "w") as file:
#         yaml.dump(structure, file, default_flow_style=False)

#     print()
#     print(output_file)
#     print()
#     print(f"Job definition saved to {output_file}")


def inject_parameters_into_sql_file(target, sql_file):
    # parameters = find_parameters_for_sql_task(target, sql_file)
    parameters = {"schema_prefix": "paul_burridge_", "catalog_prefix": "rpt_"}
    output = ["%sql\n"]
    with open(os.path.join(SQL_DIRECTORY, sql_file)) as file:
        while line := file.readline():
            if "{" in line:
                new_line = (
                    line.replace("\n", "")
                    # .replace("{{", "'{")
                    # .replace("}}", "}'")
                    .format(**parameters)
                )
                output.append(f"-- [ORIGINAL] {line}")
                output.append(f"{new_line} -- [REPLACEMENT]\n")
            elif "CREATE OR REPLACE" in line:
                output.append(f"-- [ORIGINAL] {line}")
            else:
                output.append(f"{line}")

    print("".join(output))


# def get_identifier_from_sql_file(target, sql_file):
#     parameters = find_parameters_for_sql_task(target, sql_file)
#     print(
#         ".".join(
#             [
#                 parameters.get("output_catalog_name", "?"),
#                 parameters.get("output_schema_name", "?"),
#                 os.path.split(sql_file)[-1][:-4],
#             ]
#         )
#     )
