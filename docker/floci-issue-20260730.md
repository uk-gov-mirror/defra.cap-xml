# Title
[BUG] apigateway --type AWS putIntegration endpoint invocation fails

## Service

API Gateway

## AWS API Action

PutIntegration / execute-api (invoke)

## Expected behavior

When an API Gateway REST API method is configured with `--type AWS` and a Lambda integration URI (`arn:aws:apigateway:{region}:lambda:path/2015-03-31/functions/{fnArn}/invocations`), invoking the endpoint should execute the Lambda function with the VTL-rendered request template as the payload and return the response after applying any configured VTL response template mappings.

This is the standard non-proxy Lambda integration pattern - it provides full request/response VTL mapping, unlike `AWS_PROXY` which bypasses it.

## Actual behaviour

Invoking the endpoint returns a 500:

`{"message": "The request must contain the parameter Action"}`

Floci incorrectly treats the Lambda path-style URI (`lambda:path/...`) as a query-protocol (form-urlencoded) integration. It attempts to parse the VTL-rendered Lambda payload as AWS query protocol and dispatch it through invokeQuery, which fails because the body contains no `Action` parameter.

`AWS_PROXY` integrations against the same Lambda function work correctly.

## Reproduction

```
#!/usr/bin/env bash
set -euo pipefail

export AWS_ENDPOINT_URL=http://localhost:4566
export AWS_PAGER=""
export AWS_ACCESS_KEY_ID=test
export AWS_SECRET_ACCESS_KEY=test
export AWS_DEFAULT_REGION=eu-west-2

# =============================================================================
# Lambda function code - update the handler body below to change the response
# =============================================================================
LAMBDA_CODE=$(cat <<'LAMBDA'
exports.handler = async (event) => {
  return {
    statusCode: 200,
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ message: "Hello from my-function!", event }),
  };
};
LAMBDA
)

# Package and create the Lambda function
LAMBDA_DIR=$(mktemp -d)
echo "$LAMBDA_CODE" > "$LAMBDA_DIR/index.js"
(cd "$LAMBDA_DIR" && zip -q function.zip index.js)

aws lambda create-function \
  --function-name my-function \
  --runtime nodejs20.x \
  --handler index.handler \
  --role arn:aws:iam::000000000000:role/lambda-role \
  --zip-file "fileb://$LAMBDA_DIR/function.zip" \
  --endpoint-url "$AWS_ENDPOINT_URL"

rm -rf "$LAMBDA_DIR"
echo "Lambda function 'my-function' created"

# =============================================================================
# API Gateway setup
# =============================================================================

# Create a REST API
API_ID=$(aws apigateway create-rest-api \
  --name "My API" \
  --query id --output text \
  --endpoint-url "$AWS_ENDPOINT_URL")
echo "API_ID: $API_ID"

# Get the root resource
ROOT_ID=$(aws apigateway get-resources \
  --rest-api-id "$API_ID" \
  --query 'items[?path==`/`].id' --output text \
  --endpoint-url "$AWS_ENDPOINT_URL")
echo "ROOT_ID: $ROOT_ID"

# Create a resource
RESOURCE_ID=$(aws apigateway create-resource \
  --rest-api-id "$API_ID" \
  --parent-id "$ROOT_ID" \
  --path-part users \
  --query id --output text \
  --endpoint-url "$AWS_ENDPOINT_URL")
echo "RESOURCE_ID: $RESOURCE_ID"

# Add a GET method
aws apigateway put-method \
  --rest-api-id "$API_ID" \
  --resource-id "$RESOURCE_ID" \
  --http-method GET \
  --authorization-type NONE \
  --endpoint-url "$AWS_ENDPOINT_URL"

# Add a Lambda integration (non-proxy AWS type)
aws apigateway put-integration \
  --rest-api-id "$API_ID" \
  --resource-id "$RESOURCE_ID" \
  --http-method GET \
  --type AWS \
  --integration-http-method POST \
  --uri "arn:aws:apigateway:eu-west-2:lambda:path/2015-03-31/functions/arn:aws:lambda:eu-west-2:000000000000:function:my-function/invocations" \
  --endpoint-url "$AWS_ENDPOINT_URL"

# Add a method response (required for non-proxy integrations)
aws apigateway put-method-response \
  --rest-api-id "$API_ID" \
  --resource-id "$RESOURCE_ID" \
  --http-method GET \
  --status-code 200 \
  --endpoint-url "$AWS_ENDPOINT_URL"

# Add an integration response (required for non-proxy integrations)
aws apigateway put-integration-response \
  --rest-api-id "$API_ID" \
  --resource-id "$RESOURCE_ID" \
  --http-method GET \
  --status-code 200 \
  --selection-pattern "" \
  --endpoint-url "$AWS_ENDPOINT_URL"

# Create a deployment
DEPLOYMENT_ID=$(aws apigateway create-deployment \
  --rest-api-id "$API_ID" \
  --query id --output text \
  --endpoint-url "$AWS_ENDPOINT_URL")
echo "DEPLOYMENT_ID: $DEPLOYMENT_ID"

# Create the stage explicitly
aws apigateway create-stage \
  --rest-api-id "$API_ID" \
  --stage-name dev \
  --deployment-id "$DEPLOYMENT_ID" \
  --endpoint-url "$AWS_ENDPOINT_URL"

echo ""
echo "=== Curl Commands ==="
echo "GET /users:"
echo "  curl http://localhost:4566/restapis/$API_ID/dev/_user_request_/users"
echo ""
echo "=== IDs Summary ==="
echo "  API_ID:      $API_ID"
echo "  ROOT_ID:     $ROOT_ID"
echo "  RESOURCE_ID: $RESOURCE_ID"
echo "  Stage:       dev"
echo ""

# Call the deployed API
# Invoke — returns 500 with "The request must contain the parameter Action" (Floci bug)
curl http://localhost:4566/restapis/$API_ID/dev/_user_request_/users
```

## Environment

- Floci version / image tag: latest
- Java SDK version (if applicable): AWS CLI v2
- How you're running Floci (Docker / native / mvn quarkus:dev): Docker