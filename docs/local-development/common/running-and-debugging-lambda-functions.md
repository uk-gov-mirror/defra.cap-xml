# Running And Debugging AWS Lambda Functions

## Default Configuration

[The Docker environment variable file](../../../docker/.env) is configured to debug a
LocalStack hosted AWS Lambda function by default through the following environment variable:

```sh
LAMBDA_DOCKER_FLAGS=-e NODE_OPTIONS=--inspect-brk=0.0.0.0:9229 -p 9229:9229
```

This environment variable allows the Visual Studio Code debugger to attach to the standard Node.js debug port (9229)
in a LocalStack Docker container used to run an AWS Lambda function.

## Disabling Debug Functionality

AWS Lambda function debugging can be disabled by:

* Commenting out the **LAMBDA_DOCKER_FLAGS** environment variable in [the development container environment variable file](../../../docker/.env).
* Replacing ([Teardown](../dev-container/additional-dev-container-considerations.md#teardown) and recreate) the existing containerised development environment with a new containerised development environment using
  the revised configuration
  * **IMPORTANT** - If cloning the remote repository into a container volume, the configuration change must be pushed to a branch from which the new containerised development environment **must** be created.
  * **IMPORTANT** - If a new containerised dev environment is not created, running multiple Lambda functions without
    remote debug limitations will **not** be possible.

## Re-enabling Debug Functionality

Uncomment the **LAMBDA_DOCKER_FLAGS** environment variable in [the Docker environment variable file](../../../docker/.env) and replace the containerised development environment as described above.

## Preparing To Debug An AWS Lambda Function

### Visual Studio Code

Run the Visual Studio Code **Attach to Remote Node.js (cap-xml)** debug configuration **before** AWS Lambda function
invocation. This waits for the standard Node.js debug port to be made available by a Docker container running an
AWS Lambda function before attempting to attach the debugger. Please consult the [LocalStack Lambda debugging documentation](https://hashnode.localstack.cloud/debugging-nodejs-lambda-functions-locally-using-localstack) for further details.

### Other Software

Please consult appropriate documentation.

## Invoking AWS Lambda Functions

From within the development container, use the [LocalStack AWS Command Line interface](https://docs.localstack.cloud/user-guide/integrations/aws-cli/) to retrieve the identifier of the deployed REST API from the API Gateway. For example, the command below can be used when an initial attempt to create a containerised development environment succeeds (resulting in the creation of one REST API instance)

```sh
awslocal apigateway get-rest-apis | jq -r '.items[0].id'
```

IMPORTANT

In the following examples of invoking Lambda functions through API Gateway endpoints:

* Angled bracket based placeholders such as **&lt;&lt;REST-API-ID&gt;&gt;** placeholder **must** be replaced.
* For convenience, LocalStack is configured not to require an API key when calling API Gateway endpoints.
* When the debugger attaches, it breaks before running the AWS Lambda function. As such, debugging **must** be resumed to reach
  configured breakpoints.

### Making A HTTP GET Request To The /messages.atom Endpoint

Use the REST API identifier to call the **/messages.atom** endpoint linked to the **getMessagesAtom** AWS Lambda function. For example, the following curl command can be used:

```sh
curl "http://<<REST-API-ID>>.execute-api.localhost.localstack.cloud:4566/local/messages.atom"
```

### Making A HTTP GET Request To The /message Endpoint

Use the REST API identifier to call the **/message/&lt;&lt;MESSAGE-ID&gt;&gt;** endpoint linked to the **getMessage** AWS Lambda function. For example, the following curl command can be used:

```sh
curl "http://<<REST-API-ID>>.execute-api.localhost.localstack.cloud:4566/local/message/<<MESSAGE-ID>>"
```

### Making A HTTP POST To The /message Endpoint

AWS API Gateway request templates are used to ensure XML message content is embedded within AWS Lambda JSON event objects.
Real AWS API Gateway software appears capable of embedding raw XML within AWS Lambda JSON event objects without further configuration.
At the time of writing, LocalStack API Gateway software appears to require raw XML message content to be embedded as a string
within a JSON document and slightly different request templates to be able to provide the AWS Lambda function with an event object reflecting that received from real AWS API Gateway software. For example, real AWS API Gateway software appears capable of handling raw XML
such as the following:

```sh
<xml>
  <element>content</element>
</xml>
```

LocalStack API Gateway software appears to require a JSON structure such as the following for Lambda functions to receive an event object
consistent with that received from real AWS API Gateway software.

```sh
{
  "message": "<xml><element>content</element></xml>"
}
```

The following command can be used as a guide to making a HTTP POST request to the **/message** endpoint using **curl**:

```sh
curl -H "Content-Type: text/xml" -d "@<</path/to/message/file>>" "http://<<REST-API-ID>>.execute-api.localhost.localstack.cloud:4566/local/message"
```

IMPORTANT

* The request header **Content-Type: text/xml** or **Content-Type: text/html** **must** be used to ensure correct processing by the LocalStack API Gateway request template.

### Invoking The archiveMessages AWS Lambda Function

This function is not invoked through an API Gateway endpoint and needs to be invoked using an AWS Lambda Function URL locally.
An AWS Lambda Function URL is created and output during local environment provisioning. The URL can be retrieved using the following command:

```sh
awslocal lambda get-function-url-config --function-name archiveMessages | jq -r .FunctionUrl
```

The AWS Lambda Function URL can be used with a suitable HTTP client such as curl. For example, the following command can be used in a Linux environment:

```sh
curl $(awslocal lambda get-function-url-config --function-name archiveMessages | jq -r .FunctionUrl)
```

## Making Code Changes

Code changes can be made without having to redeploy Lambda functions to LocalStack. Please consult [LocalStack Lambda debugging documentation](https://hashnode.localstack.cloud/debugging-nodejs-lambda-functions-locally-using-localstack) for more details.

## Debug Limitations

LocalStack uses a different Docker container for each available AWS Lambda function (i.e. while the same container can
process multiple requests invoking the same AWS Lambda function, a new container will be created to invoke a different
AWS Lambda function).

At a particular point in time, the standard Node.js debug port can only be used by one LocalStack Docker container
used to run an AWS Lambda function. This restriction means that a particular AWS Lambda function cannot be debugged
if a container for debugging a different AWS Lambda function is running. As such, while Docker containers used to run
Lambda functions are ephemeral, manual container removal or timeout (causing automatic removal) is needed when invoking different AWS Lambda functions in quick succession. The timeout for a Lambda function is specified by the LAMBDA_TIMEOUT
environment variable within [the  Docker environment variable file](../../../docker/.env).

## Known Issues

* Calls to the **getMessagesAtom** and **getMessage** LocalStack API Gateway endpoints return a Content-Type HTTP response header of **text/plain** rather than **application/xml** returned by calls to AWS API Gateway endpoints. This affects markup formatting in browsers.
* When running/debugging in a development container created by cloning the repository into a container volume, calls to  **getMessagesAtom** return XML content containing incorrect URLs that use the REST API ID configured on the host machine rather than the REST API ID configured in the development container.
  * To workaround this issue, ensure that the url attribute within config/config.json on the host machine matches that configured in the development container.
