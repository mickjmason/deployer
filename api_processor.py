import json
import boto3
import os
import uuid


sqs = boto3.client('sqs')


def handler(event, context):
    try:
        # Check if the 'services' key exists in the event
        if 'body' not in event:
            return {
                'statusCode': 400,
                'body': json.dumps('Missing "body" key in the event.')
            }

        body = json.loads(event["body"])

        if 'request_data' not in body:
            return {
                'statusCode': 400,
                'body': json.dumps('Missing "request_data" key in the body')
            }

        request_data = body["request_data"]
        print(f"\n\n\n\n**************\n\n{request_data}")
        if 'services' not in request_data or 'userid' not in request_data:
            return {
                'statusCode': 400,
                'body': json.dumps('request_data must contain a "services" and a "userid" key.')
            }

        # Convert the comma-separated string of services to a list
        services = request_data['services'].split(',')
        userid = request_data['userid']

        print(f"userid: {userid}\n\nservices: {services}")

        # Define the reference list containing all valid services
        valid_services = ['s3','dynamodb','sqs']  

        # Check if all elements in the 'services' list are in the 'valid_services' list
        if all(service in valid_services for service in services):
            
            process_services(services,userid)
            return {
                'statusCode': 200,
                'body': 'Service requests delivered to request_queue'
            }
        else:
            return {
                'statusCode': 400,
                'body': json.dumps('Not all services are valid.')
            }

    except Exception as e:
        return {
            'statusCode': 500,
            'body': json.dumps(f'Error: {str(e)}')
        }

def process_services(services,userid):
    request_queue_url = os.environ.get('REQUEST_QUEUE_URL')
    print(request_queue_url)
    mapping_id = uuid.uuid4()
    try:
        for service in services:
            print(f"+++++++++++++++++++++++\n\nAdding {service} from {services} to queue")
            message_body = {
                "userid": userid,
                "service": service,
                "mappingid": str(mapping_id)
            }
       
            # Send a message to the SQS queue
            sqs.send_message(
                QueueUrl=request_queue_url,
                MessageBody=json.dumps(message_body),
                MessageGroupId=str(mapping_id)
            )
        return True
    except Exception as e:
        print(f'Error sending message to SQS: {str(e)}')
        return False




