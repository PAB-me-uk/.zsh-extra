#!/usr/bin/env python
from fivetran_helper import dump_raw

# Note envar FTA needs to exist containing the Fivetran API key in base64
# See https://fivetran.com/docs/rest-api/getting-started#instructions
output_directory = "/workspace/fivetran/raw/"
dump_raw(output_directory)
