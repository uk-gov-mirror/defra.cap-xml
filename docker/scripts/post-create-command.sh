#!/bin/sh
# This script MUST be called from ${containerWorkspace Folder}.
# See https://containers.dev/implementors/json_reference/.
set -e

sudo docker/scripts/install-packages.sh
docker/scripts/setup-aws-cli-command-completion.sh
docker/scripts/init-npm.sh
# Register the API Gateway before the Lambda functions so that the API Gateway URL can be
# made available to each Lambda function using an environment variable.
docker/scripts/register-api-gateway.sh
docker/scripts/register-lambda-functions.sh

if [ -d /opt/workspaces/cap-xml/docker ]; then
  # Ensure that docker directory contents can be modified from within the development container.
  sudo chown -R vscode:vscode /opt/workspaces/cap-xml/docker
fi

docker rm docker-liquibase-1
docker image prune -f
