#!/bin/sh
set -e

docker volume rm -f capxmlpgadmin capxmlpgdata vscode capxmlpgbootstrap pgtmp capxmlliquibase

CAP_XML_VOLUME=$(docker volume ls -q -f "name=cap-xml")

if [ ! -z "$CAP_XML_VOLUME" ]; then
  docker volume rm -f $(docker volume ls -f name=cap-xml --format json | jq -r .Name)
fi
