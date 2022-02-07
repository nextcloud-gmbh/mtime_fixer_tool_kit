#!/bin/bash

set -eu

# Usage: ./list_problematic_files_on_fs.sh <data_dir>

export data_dir="$(realpath "$1")"

function check_file() {
	filepath="$1"
	relative_filepath="${filepath/#$data_dir\//}"

	username=$relative_filepath
	while [ "$(dirname "$username")" != "." ]
	do
		username=$(dirname "$username")
	done

	if [ "$username" == "__groupfolders" ]
	then
		# Ending with '/' to match the DB output.
		storage="local::$data_dir/"
		problematic_file="$relative_filepath"
	else
		storage="home::$username"
		problematic_file="${relative_filepath/#$username\//}"
	fi

	if [ "${#storage}" -le "64" ]
	then
		echo "$storage/$problematic_file"
	else
		storage_md5=$(printf '%s' "$storage" | md5sum | awk '{print $1}')
		echo "$storage_md5/$problematic_file"
	fi
}
export -f check_file

find "$data_dir" -type f ! -newermt "@86400" -exec bash -c 'check_file "$0"' {} \;
