
export AWS_ENDPOINT_URL=http://localhost:4566
export AWS_PAGER=""

# Delete the Lambda function
echo "Deleting Lambda function 'my-function'..."
awslocal lambda delete-function \
  --function-name my-function \
  --endpoint-url $AWS_ENDPOINT_URL 2>/dev/null && echo "Lambda function deleted" || echo "Lambda function not found"

# Get the API ID (assumes the test API is named "My API")
API_ID=$(awslocal apigateway get-rest-apis \
  --query 'items[?name==`My API`].id' --output text \
  --endpoint-url $AWS_ENDPOINT_URL)

if [ -z "$API_ID" ]; then
  echo "No API found with name 'My API'"
  echo "Teardown complete"
  exit 0
fi

echo "Deleting API: $API_ID"

# Delete the REST API (removes all resources, methods, integrations, and deployments)
awslocal apigateway delete-rest-api \
  --rest-api-id $API_ID \
  --endpoint-url $AWS_ENDPOINT_URL

echo "Teardown complete"
