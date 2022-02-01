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
		# Two // to match the DB output.
		echo "local::$data_dir//$relative_filepath"
	else
		echo "home::$relative_filepath"
	fi
}
export -f check_file

find "$data_dir" -type f ! -newermt "@86400" -exec bash -c 'check_file "$0"' {} \;
