#!/bin/bash

set -eu

# Usage: ./list_problematic_files_on_db.sh <db_host> <db_user> <db_pwd> <db_table>

export db_host="$1"
export db_user="$2"
export db_pwd="$3"
export db_table="$4"

mysql \
	--skip-column-names \
	--silent \
	--host="$db_host" \
	--user="$db_user" \
	--password="$db_pwd" \
	--execute="\
SELECT CONCAT(oc_storages.id, '/', oc_filecache.path) \
FROM oc_storages JOIN oc_filecache ON oc_storages.numeric_id = oc_filecache.storage \
WHERE oc_filecache.mtime<='86400'" \
	"$db_table"
