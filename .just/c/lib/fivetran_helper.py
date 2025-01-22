# %%
import json
from os import environ, path
from pathlib import Path
from urllib import error
from urllib.request import Request, urlopen

# Skipped for now
# https://api.fivetran.com/v1/metadata/connector-types/google_ads
# https://api.fivetran.com/v1/connectors/connector_id/state
# https://api.fivetran.com/v1/metadata/connector-types


def api_get(uri):
    url = f"https://api.fivetran.com/v1/{uri}"
    credentials = environ.get("FTA")
    print(f"GET {url}")
    try:
        with urlopen(
            Request(
                url=url,
                headers={
                    "Content-Type": "application/json",
                    "Authorization": f"Basic {credentials}",
                },
                method="GET",
            ),
            timeout=30,
        ) as response:
            contents = json.loads(response.read().decode())
            if contents.get("next_cursor"):
                raise SystemError("Pagination not implemented yet but we received a next_cursor")
            return contents["data"]
    except error.HTTPError as e:
        print(e)
        return None


def get_connector_list():
    return api_get("connectors")


def get_connector(connector_id):
    return api_get(f"connectors/{connector_id}")


def get_connector_state(connector_id):
    return api_get(f"connectors/{connector_id}/state")


def get_connector_schema(connector_id, log=True):
    # connector_id = get_connector_id(connector_name)
    return api_get(f"connectors/{connector_id}/schemas")


def get_destination_list():
    return api_get("destinations")


def get_destination(destination_id):
    return api_get(f"destinations/{destination_id}")


def get_connector_id(connector_name):
    return next(
        item["id"] for item in api_get("connectors")["items"] if item["schema"] == connector_name
    )


def print_connector_list():
    for item in sorted(get_connector_list()["items"], key=lambda i: i.get("schema")):
        print(f"{item['schema']} - {item['service']} - {item['id']}")


def print_connector_schema(connector_name):
    data = get_connector_schema(connector_name)
    for schema_name, schema in data["schemas"].items():
        destination_schema_name = schema["name_in_destination"]
        for table_name, table in schema["tables"].items():
            if table["enabled"]:
                print(
                    f"{schema_name}.{table_name} -> {destination_schema_name}.{table['name_in_destination']}"
                )
            else:
                print(f"{schema_name}.{table_name} -> X")


def dump_raw(output_directory):
    Path(output_directory).mkdir(parents=True, exist_ok=True)
    for item in get_connector_list()["items"]:
        connector_id = item["id"]
        connector_file_prefix = f"connector-{item['schema']}-{item['service']}-{connector_id}"
        print(connector_file_prefix)
        # Item from list of connectors
        with open(path.join(output_directory, f"{connector_file_prefix}-from-list.json"), "w") as f:
            f.write(json.dumps(item, indent=2))
        # Connector
        connector = get_connector(connector_id)
        if connector:
            with open(path.join(output_directory, f"{connector_file_prefix}.json"), "w") as f:
                f.write(json.dumps(connector, indent=2))
        # Schema
        schema = get_connector_schema(connector_id)
        if schema:
            with open(
                path.join(output_directory, f"{connector_file_prefix}-schema.json"), "w"
            ) as f:
                f.write(json.dumps(schema, indent=2))
    for item in get_destination_list()["items"]:
        destination_id = item["id"]
        destination = get_destination(destination_id)
        destination_file_prefix = "-".join(
            [
                "destination",
                destination["config"]["catalog"],
                destination["region"],
                destination["service"],
                destination_id,
            ]
        )
        with open(path.join(output_directory, f"{destination_file_prefix}.json"), "w") as f:
            f.write(json.dumps(destination, indent=2))


def dump(output_directory):
    """
    Limitations based on available API:

    Calculated fields that are not selectable in the UI (shows empty checkbox), still appear in schema column list as
    enabled, this may be Salesforce only?

    Ticket raised https://support.fivetran.com/hc/en-us/requests/241512
    """

    Path(path.join(output_directory, "all")).mkdir(parents=True, exist_ok=True)
    Path(path.join(output_directory, "enabled")).mkdir(parents=True, exist_ok=True)

    connectors = {
        item["id"]: {**get_connector(item["id"]), **{"schemas": get_connector_schema(item["id"])}}
        for item in get_connector_list()["items"]
    }

    destinations = {
        item["id"]: {**get_destination(item["id"])} for item in get_destination_list()["items"]
    }

    all_group_ids = {destination["group_id"] for destination in destinations.values()}.union(
        {connector["group_id"] for connector in connectors.values()}
    )

    groups = {
        group_id: {
            "connectors": {
                connector_id
                for connector_id in connectors
                if connectors[connector_id]["group_id"] == group_id
            },
            "destinations": {
                destination_id
                for destination_id in destinations
                if destinations[destination_id]["group_id"] == group_id
            },
        }
        for group_id in all_group_ids
    }

    # Append destinations
    connectors = {
        connector_id: {
            **connector,
            **{
                "destinations": [
                    destinations[destination_id]
                    for destination_id in groups[connector["group_id"]]["destinations"]
                ]
            },
        }
        for connector_id, connector in connectors.items()
    }

    for connector_id, connector in connectors.items():
        destination_catalogs = "-".join(
            [destination["config"]["catalog"] for destination in connector["destinations"]]
        )
        connector_file_prefix = "-".join(
            [
                "connector",
                connector["schema"],
                connector["service"],
                destination_catalogs,
                connector_id,
            ]
        )
        with open(
            path.join(output_directory, "all", f"{connector_file_prefix}-from-list.json"), "w"
        ) as f:
            f.write(json.dumps(connector, indent=2))

        if isinstance(connector["schemas"], dict) and "schemas" in connector["schemas"]:
            connector["schemas"]["schemas"] = filter_disabled(connector["schemas"]["schemas"])
            with open(
                path.join(output_directory, "enabled", f"{connector_file_prefix}-from-list.json"),
                "w",
            ) as f:
                f.write(json.dumps(connector, indent=2))


def dump_state(output_directory):
    Path(path.join(output_directory, "all")).mkdir(parents=True, exist_ok=True)
    Path(path.join(output_directory, "state")).mkdir(parents=True, exist_ok=True)

    state = {item["id"]: get_connector_state(item["id"]) for item in get_connector_list()["items"]}

    with open(path.join(output_directory, "state", f"state.json"), "w") as f:
        f.write(json.dumps(state, indent=2))


def filter_disabled(item):
    if isinstance(item, dict):
        return {
            key: filter_disabled(value)
            for key, value in item.items()
            if not isinstance(value, dict) or "enabled" not in value or value["enabled"]
        }
    return item


# To be refactored:


def get_table_columns(connector_name, find_table_name):
    data = get_connector_schema(connector_name, log=False)
    found = [
        (schema_name, schema["name_in_destination"], table_name, table)
        for schema_name, schema in data["schemas"].items()
        for table_name, table in schema["tables"].items()
        if table_name.lower() == find_table_name
        or table["name_in_destination"].lower() == find_table_name
    ]
    for schema_name, destination_schema_name, table_name, table in found:
        for column_name, column in table.get("columns", {}).items():
            if column["enabled"]:
                print(
                    f"{schema_name}.{table_name}.{column_name} -> {destination_schema_name}.{table['name_in_destination']}.{column['name_in_destination']}"
                )
            else:
                print(f"{schema_name}.{table_name}.{column_name} -> X")


# get_connector_schema
# get_connector_schema_raw
# get_table_columns
# list_connectors

# find_table_name = "opportunity_line_item".lower()
# with open("/workspace/calypso/data-pipelines/schema.json") as f:
#     data = json.loads(f.read())
#     table = [
#         table
#         for schema_name, schema in data["schemas"].items()
#         for table_name, table in schema["tables"].items()
#         if table_name.lower() == find_table_name
#         or table["name_in_destination"].lower() == find_table_name
#     ]
#     print(json.dumps(table[0], indent=2))
