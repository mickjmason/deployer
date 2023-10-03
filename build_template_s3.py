import json
import boto3
import os
import uuid


def handler(event, context):
    build_response = build_template(event)
    db_save_response = save_db_mapping(build_response)

    return db_save_response


def build_template(event):
    userid = event["userid"]
    service = event["service"]
    mappingid = event["mappingid"]
    itemid = str(uuid.uuid4())
    template_bucket_name = os.environ["TEMPLATE_BUCKET_NAME"]
    s3 = boto3.resource("s3")

    contents = f'''resource "aws_s3_bucket" "{userid}-{itemid}" {{
        bucket = "{userid}-{itemid}"
     }}
     
     output "{userid}-bucketname" {{
     value=aws_s3_bucket.{userid}-{itemid}.id
     }}'''

    filename = f"{userid}/{mappingid}/{itemid}.tf"
    with open(f"/tmp/{itemid}.tf", "a") as data:
        data.write(contents + "\n")
    s3.Bucket(template_bucket_name).upload_file(f"/tmp/{itemid}.tf", filename)

    return {
        "userid": userid,
        "service": service,
        "mappingid": mappingid,
        "itemid": itemid,
        "filename": filename,
    }


def save_db_mapping(template_object):
    userid = template_object["userid"]
    service = template_object["service"]
    mappingid = template_object["mappingid"]
    filename = template_object["filename"]
    itemid = template_object["itemid"]
    endpoint = "http://%s:4566" % os.environ["LOCALSTACK_HOSTNAME"]
    dynamodb = boto3.client("dynamodb", endpoint_url=endpoint)
    mapping_table_name = os.environ["DEPLOYMENT_MAPPING_TABLE_NAME"]
    try:
        dynamodb.update_item(
            TableName=mapping_table_name,
            Key={"userid": {"S": userid}, "itemid":{"S":itemid}},
            AttributeUpdates={
                "mappingid": {"Value": {"S": mappingid}, "Action": "PUT"},
                "service": {"Value": {"S": service}, "Action": "PUT"},
                "filename": {"Value": {"S": filename}, "Action": "PUT"},
            },
        )

        response = {
            "statusCode": 200,
            "body": "Template saved to DB",
            "userid": userid,
            "itemid": itemid,
            "mappingid": mappingid,
            "service": service,
            "filename": filename,
            "restapiid": os.environ["REST_API_ID"],
            "localstack_hostname": os.environ["LOCALSTACK_HOSTNAME"],
            "status": "deploying"
        }

        print(f"SAVED TO DATABASE: {response}")

    except Exception as e:
        response = {"statusCode": 500, "body": f"NOT SAVED TO DATABASE: {str(e)}"}

    return response
