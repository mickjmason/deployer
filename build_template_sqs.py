import json
import boto3
import os
import uuid

def handler(event, context):
    print("Building sqs template")
    
    return {
        'statusCode': 200,
        'body': 'Built sqs template'
    }

