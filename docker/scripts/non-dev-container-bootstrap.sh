#!/bin/sh
# This script MUST be called from ${containerWorkspace Folder}.
# See https://containers.dev/implementors/json_reference/.
set -e

#Use the docker/.env file to set environment variables. 
set -a
. docker/.env
set +a

docker/scripts/initialize-command.sh
docker compose -f docker/infrastructure.yml -f docker/networks.yml -f docker/dev-tools.yml up -d
docker/scripts/register-lambda-functions.sh
docker/scripts/register-api-gateway.sh
docker rm docker-liquibase-1
