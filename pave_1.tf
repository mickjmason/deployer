resource "aws_lambda_function" "api_processor" {
  filename         = "api_processor.zip" 
  function_name    = "api_processor"
  role             = aws_iam_role.api_processor_exec_role.arn
  handler          = "api_processor.handler"               
  runtime          = "python3.9"                           
  source_code_hash = filebase64sha256("api_processor.zip") 
  environment {
    variables = {
      REQUEST_QUEUE_URL = aws_sqs_queue.request_queue.url
    }
  }
}

resource "aws_lambda_function" "confirmation_processor" {
  filename         = "confirmation_processor.zip" 
  function_name    = "confirmation_processor"
  role             = aws_iam_role.api_processor_exec_role.arn
  handler          = "confirmation_processor.handler"               
  runtime          = "python3.9"                           
  source_code_hash = filebase64sha256("confirmation_processor.zip") 
  environment {
    variables = {
      REQUEST_QUEUE_URL = aws_sqs_queue.request_queue.url
      DEPLOYMENT_MAPPING_TABLE_NAME = aws_dynamodb_table.user_deployment_mapping.id
    }
  }
}


resource "aws_iam_role" "api_processor_exec_role" {
  name = "api_processor_exec_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role" "api_role" {
  name = "api_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "apigateway.amazonaws.com"
        }
      }
    ]
  })
}


resource "aws_api_gateway_rest_api" "deployer" {
  name        = "Deployer"
  description = "An API for deploying infrastructure from terraform files"
}

resource "aws_api_gateway_resource" "provision_resource" {
  rest_api_id = aws_api_gateway_rest_api.deployer.id
  parent_id   = aws_api_gateway_rest_api.deployer.root_resource_id
  path_part   = "provision"
}

resource "aws_api_gateway_method" "deployer_post_method" {
  rest_api_id   = aws_api_gateway_rest_api.deployer.id
  resource_id   = aws_api_gateway_resource.provision_resource.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "deployer_post_integration" {
  rest_api_id             = aws_api_gateway_rest_api.deployer.id
  resource_id             = aws_api_gateway_resource.provision_resource.id
  http_method             = aws_api_gateway_method.deployer_post_method.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = "arn:aws:apigateway:us-east-1:lambda:path/2015-03-31/functions/${aws_lambda_function.api_processor.arn}/invocations"
  depends_on = [
    aws_api_gateway_method.deployer_post_method
  ]
}

resource "aws_api_gateway_resource" "confirmation_resource" {
  rest_api_id = aws_api_gateway_rest_api.deployer.id
  parent_id   = aws_api_gateway_rest_api.deployer.root_resource_id
  path_part   = "confirmation"
}

resource "aws_api_gateway_method" "confirmation_post_method" {
  rest_api_id   = aws_api_gateway_rest_api.deployer.id
  resource_id   = aws_api_gateway_resource.confirmation_resource.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "confirmation_post_integration" {
  rest_api_id             = aws_api_gateway_rest_api.deployer.id
  resource_id             = aws_api_gateway_resource.confirmation_resource.id
  http_method             = aws_api_gateway_method.confirmation_post_method.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = "arn:aws:apigateway:us-east-1:lambda:path/2015-03-31/functions/${aws_lambda_function.confirmation_processor.arn}/invocations"
  depends_on = [
    aws_api_gateway_method.confirmation_post_method
  ]
}

resource "aws_lambda_permission" "apigateway_deployer" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.api_processor.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "arn:aws:execute-api:us-east-1:000000000000:${aws_api_gateway_rest_api.deployer.id}/*/${aws_api_gateway_method.deployer_post_method.http_method}/deployerresource"
}

resource "aws_api_gateway_deployment" "public_deployer" {
  depends_on  = [aws_api_gateway_integration.deployer_post_integration]
  rest_api_id = aws_api_gateway_rest_api.deployer.id
  stage_name  = "test" 
  variables = {
    # You can define stage variables here if needed
  }
}

resource "aws_lambda_function" "build_template_s3" {
  filename         = "build_template_s3.zip" 
  function_name    = "build_template_s3"
  role             = aws_iam_role.service_processing_exec_role.arn
  handler          = "build_template_s3.handler"               
  runtime          = "python3.9"                               
  source_code_hash = filebase64sha256("build_template_s3.zip") 
  environment {
    variables = {
      TEMPLATE_BUCKET_NAME          = aws_s3_bucket.template_store.id
      TEMPLATE_BUCKET_ARN           = aws_s3_bucket.template_store.arn
      DEPLOYMENT_MAPPING_TABLE_NAME = aws_dynamodb_table.user_deployment_mapping.id
      REST_API_ID             = aws_api_gateway_rest_api.deployer.id

    }
  }
}

resource "aws_lambda_function" "build_template_dynamodb" {
  filename         = "build_template_dynamodb.zip" 
  function_name    = "build_template_dynamodb"
  role             = aws_iam_role.service_processing_exec_role.arn
  handler          = "build_template_dynamodb.handler"               
  runtime          = "python3.9"                                     
  source_code_hash = filebase64sha256("build_template_dynamodb.zip") 
  environment {
    variables = {
      REQUEST_QUEUE_URL             = aws_sqs_queue.request_queue.url
      PREPARATION_STATE_MACHINE_ARN = aws_sfn_state_machine.preparation_state_machine.arn
    }
  }
}

resource "aws_lambda_function" "build_template_sqs" {
  filename         = "build_template_sqs.zip" 
  function_name    = "build_template_sqs"
  role             = aws_iam_role.service_processing_exec_role.arn
  handler          = "build_template_sqs.handler"               
  runtime          = "python3.9"                                
  source_code_hash = filebase64sha256("build_template_sqs.zip") 
  environment {
    variables = {
      REQUEST_QUEUE_URL             = aws_sqs_queue.request_queue.url
      PREPARATION_STATE_MACHINE_ARN = aws_sfn_state_machine.preparation_state_machine.arn
    }
  }
}

resource "aws_lambda_function" "halt_processing_processor" {
  filename         = "halt_processing_processor.zip" 
  function_name    = "halt_processing_processor"
  role             = aws_iam_role.service_processing_exec_role.arn
  handler          = "halt_processing_processor.handler"               
  runtime          = "python3.9"                                       
  source_code_hash = filebase64sha256("halt_processing_processor.zip") 
  environment {
    variables = {
      REQUEST_QUEUE_URL             = aws_sqs_queue.request_queue.url
      PREPARATION_STATE_MACHINE_ARN = aws_sfn_state_machine.preparation_state_machine.arn
    }
  }
}

resource "aws_iam_role" "service_processing_exec_role" {
  name = "service_processing_exec_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "service_processing_exec_role_policy" {
  name = "service_processing_exec_role_policy"
  role = aws_iam_role.service_processing_exec_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "dynamodb:*",
        ]
        Effect   = "Allow"
        Resource = "*"
      },
      {
        Action = [
          "s3:*",
        ]
        Effect   = "Allow"
        Resource = "*"
      },
    ]
  })
}

resource "aws_sqs_queue" "request_queue" {
  name                        = "request_queue.fifo"
  fifo_queue                  = true
  content_based_deduplication = true
}

resource "aws_sqs_queue" "request_queue_deadletter" {
  name = "request_queue-deadletter-queue"
  redrive_allow_policy = jsonencode({
    redrivePermission = "byQueue",
    sourceQueueArns   = [aws_sqs_queue.request_queue.arn]
  })
}

resource "aws_lambda_function" "request_queue_processor" {
  filename         = "request_queue_processor.zip" 
  function_name    = "request_queue_processor"
  role             = aws_iam_role.request_queue_processor_exec_role.arn
  handler          = "request_queue_processor.handler"               
  runtime          = "python3.9"                                     
  source_code_hash = filebase64sha256("request_queue_processor.zip") 
  environment {
    variables = {
      REQUEST_QUEUE_URL             = aws_sqs_queue.request_queue.url
      PREPARATION_STATE_MACHINE_ARN = aws_sfn_state_machine.preparation_state_machine.arn
    }
  }
}

resource "aws_iam_role" "request_queue_processor_exec_role" {
  name = "request_queue_processor_exec_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}


resource "aws_sfn_state_machine" "preparation_state_machine" {
  name     = "preparation_state_machine"
  role_arn = aws_iam_role.preparation_state_machine_exec_role.arn

  definition = file("${path.module}/json/preparation_state_machine.json")
}

resource "aws_iam_role" "preparation_state_machine_exec_role" {
  name = "preparation_state_machine_exec_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service : [
            "lambda.amazonaws.com",
            "states.amazonaws.com"
          ]
        }
      }
    ]
  })
}

resource "aws_lambda_function" "check1_processor" {
  filename         = "check1_processor.zip" 
  function_name    = "check1_processor"
  role             = aws_iam_role.request_queue_processor_exec_role.arn
  handler          = "check1_processor.handler"               
  runtime          = "python3.9"                              
  source_code_hash = filebase64sha256("check1_processor.zip") 
  environment {
    variables = {
      REQUEST_QUEUE_URL = aws_sqs_queue.request_queue.url
    }
  }
}

resource "aws_lambda_function" "check2_processor" {
  filename         = "check2_processor.zip" 
  function_name    = "check2_processor"
  role             = aws_iam_role.request_queue_processor_exec_role.arn
  handler          = "check2_processor.handler"               
  runtime          = "python3.9"                              
  source_code_hash = filebase64sha256("check2_processor.zip") 
  environment {
    variables = {
      REQUEST_QUEUE_URL = aws_sqs_queue.request_queue.url
    }
  }
}
