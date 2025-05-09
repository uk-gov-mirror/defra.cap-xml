#!/bin/sh
set -e

if [ ! -d /cx_tables ]; then
  mkdir /cx_tables
fi
if [ ! -d /cx_indexes ]; then
  mkdir /cx_indexes
fi
psql -c "CREATE USER cx WITH PASSWORD '$CAP_XML_DB_PASSWORD';"
psql -c "CREATE DATABASE $CAP_XML_DB_NAME";
psql -d $CAP_XML_DB_NAME -f "/tmp/setup.sql";
psql -d $CAP_XML_DB_NAME -c "CREATE EXTENSION IF NOT EXISTS \"uuid-ossp\"";
