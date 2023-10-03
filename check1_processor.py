import json
import boto3
import os
import uuid

def handler(event, context):
    print(f"I'm doing check 1 {event}")
    
    return {
        'statusCode': 200,
        'body': json.dumps("Check 1 complete")
    }

