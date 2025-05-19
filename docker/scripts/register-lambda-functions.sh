#!/bin/sh
# This script MUST be called from ${containerWorkspace Folder}.
# See https://containers.dev/implementors/json_reference/.
set -e

lambda_functions_dir="lib/functions"

# Prepare a comma separated list of custom environment variables required by
# each Lambda function.
cap_xml_db_username=$(echo CAP_XML_DB_USERNAME=$CAP_XML_DB_USERNAME)
cap_xml_db_password=$(echo CAP_XML_DB_PASSWORD=$CAP_XML_DB_PASSWORD)
cap_xml_db_name=$(echo CAP_XML_DB_NAME=$CAP_XML_DB_NAME)
cap_xml_db_host=$(echo CAP_XML_DB_HOST=$CAP_XML_DB_HOST)
set -- $cap_xml_db_username $cap_xml_db_password $cap_xml_db_name $cap_xml_db_host
custom_environment_variables=$(printf '%s,' "$@" | sed 's/,*$//g')

# Iterate over each file in lambda_functions_dir
for lambda_function in "$lambda_functions_dir"/*; do
  if [ -f "$lambda_function" ]; then
      function_name=$(basename "$lambda_function" .js)
      echo Registering $function_name with LocalStack

      awslocal lambda create-function \
        --function-name "$function_name" \
        --code S3Bucket="hot-reload",S3Key="$(pwd)/" \
        --runtime nodejs20.x \
        --timeout $LAMBDA_TIMEOUT \
        --role arn:aws:iam::000000000000:role/lambda-role \
        --handler lib/functions/$function_name.$function_name \
        --environment "Variables={$custom_environment_variables}" \
        --no-cli-pager
      sleep 1

  fi
done

echo "All Lambda functions have been registered with LocalStack."

awslocal lambda create-function-url-config --function-name archiveMessages --auth-type NONE

echo "Created function URL config for archiveMessages function"
