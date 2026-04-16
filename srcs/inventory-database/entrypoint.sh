#!/bin/sh
set -e

# Use a default path if PGDATA isn't set for some reason
DATA_DIR=${PGDATA:-/var/lib/postgresql/data}

# Create the socket directory
mkdir -p /run/postgresql
chown -R postgres:postgres /run/postgresql

# Initialize DB if folder is empty
if [ ! -s "$DATA_DIR/PG_VERSION" ]; then
    echo "Initializing database in $DATA_DIR..."
    su-exec postgres initdb -D "$DATA_DIR"
fi

echo "Starting PostgreSQL..."
exec su-exec postgres postgres -D "$DATA_DIR"