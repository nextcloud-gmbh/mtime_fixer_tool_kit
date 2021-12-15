#!/bin/bash

set -eu

# Usage: ./solvable_files.sh <data_dir> <db_host> <db_user> <db_pwd> <db_table> <fix,list>

export data_dir="$1"
export db_host="$2"
export db_user="$3"
export db_pwd="$4"
export db_table="$5"
export action="${6:-list}"

if [ "${data_dir:0:1}" != "/" ]
then
	echo "data_dir must be absolute."
	exit 1
fi

# 1. Return if fs mtime != -3600
# 2. Compute username from filepath
# 3. Query mtime from the database with the filename and the username
# 4. Return if mtime_on_fs != mtime_in_db
# 5. Correct the fs mtime with touch
# 6. Run occ files:scan on the file
function correct_mtime() {
	filepath="$1"
	filename="$(basename "$filepath")"
	relative_filepath="${filepath//$data_dir/}"
	mtime_on_fs="$(stat -c '%Y' "$filepath")"

	if [ "$mtime_on_fs" != '-3600' ]
	then
		return
	fi

	username=$relative_filepath
	while [ "$(dirname "$username")" != "." ]
	do
		username=$(dirname "$username")
	done

	if [ "$username" == "__groupfolders" ]
	then
		mtime_in_db=$(
			mysql \
				--skip-column-names \
				--silent \
				--host="$db_host" \
				--user="$db_user" \
				--password="$db_pwd" \
				--execute="\
					SELECT mtime
					FROM oc_storages JOIN oc_filecache ON oc_storages.numeric_id = oc_filecache.storage \
					WHERE oc_storages.id='local::$data_dir' AND oc_filecache.name='$filename'" \
				"$db_table"
			)
	else
		mtime_in_db=$(
			mysql \
				--skip-column-names \
				--silent \
				--host="$db_host" \
				--user="$db_user" \
				--password="$db_pwd" \
				--execute="\
					SELECT mtime
					FROM oc_storages JOIN oc_filecache ON oc_storages.numeric_id = oc_filecache.storage \
					WHERE oc_storages.id='home::$username' AND oc_filecache.name='$filename'" \
				"$db_table"
			)
	fi

	if [ "$mtime_in_db" != "$mtime_on_fs" ]
	then
		echo "mtime in database do not match fs mtime (fs: $mtime_on_fs, db: $mtime_in_db). Skipping $filepath"
		return
	fi

	echo "$filepath"

	if [ "$action" = "fix" ]
	then
		touch --no-create "$filepath"
		php ./occ --quiet files:scan --path "$relative_filepath"
	fi
}
export -f correct_mtime

find "$data_dir" -type f -exec bash -c 'correct_mtime "$0"' {} \;
