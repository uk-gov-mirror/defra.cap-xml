# docker compose -f ../../docker/infrastructure.yml -f ../../docker/networks.yml up floci -d


export AWS_ENDPOINT_URL=http://localhost:4566
export AWS_PAGER=""

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

awslocal lambda create-function \
  --function-name my-function \
  --runtime nodejs20.x \
  --handler index.handler \
  --role arn:aws:iam::000000000000:role/lambda-role \
  --zip-file "fileb://$LAMBDA_DIR/function.zip" \
  --endpoint-url $AWS_ENDPOINT_URL

rm -rf "$LAMBDA_DIR"
echo "Lambda function 'my-function' created"

# =============================================================================
# API Gateway setup
# =============================================================================

# Create a REST API
API_ID=$(awslocal apigateway create-rest-api \
  --name "My API" \
  --query id --output text \
  --endpoint-url $AWS_ENDPOINT_URL)
echo "API_ID: $API_ID"

# Get the root resource
ROOT_ID=$(awslocal apigateway get-resources \
  --rest-api-id $API_ID \
  --query 'items[?path==`/`].id' --output text \
  --endpoint-url $AWS_ENDPOINT_URL)
echo "ROOT_ID: $ROOT_ID"

# Create a resource
RESOURCE_ID=$(awslocal apigateway create-resource \
  --rest-api-id $API_ID \
  --parent-id $ROOT_ID \
  --path-part users \
  --query id --output text \
  --endpoint-url $AWS_ENDPOINT_URL)
echo "RESOURCE_ID: $RESOURCE_ID"

# Add a GET method
awslocal apigateway put-method \
  --rest-api-id $API_ID \
  --resource-id $RESOURCE_ID \
  --http-method GET \
  --authorization-type NONE \
  --endpoint-url $AWS_ENDPOINT_URL

# Add a Lambda integration
awslocal apigateway put-integration \
  --rest-api-id $API_ID \
  --resource-id $RESOURCE_ID \
  --http-method GET \
  --type AWS \
  --integration-http-method POST \
  --uri "arn:aws:apigateway:eu-west-2:lambda:path/2015-03-31/functions/arn:aws:lambda:eu-west-2:000000000000:function:my-function/invocations" \
  --endpoint-url $AWS_ENDPOINT_URL

# Create a deployment
DEPLOYMENT_ID=$(awslocal apigateway create-deployment \
  --rest-api-id $API_ID \
  --query id --output text \
  --endpoint-url $AWS_ENDPOINT_URL)
echo "DEPLOYMENT_ID: $DEPLOYMENT_ID"

# Create the stage explicitly
awslocal apigateway create-stage \
  --rest-api-id $API_ID \
  --stage-name dev \
  --deployment-id $DEPLOYMENT_ID \
  --endpoint-url $AWS_ENDPOINT_URL

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
curl http://localhost:4566/restapis/$API_ID/dev/_user_request_/users

# awslocal lambda invoke \
#   --function-name my-function \
#   --payload '{}' \
#   --endpoint-url http://localhost:4566 \
#   /dev/stdout
