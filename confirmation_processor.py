import json
import boto3
import os
import uuid



def handler(event, context):
    
    endpoint = "http://%s:4566" % os.environ["LOCALSTACK_HOSTNAME"]
    stepfunction = boto3.client("stepfunctions", endpoint_url=endpoint)
    body = json.loads(event["body"])
    task_token = body["token"]
    userid = body["userid"]
    itemid = body["itemid"]
    validated = body["validated"]
    print(f"THE VALUE OF VALIDATED IS: {validated}")
    if validated==1:
        update_deployment_status(userid,itemid,"deployed")
        response = stepfunction.send_task_success(
            taskToken=task_token, output=json.dumps("PROCESSED SUCCESSFULLY")
        )
    else:
        update_deployment_status(userid,itemid,"failed")
        response = stepfunction.send_task_failure(
            taskToken=task_token, error=json.dumps(f"error: DEPLOYMENT NOT VALIDATED: userid: {userid}, itemid: {itemid}")
        )


    return {"statusCode": 200, "body": response}


def update_deployment_status(userid,itemid, deployment_status):
    endpoint = "http://%s:4566" % os.environ["LOCALSTACK_HOSTNAME"]
    dynamodb = boto3.client("dynamodb", endpoint_url=endpoint)
    mapping_table_name = os.environ["DEPLOYMENT_MAPPING_TABLE_NAME"]
    try:
        dynamodb.update_item(
            TableName=mapping_table_name,
            Key={"userid": {"S": userid}, "itemid":{"S":itemid}},
            AttributeUpdates={
                "status": {"Value": {"S": deployment_status}, "Action": "PUT"}
            },
        )

        response = {
            "statusCode": 200,
            "body": "Template saved to DB",
            "userid": userid,
            "itemid": itemid,
            "status": deployment_status
        }

        print(f"SAVED TO DATABASE: {response}")

    except Exception as e:
        response = {"statusCode": 500, "body": f"NOT SAVED TO DATABASE: {str(e)}"}