#! /bin/bash

for i in $(php ./occ groupfolders:list --output=json_pretty | grep '"id":' | sed "s/.*id\": //" | sed "s/,//"); do
	php ./occ groupfolders:scan "$i"
done

