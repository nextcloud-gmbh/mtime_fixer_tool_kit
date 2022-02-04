#!/bin/bash

set -eu

# Usage: ./solvable_files.sh <data_dir> <mysql|pgsql> <db_host> <db_user> <db_pwd> <db_name> <fix,list> <scan,noscan>

export data_dir="$(realpath "$1")"
export db_type="$2"
export db_host="$3"
export db_user="$4"
export db_pwd="$5"
export db_name="$6"
export action="${7:-list}"
export scan_action="${8:-noscan}"

# 1. Return if fs mtime <= 86400
# 2. Compute username from filepath
# 3. Query mtime from the database with the filename and the username
# 4. Return if mtime_on_fs != mtime_in_db
# 5. Correct the fs mtime with touch
function correct_mtime() {
	filepath="$1"
	relative_filepath="${filepath/#$data_dir\//}"
	mtime_on_fs="$(stat -c '%Y' "$filepath")"

	username=$relative_filepath
	while [ "$(dirname "$username")" != "." ]
	do
		username=$(dirname "$username")
	done

	relative_filepath_without_username="${relative_filepath/#$username\//}"

	base64_relative_filepath="$(printf '%s' "$relative_filepath" | base64)"
	base64_relative_filepath_without_username="$(printf '%s' "$relative_filepath_without_username" | base64)"

	if [ "$username" == "__groupfolders" ]
	then
		if [ "$db_type" == "mysql" ]
		then
			mtime_in_db=$(
				mysql \
					--skip-column-names \
					--silent \
					--host="$db_host" \
					--user="$db_user" \
					--password="$db_pwd" \
					--default-character-set=utf8 \
					--execute="\
						SELECT mtime
						FROM oc_storages JOIN oc_filecache ON oc_storages.numeric_id = oc_filecache.storage \
						WHERE oc_storages.id='local::$data_dir/' AND oc_filecache.path=FROM_BASE64('$base64_relative_filepath')" \
					"$db_name"
			)
		elif [ "$db_type" == "pgsql" ]
		then
			mtime_in_db=$(
				psql \
					"postgresql://$db_user:$db_pwd@$db_host/$db_name" \
					--tuples-only \
					--no-align \
					--command="\
						SELECT mtime
						FROM oc_storages JOIN oc_filecache ON oc_storages.numeric_id = oc_filecache.storage \
						WHERE oc_storages.id='local::$data_dir/' AND oc_filecache.path=CONVERT_FROM(DECODE('$base64_relative_filepath', 'base64'), 'UTF-8')"
			)
		fi
	else
		if [ "$db_type" == "mysql" ]
		then
			mtime_in_db=$(
				mysql \
					--skip-column-names \
					--silent \
					--host="$db_host" \
					--user="$db_user" \
					--password="$db_pwd" \
					--default-character-set=utf8 \
					--execute="\
						SELECT mtime
						FROM oc_storages JOIN oc_filecache ON oc_storages.numeric_id = oc_filecache.storage \
						WHERE oc_storages.id='home::$username' AND oc_filecache.path=FROM_BASE64('$base64_relative_filepath_without_username')" \
					"$db_name"
			)
		elif [ "$db_type" == "pgsql" ]
		then
			mtime_in_db=$(
				psql \
					"postgresql://$db_user:$db_pwd@$db_host/$db_name" \
					--tuples-only \
					--no-align \
					--command="\
						SELECT mtime
						FROM oc_storages JOIN oc_filecache ON oc_storages.numeric_id = oc_filecache.storage \
						WHERE oc_storages.id='home::$username' AND oc_filecache.path=CONVERT_FROM(DECODE('$base64_relative_filepath_without_username', 'base64'), 'UTF-8')"
			)
		fi
	fi

	if [ "$mtime_in_db" == "" ]
	then
		return
	fi

	if [ "$mtime_in_db" != "$mtime_on_fs" ]
	then
		echo "mtime in database do not match fs mtime (fs: $mtime_on_fs, db: $mtime_in_db). Skipping $filepath"
		return
	fi

	echo "$filepath"

	if [ "$action" == "fix" ]
	then
		touch -c "$filepath"
		if [ "$scan_action" = "scan" ]
		then
			sudo -u "$(stat -c '%U' ./occ)" php ./occ files:scan --quiet --path="$relative_filepath"
		fi
	fi
}
export -f correct_mtime

find "$data_dir" -type f ! -newermt "@86400" -exec bash -c 'correct_mtime "$0"' {} \;
