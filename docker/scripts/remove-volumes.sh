#!/bin/sh
set -e

docker volume rm -f pgadmin pgdata vscode pgbootstrap pgtmp liquibase

CAP_XML_VOLUME=$(docker volume ls -q -f "name=capxml")

if [ ! -z "$CAP_XML_VOLUME" ]; then
  docker volume rm -f $(docker volume ls -f name=capxml --format json | jq -r .Name)
fi
