#!/usr/bin/env bash
# Uses the same network namespace as the application on a Linux cloud host.
# Supply libpq PGHOST/PGPORT/PGDATABASE/PGUSER/PGSSLMODE, never JDBC URLs.
set -euo pipefail
: "${PGHOST:?Set the existing database host}"
: "${PGDATABASE:?Set the existing database name}"
: "${PGUSER:?Set the application database user}"
export PGPORT="${PGPORT:-5432}" PGSSLMODE="${PGSSLMODE:-verify-full}"
psql -X -W -v ON_ERROR_STOP=1 -c 'SELECT current_database(), current_user, version();'
