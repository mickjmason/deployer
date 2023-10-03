# deployer

cd to the deployer folder.
execute:

```
tflocal init
tflocal apply
```

Build the docker image:

```
docker build -t deployer.
```

Push the docker image to ECR:

```
docker push localhost.localstack.cloud:4510/deployer_repository/deployer
```

Zip up the lambda function code and update the lambda functions

```
zip api_processor.zip api_processor.py
awslocal lambda update-function-code --function-name api_processor --zip-file=fileb://api_processor.zip | jq -r .

zip confirmation_processor.zip confirmation_processor.py
awslocal lambda update-function-code --function-name confirmation_processor --zip-file=fileb://confirmation_processor.zip | jq -r .

zip request_queue_processor.zip request_queue_processor.py
awslocal lambda update-function-code --function-name request_queue_processor --zip-file=fileb://request_queue_processor.zip | jq -r .

zip check1_processor.zip check1_processor.py
awslocal lambda update-function-code --function-name check1_processor --zip-file=fileb://check1_processor.zip | jq -r .

zip check2_processor.zip check2_processor.py
awslocal lambda update-function-code --function-name check2_processor --zip-file=fileb://check2_processor.zip | jq -r .

zip build_template_s3.zip build_template_s3.py
awslocal lambda update-function-code --function-name build_template_s3 --zip-file=fileb://build_template_s3.zip | jq -r .

zip build_template_dynamodb.zip build_template_dynamodb.py
awslocal lambda update-function-code --function-name build_template_dynamodb --zip-file=fileb://build_template_dynamodb.zip | jq -r .

zip build_template_sqs.zip build_template_sqs.py
awslocal lambda update-function-code --function-name build_template_sqs --zip-file=fileb://build_template_sqs.zip | jq -r .

zip halt_processing_processor.zip halt_processing_processor.py
awslocal lambda update-function-code --function-name halt_processing_processor --zip-file=fileb://halt_processing_processor.zip | jq -r .

zip deployment_task_invoker.zip deployment_task_invoker.py
awslocal lambda update-function-code --function-name deployment_task_invoker --zip-file=fileb://deployment_task_invoker.zip | jq -r .

```

Call the API:

```
RESTAPIID=$(awslocal apigateway get-rest-apis | jq -r .items[0].id)
curl -X POST http://$RESTAPIID.execute-api.localhost.localstack.cloud:4566/test/provision -H "Content-Type: application/json" -d '{"request_data": {"services":"s3","userid":"d123456"}}'
```

Check the most recent execution of the preparation_state_machine:

```
EXECUTION_ARN=$(awslocal stepfunctions list-executions --state-machine-arn arn:aws:states:us-east-1:000000000000:stateMachine:preparation_state_machine | jq -r .executions[-1].executionArn)
awslocal stepfunctions get-execution-history --execution-arn $EXECUTION_ARN | jq -r . > execution.json
```

Check the most recent execution of the deployment_execution_state_machine

```
EXECUTION_ARN=$(awslocal stepfunctions list-executions --state-machine-arn arn:aws:states:us-east-1:000000000000:stateMachine:deployment_execution_state_machine | jq -r .executions[-1].executionArn)
awslocal stepfunctions get-execution-history --execution-arn $EXECUTION_ARN | jq -r . > deployer_execution.json
```


