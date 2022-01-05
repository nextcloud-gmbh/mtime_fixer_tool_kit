#!/bin/bash

set -eu

# Usage: ./list_problematic_files_on_fs.sh <data_dir>

export data_dir="$1"

if [ "${data_dir:0:1}" != "/" ]
then
	echo "data_dir must be absolute."
	exit 1
fi

function check_file() {
	filepath="$1"
	mtime_on_fs="$(stat -c '%Y' "$filepath")"
	relative_filepath="${filepath//$data_dir/}"

	if [ "$mtime_on_fs" -gt '86400' ]
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
		echo "local::$data_dir/$relative_filepath"
	else
		echo "home::$relative_filepath"
	fi
}
export -f check_file

find "$data_dir" -type f -exec bash -c 'check_file "$0"' {} \;
