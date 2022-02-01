#!/bin/bash

set -eu

# Usage: ./fix_group_folders.sh <data_dir> <mysql|pgsql> <db_host> <db_user> <db_pwd> <db_name>

export data_dir="$(realpath "$1")"
export db_type="$2"
export db_host="$3"
export db_user="$4"
export db_pwd="$5"
export db_name="$6"

if [ "$db_type" == "mysql" ]
then
	for filepath in $(mysql \
		--skip-column-names \
		--silent \
		--host="$db_host" \
		--user="$db_user" \
		--password="$db_pwd" \
		--default-character-set=utf8 \
		--execute="\
			SELECT concat(oc_storages.id, oc_filecache.path) \
			FROM oc_storages JOIN oc_filecache ON oc_storages.numeric_id = oc_filecache.storage \
			WHERE oc_filecache.mtime < 86400 AND \
			oc_storages.id = 'local::$data_dir/'" \
			"$db_name" | sed -e "s/^.*:://")
	do
		if [ ! -f "$filepath" ]
		then
			echo "Can't find $filepath. Skipping."
			continue
		fi

		updated_mtime=$(stat --format=%Y "$filepath")
		relative_filepath="${filepath/#$data_dir\//}"
		base64_relative_filepath="$(printf '%s' "$relative_filepath" | base64)"

		mysql \
			--skip-column-names \
			--silent \
			--host="$db_host" \
			--user="$db_user" \
			--password="$db_pwd" \
			--default-character-set=utf8 \
			--execute="\
				UPDATE oc_filecache \
				SET mtime=$updated_mtime \
				WHERE \
				storage=(SELECT oc_storages.numeric_id FROM oc_storages WHERE oc_storages.id = 'local::$data_dir/') AND \
				mtime < 86400 AND \
				path=FROM_BASE64('$base64_relative_filepath')" \
				"$db_name"
	done
elif [ "$db_type" == "pgsql" ]
then
	for filepath in $(psql \
		"postgresql://$db_user:$db_pwd@$db_host/$db_name" \
		--tuples-only \
		--no-align \
		--command="\
			SELECT concat(oc_storages.id, oc_filecache.path) \
			FROM oc_storages JOIN oc_filecache ON oc_storages.numeric_id = oc_filecache.storage \
			WHERE oc_filecache.mtime < 86400 AND \
			oc_storages.id = 'local::$data_dir/'" | sed -e "s/^.*:://")
	do
		if [ ! -f "$filepath" ]
		then
			echo "Can't find $filepath. Skipping."
			continue
		fi

		updated_mtime=$(stat --format=%Y "$filepath")
		relative_filepath="${filepath/#$data_dir\//}"
		base64_relative_filepath="$(printf '%s' "$relative_filepath" | base64)"

		psql \
			"postgresql://$db_user:$db_pwd@$db_host/$db_name" \
			--command="\
				UPDATE oc_filecache \
				SET mtime=$updated_mtime \
				WHERE \
				storage=(SELECT oc_storages.numeric_id FROM oc_storages WHERE oc_storages.id = 'local::$data_dir/') AND \
				mtime < 86400 AND \
				path=CONVERT_FROM(DECODE('$base64_relative_filepath', 'base64'), 'UTF-8')"
	done
fi
