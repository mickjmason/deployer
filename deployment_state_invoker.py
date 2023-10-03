import json
import boto3
import os
import uuid

def handler(event, context):
    deployment_state_machine = os.environ.get('DEPLOYMENT_STATE_MACHINE_ARN')
    print("CHUFFCHUFF")

    try:
        
        statemachine = boto3.client('stepfunctions')
        print(f"Starting deployment stepfunction with: {event}")
        response = statemachine.start_execution(stateMachineArn=deployment_state_machine, input=event)
        
        
        return response
    
    except Exception as e:
        return {
            'statusCode': 500,
            'body': f'Error: {str(e)}'
        }

