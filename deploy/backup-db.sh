#!/usr/bin/env bash
# PG* variables and ~/.pgpass configure credentials. No password in arguments.
set -euo pipefail
: "${PGHOST:?Set PGHOST}"
: "${PGDATABASE:?Set PGDATABASE}"
: "${PGUSER:?Set PGUSER}"
destination="${1:?Usage: backup-db.sh /absolute/path/to/backup.dump}"
[[ "$destination" = /* && ! -e "$destination" ]] || { echo 'Use a new absolute output path.' >&2; exit 1; }
umask 077
partial="${destination}.partial"
[[ ! -e "$partial" ]] || { echo 'Partial output already exists.' >&2; exit 1; }
pg_dump --format=custom --no-owner --no-acl --file="$partial"
pg_restore --list "$partial" >/dev/null
mv -- "$partial" "$destination"
printf 'Backup validated: %s\n' "$destination"
