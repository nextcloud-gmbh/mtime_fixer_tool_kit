#!/bin/bash

set -eu

# Usage: ./unsolvable_files.sh <data_dir> <db_host> <db_user> <db_pwd> <db_table>

export data_dir="$1"
export db_host="$2"
export db_user="$3"
export db_pwd="$4"
export db_table="$5"

cd "$(dirname -- "${BASH_SOURCE[0]}")"

{
	./list_problematic_files_on_fs.sh "$data_dir" &
	./list_problematic_files_on_db.sh "$db_host" "$db_user" "$db_pwd" "$db_table"
} | sort | uniq -u

