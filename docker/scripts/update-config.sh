#!/bin/sh
# This script MUST be called from ${containerWorkspace Folder}.
set -e

CAP_XML_RDS_CONNECTION_STRING=${CAP_XML_DB_CONNECTION_STRING}
JQ_CAP_XML_RDS_CONNECTION_STRING=$CAP_XML_RDS_CONNECTION_STRING jq '.aws.rdsConnectionString=$ENV.JQ_CAP_XML_RDS_CONNECTION_STRING' config/config.example.json > config/tmp-config.json
mv -f config/tmp-config.json config/config.json
echo Updated config/config.json - \$.aws.rdsConnectionString \($CAP_XML_RDS_CONNECTION_STRING\) allows connectivity to the provisioned local Postgres database
CAP_XML_API_URL=http://$(awslocal apigateway get-rest-apis | jq -r ".items[0].id").execute-api.localhost.localstack.cloud:4566/local
JQ_CAP_XML_API_URL=$CAP_XML_API_URL jq '.url=$ENV.JQ_CAP_XML_API_URL' config/config.json > config/tmp-config.json
mv -f config/tmp-config.json config/config.json
echo Updated config/config.json - \$.url \($CAP_XML_API_URL\) allows connectivity to the provisioned LocalStack API Gateway
