#!/bin/sh
set -e

# Use a default path if PGDATA isn't set for some reason
DATA_DIR=${PGDATA:-/var/lib/postgresql/data}

# Create the socket directory
mkdir -p /run/postgresql
chown -R postgres:postgres /run/postgresql

if [ -z "$POSTGRES_USER" ] || [ -z "$POSTGRES_PASSWORD" ] || [ -z "$POSTGRES_DB" ]; then
    echo "POSTGRES_USER, POSTGRES_PASSWORD, and POSTGRES_DB must be set"
    exit 1
fi

# Initialize DB if folder is empty
if [ ! -s "$DATA_DIR/PG_VERSION" ]; then
    echo "Initializing database in $DATA_DIR..."
    su-exec postgres initdb -D "$DATA_DIR"
fi

# Allow connections from other containers in the compose network.
if ! grep -q "^host[[:space:]]\+all[[:space:]]\+all[[:space:]]\+all[[:space:]]\+scram-sha-256" "$DATA_DIR/pg_hba.conf"; then
    echo "host all all all scram-sha-256" >> "$DATA_DIR/pg_hba.conf"
fi

echo "Ensuring database role and schema exist..."
su-exec postgres pg_ctl -D "$DATA_DIR" -o "-c listen_addresses='localhost'" -w start

su-exec postgres psql -v ON_ERROR_STOP=1 --username=postgres --dbname=postgres <<-EOSQL
DO
\$\$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = '${POSTGRES_USER}') THEN
        CREATE ROLE "${POSTGRES_USER}" LOGIN PASSWORD '${POSTGRES_PASSWORD}';
    ELSE
        ALTER ROLE "${POSTGRES_USER}" WITH LOGIN PASSWORD '${POSTGRES_PASSWORD}';
    END IF;
END
\$\$;
EOSQL

if ! su-exec postgres psql --username=postgres --dbname=postgres -tAc "SELECT 1 FROM pg_database WHERE datname='${POSTGRES_DB}'" | grep -q 1; then
    su-exec postgres createdb --owner="$POSTGRES_USER" "$POSTGRES_DB"
fi

su-exec postgres pg_ctl -D "$DATA_DIR" -m fast -w stop

echo "Starting PostgreSQL..."
exec su-exec postgres postgres -D "$DATA_DIR" -c listen_addresses='*'