# mtime correction tool kit

## `solvable_files.sh`

This script looks for problematic files on the server's file system.

The default behavior is to simply list the solvable files.

To fix the files mtime on both the file system and the database, you have to call the script with the `fix` argument at the end of the argument list.

### Checks

The mtime from the file system and from the database must be equal to proceed.

To find the file's mtime from the database, a username is derived from the file's path, this allow use to find the correct storage, file on the database.

Group folders are handled specially by checking if the username equal `__groupfolders`.

### Actions

- The file's mtime will be updated with the `touch` command.
- An `occ files:scan` will be run on the file to update the database.

### Limitations

- Files that are not present on the server's file system will not be fixed. For example files on an external storage.

### Usage

```shell
./solvable_files.sh <data_dir> <mysql|pgsql> <db_host> <db_user> <db_pwd> <db_name> [<fix|list>] [<scan|noscan>] [<use_birthday,dont_use_birthday>] [<verbose,noverbose>]
```

#### use_birthday
This option will use the files 'birthday' from `stat` if available, else it'll use ctime (last changed) to restore mtime, as opposed to using the current date/timestamp.

#### verbose
The verbose option will give more output on what the script is doing, and which datestamps it's using.

### Output

```shell
$ ./solvable_files.sh "$PWD/data/" mysql localhost nextcloud password nextcloud list noscan use_birthday verbose
mtime for "/home/louis/workspace/nextcloud/server/data/__groupfolders/1/(test).md" updated to "2022-01-09 12:05:07.358561800 +0200"
mtime for "/home/louis/workspace/nextcloud/server/data/__groupfolders/1/test.md" updated to "2022-01-09 12:05:07.358561800 +0200"
mtime for "/home/louis/workspace/nextcloud/server/data/__groupfolders/1/test.md" updated to "2022-01-09 12:05:07.358561800 +0200"
mtime for "/home/louis/workspace/nextcloud/server/data/alice/files_trashbin/files/storage trash.d1639576034/(test).md" updated to "2022-01-09 12:05:07.358561800 +0200"
mtime for "/home/louis/workspace/nextcloud/server/data/alice/files_trashbin/files/storage trash.d1639576034/test.md" updated to "2022-01-09 12:05:07.358561800 +0200"
mtime for "/home/louis/workspace/nextcloud/server/data/alice/files_trashbin/files/storage trash.d1639576034/test.md" updated to "2022-01-09 12:05:07.358561800 +0200"
mtime for "/home/louis/workspace/nextcloud/server/data/admin/files/welcome.txt" updated to "2022-01-09 12:05:07.358561800 +0200"
mtime for "/home/louis/workspace/nextcloud/server/data/admin/files/shared test/(test).md" updated to "2022-01-09 12:05:07.358561800 +0200"
mtime for "/home/louis/workspace/nextcloud/server/data/admin/files/shared test/test.md" updated to "2022-01-09 12:05:07.358561800 +0200"
mtime for "/home/louis/workspace/nextcloud/server/data/admin/files/shared test/test.md" updated to "2022-01-09 12:05:07.358561800 +0200"
```

```shell
$ ./server/mtime_scripts/solvable_files.sh "$PWD/server/data/" mysql localhost nextcloud password nextcloud list noscan | wc -l
10
```

## `unsolvable_files.sh`

This script lists files that can not be fixed by the `solvable_files.sh` script. For example files on an external storage.

It compares files found in the database with files found in on the server's file system and prints the diff.

### Usage

```shell
./unsolvable_files.sh <data_dir> <mysql|pgsql> <db_host> <db_user> <db_pwd> <db_name>
```

### Output

```shell
$ ./unsolvable_files.sh "$PWD/data/" mysql localhost nextcloud password nextcloud
local::/home/louis/nextcloud_external//(test).md
local::/home/louis/nextcloud_external//test".md
local::/home/louis/nextcloud_external//test.md
```

```shell
$ ./unsolvable_files.sh "$PWD/data/" mysql localhost nextcloud password nextcloud | wc -l
3
```

## `fix_group_folders.sh`

This script will simulate a scan for files located in the groupfolder's trash and version folders.

### Usage

```shell
./fix_group_folders.sh <data_dir> <mysql|pgsql> <db_host> <db_user> <db_pwd> <db_name>
```

### Output

```shell
./fix_group_folders.sh "$PWD/data/" mysql localhost nextcloud password nextcloud
```
