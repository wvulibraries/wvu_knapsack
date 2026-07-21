#!/bin/sh
set -e

mkdir -p /app/samvera/hyrax-webapp/tmp/pids
rm -f /app/samvera/hyrax-webapp/tmp/pids/*

# Ensure data directories exist (especially for mounted volumes)
mkdir -p /app/samvera/data/logs/rails
mkdir -p /app/samvera/data/bundle

# Run the command
exec "$@"
