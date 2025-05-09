#!/bin/sh
# This script MUST be called from ${containerWorkspace Folder}.
# See https://containers.dev/implementors/json_reference/.
set -e

# Prepare to clone the cap-xml-db repository using a git
# HTTPS URL by default.
CAP_XML_DB_REPOSITORY_URL=https://github.com/DEFRA/cap-xml-db.git

# If the SSH_AUTH_SOCK environment variable is populated, prepare
# to clone the cap-xml-db repository using a git SSH URL.
if [ ! -z "$SSH_AUTH_SOCK" ]; then
  CAP_XML_DB_REPOSITORY_URL=git@github.com:DEFRA/cap-xml-db.git
fi

if [ -d ../cap-xml-db ]; then
  echo Local cap-xml-db repository exists
elif [ x${CAP_XML_DB_BRANCH} = "x" ]; then
    echo Cloning master branch of cap-xml-db repository
    (cd .. && git clone -b master ${CAP_XML_DB_REPOSITORY_URL})
else
  echo Cloning ${CAP_XML_DB_BRANCH} branch of cap-xml-db repository
  (cd .. && git clone -b ${CAP_XML_DB_BRANCH}  ${CAP_XML_DB_REPOSITORY_URL})
fi

