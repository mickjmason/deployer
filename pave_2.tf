resource "aws_lambda_event_source_mapping" "example" {
  event_source_arn                   = aws_sqs_queue.request_queue.arn
  function_name                      = aws_lambda_function.request_queue_processor.arn
  maximum_batching_window_in_seconds = 30
  batch_size                         = 10
}

resource "aws_ecs_cluster" "deployment_cluster" {
  name = "deployment_cluster"
}

resource "aws_vpc" "deployer_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
}

resource "aws_iam_role" "deployer_task_execution_role" {
  name = "deployer_task_execution_role"

  assume_role_policy = jsonencode(
    {
      "Version" : "2012-10-17",
      "Statement" : [
        {
          "Action" : "sts:AssumeRole",
          "Principal" : {
            "Service" : "ecs-tasks.amazonaws.com"
          },
          "Effect" : "Allow",
          "Sid" : ""
        }
      ]
  })
}

resource "aws_iam_role_policy_attachment" "deployer_task_execution_role_policy_attachment" {
  role       = aws_iam_role.deployer_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_ecr_repository" "deployer_repository" {
  name = "deployer_repository"
}

output "deployer_ecs_arn" {
  value = aws_ecs_cluster.deployment_cluster.arn
}

output "deployer_ecs_id" {
  value = aws_ecs_cluster.deployment_cluster.id
}

output "deployer_ecr_url" {
  value = aws_ecr_repository.deployer_repository.repository_url
}

output "deployer_ecr_arn" {
  value = aws_ecr_repository.deployer_repository.arn
}

resource "aws_s3_bucket" "template_store" {
  bucket = "templatestore"
}

resource "aws_dynamodb_table" "user_deployment_mapping" {
  name         = "user_deployment_mapping"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "userid"
  range_key    = "itemid"

  attribute {
    name = "userid"
    type = "S"
  }

  attribute {
    name = "itemid"
    type = "S"
  }

  attribute {
    name = "mappingid"
    type = "S"
  }

  attribute {
    name = "service"
    type = "S"
  }

  local_secondary_index {
    name            = "userid_mapping_index"
    projection_type = "INCLUDE"
    range_key       = "mappingid"
    non_key_attributes = [
      "filename",
      "deployed",
      "service"
    ]
  }

  local_secondary_index {
    name            = "userid_service_index"
    projection_type = "INCLUDE"
    range_key       = "service"
    non_key_attributes = [
      "filename",
      "deployed",
      "mappingid"
    ]
  }

}

locals {
  subnet_ids = join(",", [for s in data.aws_subnet.default_ids: s.id])
}

locals {
  security_group = data.aws_security_groups.default_security_groups.ids[0]
}

resource "aws_lambda_function" "deployment_task_invoker" {
  filename         = "deployment_task_invoker.zip" 
  function_name    = "deployment_task_invoker"
  role             = aws_iam_role.service_processing_exec_role.arn
  handler          = "deployment_task_invoker.handler"               
  runtime          = "python3.9"                                    
  source_code_hash = filebase64sha256("deployment_task_invoker.zip") 
  environment {
    variables = {
      REST_API_ID             = aws_api_gateway_rest_api.deployer.id
      PREPARATION_STATE_MACHINE_ARN = aws_sfn_state_machine.preparation_state_machine.arn
      SUBNETS = local.subnet_ids
      SECURITY_GROUPS = local.security_group
    }
  }
}

resource "aws_lambda_function" "deployment_state_invoker" {
  filename         = "deployment_state_invoker.zip" 
  function_name    = "deployment_state_invoker"
  role             = aws_iam_role.service_processing_exec_role.arn
  handler          = "deployment_state_invoker.handler"               
  runtime          = "python3.9"                                     
  source_code_hash = filebase64sha256("deployment_state_invoker.zip") 
  environment {
    variables = {
      DEPLOYMENT_STATE_MACHINE_ARN = aws_sfn_state_machine.deployment_execution_state_machine.arn
    }
  }
}


# resource "aws_sfn_state_machine" "deployment_execution_state_machine" {
#   name     = "deployment_execution_state_machine"
#   role_arn = aws_iam_role.deployment_execution_state_machine_exec_role.arn

#   definition = templatefile("${path.module}/json/deployment_step_function_ecs.json",{
#     functionname = "arn:aws:lambda:us-east-1:000000000000:function:deployment_task_invoker",
#     subnets = data.aws_subnets.default.ids,
#     securitygroup = local.security_group,
#     ecs_cluster = aws_ecs_cluster.deployment_cluster.arn,
#     task_definition_arn = aws_ecs_task_definition.terraform_deployer_task_definition.arn
#   })
    
# }

resource "aws_sfn_state_machine" "deployment_execution_state_machine" {
  name     = "deployment_execution_state_machine"
  role_arn = aws_iam_role.deployment_execution_state_machine_exec_role.arn

  definition = <<EOF
    {
      "Comment" : "Preparation step function to initiate deployment for services",
      "StartAt" : "StartDeploymentTask",
      "States" : {
        "StartDeploymentTask": {
          "Type" : "Task",
          "Resource" : "arn:aws:states:::lambda:invoke",
          "OutputPath" : "$.Payload",
          "Parameters" : {
            "FunctionName" : "arn:aws:lambda:us-east-1:000000000000:function:deployment_task_invoker",
            "Payload.$" : "$"
          },
          "Retry" : [
            {
              "ErrorEquals" : [
                "Lambda.ServiceException",
                "Lambda.AWSLambdaException",
                "Lambda.SdkClientException",
                "Lambda.TooManyRequestsException"
              ],
              "IntervalSeconds" : 2,
              "MaxAttempts" : 6,
              "BackoffRate" : 2
            }
          ],
          "End" : true
        }
      }

  }
  EOF
}



resource "aws_iam_role" "deployment_execution_state_machine_exec_role" {
  name = "deployment_execution_state_machine_exec_role"

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


# Create an ECS service
resource "aws_ecs_service" "terraform_deployer_service" {
  name            = "my-terraform_deployer_service"
  cluster         = aws_ecs_cluster.deployment_cluster.id
  task_definition = aws_ecs_task_definition.terraform_deployer_task_definition.arn
  launch_type     = "FARGATE"

  # network_configuration {
  #   subnets = aws_subnet.ecs_subnet[*].id
  #   security_groups = [aws_security_group.ecs_sg.id]
  # }

  depends_on = [aws_ecs_task_definition.terraform_deployer_task_definition]
}
resource "aws_ecs_task_definition" "terraform_deployer_task_definition" {
  family                   = "terraform"
  network_mode             = "none"
  requires_compatibilities = ["FARGATE"]

  execution_role_arn = aws_iam_role.deployer_task_execution_role.arn

  container_definitions = <<EOF
  [
    {
      "name": "deployer",
      "image": "deployer:latest",
      "portMappings": [
        {
          "containerPort": 80,
          "hostPort": 80
        }
      ]
    }
  ]
EOF
}
