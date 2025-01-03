# %%
import json
import os
from urllib.request import Request, urlopen


def api_get(uri):
    url = f"https://api.fivetran.com/v1/{uri}"
    credentials = os.environ.get("FTA")
    print(f"GET {url}")
    with urlopen(
        Request(
            url=url,
            headers={"Content-Type": "application/json", "Authorization": f"Basic {credentials}"},
            method="GET",
        ),
        timeout=30,
    ) as response:
        contents = json.loads(response.read().decode())
        if contents.get("next_cursor"):
            raise SystemError("Pagination not implemented yet but we received a next_cursor")
        return contents["data"]


def list_connectors():
    for item in api_get("connectors")["items"]:
        print(f"{item['schema']} - {item['service']} - {item['id']}")


def get_connector_id(connector_name):
    return next(
        item["id"] for item in api_get("connectors")["items"] if item["schema"] == connector_name
    )


def get_connector_schema(connector_name, log=True):
    connector_id = get_connector_id(connector_name)
    data = api_get(f"connectors/{connector_id}/schemas")
    if log:
        for schema_name, schema in data["schemas"].items():
            destination_schema_name = schema["name_in_destination"]
            for table_name, table in schema["tables"].items():
                if table["enabled"]:
                    print(
                        f"{schema_name}.{table_name} -> {destination_schema_name}.{table['name_in_destination']}"
                    )
                else:
                    print(f"{schema_name}.{table_name} -> X")
    return data


def get_connector_schema_raw(connector_name):
    print(json.dumps(get_connector_schema(connector_name, log=False), indent=2))


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
