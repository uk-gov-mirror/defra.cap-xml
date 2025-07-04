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
# Register the API Gateway before the Lambda functions so that the API Gateway URL can be
# made available to each Lambda function using an environment variable.
docker/scripts/register-api-gateway.sh
docker/scripts/register-lambda-functions.sh
docker rm docker-liquibase-1
