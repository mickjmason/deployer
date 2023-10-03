import json
import boto3
import os
import uuid


def handler(event, context):
    try:
        result = False
        #
        cluster_name = "arn:aws:ecs:us-east-1:000000000000:cluster/deployment_cluster"
        task_definition = "arn:aws:ecs:us-east-1:000000000000:task-definition/terraform:1"

        endpoint = "http://%s:4566" % os.environ["LOCALSTACK_HOSTNAME"]
        ecs_client = boto3.client("ecs",endpoint_url=endpoint)
        subnets = os.environ["SUBNETS"].split(',')
        response = ecs_client.run_task(
            cluster=cluster_name,
            taskDefinition=task_definition,
            launchType="FARGATE",
            networkConfiguration={
                "awsvpcConfiguration": {
                    "subnets": subnets, 
                    "securityGroups": [
                        os.environ["SECURITY_GROUPS"]
                    ], 
                }
            },
            overrides={
                "containerOverrides": [
                    {
                        "environment": [
                            {"name": "DEPLOYMENT_USER_ID", "value": event["userid"]},
                            {"name": "DEPLOYMENT_ITEM_ID", "value": event["itemid"]},
                            {"name": "DEPLOYMENT_MAPPING_ID", "value": event["mappingid"]},
                            {"name": "DEPLOYMENT_FILENAME", "value": event["filename"]},
                            {"name": "DEPLOYMENT_SERVICE", "value": event["service"]},
                            {"name": "DEPLOYMENT_TOKEN", "value": event["token"]},
                            {"name": "REST_API_ID", "value": os.environ["REST_API_ID"]},
                            {"name": "LOCALSTACK_HOSTNAME", "value": os.environ["LOCALSTACK_HOSTNAME"]}
                        ],
                    }
                ]
            },
        )

        # Check if the task was started successfully
        if "tasks" in response and len(response["tasks"]) > 0:
            task = response["tasks"][0]
            task_arn = task["taskArn"]
            result = True

        print(f"\n\nTASK RESPONSE: {response}")
        return {"statusCode": 200, "body": f"Task Result: {str(response)}"}

    except Exception as e:
        print(f"ECS TASK FAILED: {str(e)}")
        return{"statusCode":500, "body": f"{str(e)}"}
