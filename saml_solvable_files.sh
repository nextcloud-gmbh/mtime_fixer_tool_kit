#!/bin/bash

set -eu

# Usage: ./saml_solvable_files.sh <data_dir> <mysql|pgsql> <db_host> <db_user> <db_pwd> <db_name> <fix,list>

export data_dir="$(realpath "$1")"
export db_type="$2"
export db_host="$3"
export db_user="$4"
export db_pwd="$5"
export db_name="$6"
export action="${7:-list}"

# 1. Return if fs mtime <= 86400
# 2. Compute username from filepath
# 3. Query mtime from the database with the filename and the username
# 4. Return if mtime_on_fs != mtime_in_db
# 5. Correct the fs mtime with touch
function correct_mtime() {
	filepath="$1"
	base64_filepath="$(printf '%s' "$filepath" | base64)"
	mtime_on_fs="$(stat -c '%Y' "$filepath")"

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
					from oc_storages JOIN oc_filecache ON oc_storages.numeric_id = oc_filecache.storage LEFT JOIN oc_user_saml_users ON oc_storages.id = concat('home::', oc_user_saml_users.uid)
					WHERE (oc_user_saml_users.home IS NOT NULL AND concat(oc_user_saml_users.home, '/', oc_filecache.path)=FROM_BASE64('$base64_filepath')) OR
					concat('$data_dir', '/', oc_user_saml_users.uid, '/', oc_filecache.path)=FROM_BASE64('$base64_filepath')" \
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
					from oc_storages JOIN oc_filecache ON oc_storages.numeric_id = oc_filecache.storage LEFT JOIN oc_user_saml_users ON oc_storages.id = concat('home::', oc_user_saml_users.uid)
					WHERE (oc_user_saml_users.home IS NOT NULL AND concat(oc_user_saml_users.home, '/', oc_filecache.path)=CONVERT_FROM(DECODE('$base64_filepath', 'base64'), 'UTF-8')) OR
					concat('$data_dir', '/', oc_user_saml_users.uid, '/', oc_filecache.path)=CONVERT_FROM(DECODE('$base64_filepath', 'base64'), 'UTF-8')" \
		)
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
	fi
}
export -f correct_mtime

find "$data_dir" -type f ! -newermt "@86400" -exec bash -c 'correct_mtime "$0"' {} \;
