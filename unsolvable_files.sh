#!/bin/bash

set -eu

# Usage: ./unsolvable_files.sh <data_dir> <mysql|pgsql> <db_host> <db_user> <db_pwd> <db_name>

export data_dir="$(realpath "$1")"
export db_type="$2"
export db_host="$3"
export db_user="$4"
export db_pwd="$5"
export db_name="$6"

cd "$(dirname -- "${BASH_SOURCE[0]}")"

{
	./list_problematic_files_on_fs.sh "$data_dir" &
	./list_problematic_files_on_db.sh "$db_type" "$db_host" "$db_user" "$db_pwd" "$db_name"
} | sort | uniq -u

