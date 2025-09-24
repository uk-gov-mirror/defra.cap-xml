#!/bin/sh
set -e

CAP_XML_NETWORK=$(docker network ls -q -f "name=docker_ls")

if [ ! -z "$CAP_XML_NETWORK" ]; then
  docker network rm -f $(docker network ls -f name=docker_ls --format json | jq -r .Name)
fi
