import json
import boto3
import os
import uuid


sqs = boto3.client('sqs')


def handler(event, context):
    results = []
    request_queue_url = os.environ.get('REQUEST_QUEUE_URL')

    for record in event['Records']:

        sqs = boto3.client('sqs')
        receipt_handle = record['receiptHandle']
        results.append(process_record(record["body"]))
    
    return {
        'statusCode': 200,
        'body': f"{results}"
    }


def process_record(payload):
    
    preparation_state_machine = os.environ.get('PREPARATION_STATE_MACHINE_ARN')

    try:
        
        statemachine = boto3.client('stepfunctions')
        print(f"Starting stepfunction for service {payload}")
        response = statemachine.start_execution(stateMachineArn=preparation_state_machine, input=payload)
        
        
        return response
    except Exception as e:
        return {
            'statusCode': 500,
            'body': f'Error: {str(e)}'
        }


