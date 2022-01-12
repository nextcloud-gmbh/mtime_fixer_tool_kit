#!/bin/bash

set -eu

# Usage: ./list_problematic_files_on_db.sh <mysql|pgsql> <db_host> <db_user> <db_pwd> <db_name>

export db_type="$1"
export db_host="$2"
export db_user="$3"
export db_pwd="$4"
export db_name="$5"

if [ "$db_type" == "mysql" ]
then
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
		"$db_name"
elif [ "$db_type" == "pgsql" ]
then
	psql \
		"postgresql://$db_user:$db_pwd@$db_host/$db_name" \
		--tuples-only \
		--no-align \
		--command="\
	SELECT CONCAT(oc_storages.id, '/', oc_filecache.path) \
	FROM oc_storages JOIN oc_filecache ON oc_storages.numeric_id = oc_filecache.storage \
	WHERE oc_filecache.mtime<='86400'"
fi
