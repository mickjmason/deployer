import json
import boto3
import os
import uuid

def handler(event, context):
    print("Halting processing")
    
    return {
        'statusCode': 500,
        'body': json.dumps("Processing halted")
    }

