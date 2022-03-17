#!/bin/bash

if [ -z "$1" -o -z "$2" -o -z "$3" -o -z "$4" -o -z "$5" -o -z "$6" -o -z "$7" ]; then
	echo "Usage: s3_fix_mtime.sh <mysql|pgsql> <db_host> <db_user> <db_pwd> <db_name> <s3 bucket> <s3 base URL> <user id|all>"
	exit 1
fi

set -eu

export db_type="$1"
export db_host="$2"
export db_user="$3"
export db_pwd="$4"
export db_name="$5"
export bucket="$6"
export url="$7"
export command="${8:-all}"

if [ -z "${AWS_ACCESS_KEY_ID-}"  ]; then
	echo "Need AWS_ACCESS_KEY_ID to be set"
	exit 1
fi

if [ -z "${AWS_SECRET_ACCESS_KEY-}" ]; then
	echo "Need AWS_SECRET_ACCESS_KEY to be set"
	exit 1
fi

s3simple() {
	local fileid=$1
	local path="/${bucket}/urn:oid:${fileid}"

	local method md5
	method="GET"
	md5=""

	local date="$(date -u '+%a, %0e %b %Y %H:%M:%S GMT')"
	local string_to_sign
	printf -v string_to_sign "%s\n%s\n\n%s\n%s" "$method" "$md5" "$date" "$path"
	local signature=$(echo -n "$string_to_sign" | openssl sha1 -binary -hmac "${AWS_SECRET_ACCESS_KEY}" | openssl base64)
	local authorization="AWS ${AWS_ACCESS_KEY_ID}:${signature}"

	modificationDate=`curl -o /dev/null -D - -s -f -H "Date:${date}" -H "Authorization:${authorization}" "${url}${path}" | grep "Last-Modified"`
	decodedDate=`echo $modificationDate | sed -e "s/Last\-Modified: //"`
	unixDate=`date --date="$decodedDate" +"%s"`

	if [ "$db_type" == "mysql" ]
	then
		mysql \
			--skip-column-names \
			--silent \
			--host="$db_host" \
			--user="$db_user" \
			--password="$db_pwd" \
			--default-character-set=utf8 \
			--execute="\
				UPDATE oc_filecache set mtime=$unixDate
				WHERE
				fileid=$fileid AND
				mtime<86400 OR mtime>=4294967295" \
			"$db_name"
	elif [ "$db_type" == "pgsql" ]
	then
		psql \
			"postgresql://$db_user:$db_pwd@$db_host/$db_name" \
			--tuples-only \
			--no-align \
			--command="\
				UPDATE oc_filecache set mtime=$unixDate
				WHERE
				fileid=$fileid AND
				mtime<86400 OR mtime>=4294967295"
	fi
}

if [ "$db_type" == "mysql" ]
then
	if [ "$command" == "all" ]
	then
		results=$(
			mysql \
				--skip-column-names \
				--silent \
				--host="$db_host" \
				--user="$db_user" \
				--password="$db_pwd" \
				--default-character-set=utf8 \
				--execute="\
					SELECT fileid FROM oc_filecache WHERE mtime<86400 OR mtime>=4294967295" \
				"$db_name"
		)
	else
		results=$(
			mysql \
				--skip-column-names \
				--silent \
				--host="$db_host" \
				--user="$db_user" \
				--password="$db_pwd" \
				--default-character-set=utf8 \
				--execute="\
					SELECT oc_filecache.fileid
					FROM oc_storages JOIN oc_filecache ON oc_filecache.storage = oc_storages.numeric_id
					WHERE (mtime<86400 OR mtime>=4294967295) AND oc_storages.id='object::user:$command'" \
				"$db_name"
		)
	fi
elif [ "$db_type" == "pgsql" ]
then
	if [ "$command" == "all" ]
	then
		results=$(
			psql \
				"postgresql://$db_user:$db_pwd@$db_host/$db_name" \
				--tuples-only \
				--no-align \
				--command="\
					SELECT fileid FROM oc_filecache WHERE mtime<86400 OR mtime>=4294967295"
		)
	else
		results=$(
			psql \
				"postgresql://$db_user:$db_pwd@$db_host/$db_name" \
				--tuples-only \
				--no-align \
				--command="\
					SELECT oc_filecache.fileid
					FROM oc_storages JOIN oc_filecache ON oc_filecache.storage = oc_storages.numeric_id
					WHERE (mtime<86400 OR mtime>=4294967295) AND oc_storages.id='object::user:$command'"
		)
	fi
fi

for i in $results; do
	s3simple $i
done
