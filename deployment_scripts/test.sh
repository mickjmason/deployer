#!/bin/bash

if [ -z "$REST_API_ID" ]; then
    echo "The environment variable REST_API_ID is not set."
    exit 1
fi

echo $DEPLOYMENT_USER_ID
echo $DEPLOYMENT_TOKEN


aws --endpoint http://localhost.localstack.cloud:4566 s3api get-object --bucket templatestore --key $DEPLOYMENT_FILENAME /opt/deployments/main.tf
cd /opt/deployments
tflocal init
tflocal apply -auto-approve

aws --endpoint http://localhost.localstack.cloud:4566 s3api put-object --bucket $DEPLOYMENT_USER_ID-$DEPLOYMENT_ITEM_ID --key /deleteme/test

if [ $? -eq 0 ]; then
    # If the exit code is 0 (success), curl URL 1
    DEPLOYMENT_VALIDATED=1
else
    # If the exit code is not 0 (failure), curl URL 2
    DEPLOYMENT_VALIDATED=0
fi

curl -X POST http://$REST_API_ID.execute-api.localhost.localstack.cloud:4566/test/confirmation -H "Content-Type: application/json" \
--data @<(cat <<EOF
{
  "token": "$DEPLOYMENT_TOKEN",
  "userid":"$DEPLOYMENT_USER_ID",
  "itemid":"$DEPLOYMENT_ITEM_ID",
  "validated": "$DEPLOYMENT_VALIDATED"
  }
EOF
)

sleep infinity