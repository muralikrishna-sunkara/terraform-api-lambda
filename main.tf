
# S3 Bucket for Lambda packages
resource "aws_s3_bucket" "lambda_bucket" {
  bucket = "${var.project_name}-lambda-bucket-${var.environment}-${data.aws_caller_identity.current.account_id}"

  tags = {
    Name        = "${var.project_name}-lambda-bucket"
    Environment = var.environment
  }
}

resource "aws_s3_bucket_versioning" "lambda_bucket_versioning" {
  bucket = aws_s3_bucket.lambda_bucket.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "lambda_bucket_encryption" {
  bucket = aws_s3_bucket.lambda_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# S3 Lifecycle policy for cost optimization
resource "aws_s3_bucket_lifecycle_configuration" "lambda_bucket_lifecycle" {
  bucket = aws_s3_bucket.lambda_bucket.id

  rule {
    id     = "delete-old-versions"
    status = "Enabled"

    noncurrent_version_expiration {
      noncurrent_days = 30
    }
  }

  rule {
    id     = "transition-to-ia"
    status = "Enabled"

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }
  }
}

# DynamoDB Table (On-Demand - Cost optimized)
resource "aws_dynamodb_table" "data_table" {
  name           = "${var.project_name}-data-table-${var.environment}"
  billing_mode   = var.dynamodb_billing_mode
  hash_key       = "id"

  attribute {
    name = "id"
    type = "S"
  }

  ttl {
    attribute_name = "ttl"
    enabled        = true
  }

  point_in_time_recovery {
    enabled = true
  }

  tags = {
    Name        = "${var.project_name}-data-table"
    Environment = var.environment
    CostOptimized = "true"
  }
}

# Archive Lambda function code
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/lambda_function.py"
  output_path = "${path.module}/lambda_function.zip"
}

# Upload Lambda package to S3
resource "aws_s3_object" "lambda_package" {
  bucket = aws_s3_bucket.lambda_bucket.id
  key    = "lambda-${var.project_name}-${var.environment}.zip"
  source = data.archive_file.lambda_zip.output_path
  etag   = data.archive_file.lambda_zip.output_base64sha256

  tags = {
    Name        = "${var.project_name}-lambda-package"
    Environment = var.environment
  }
}

# Lambda Function
resource "aws_lambda_function" "app" {
  filename            = data.archive_file.lambda_zip.output_path
  function_name       = "${var.project_name}-${var.environment}"
  role                = aws_iam_role.lambda_role.arn
  handler             = "lambda_function.lambda_handler"
  source_code_hash    = data.archive_file.lambda_zip.output_base64sha256
  runtime             = "python3.11"
  timeout             = var.lambda_timeout
  memory_size         = var.lambda_memory_size

  environment {
    variables = {
      DYNAMODB_TABLE = aws_dynamodb_table.data_table.name
      ENVIRONMENT    = var.environment
    }
  }

  depends_on = [aws_iam_role_policy_attachment.lambda_basic_execution]

  tags = {
    Name        = "${var.project_name}-function"
    Environment = var.environment
  }
}

# API Gateway REST API
resource "aws_apigatewayv2_api" "api" {
  name          = "${var.project_name}-api-${var.environment}"
  protocol_type = "HTTP"
  cors_configuration {
    allow_origins = ["*"]
    allow_methods = ["GET", "POST", "PUT", "DELETE", "OPTIONS"]
    allow_headers = ["Content-Type", "Authorization"]
  }

  tags = {
    Name        = "${var.project_name}-api"
    Environment = var.environment
  }
}

# API Gateway Integration
resource "aws_apigatewayv2_integration" "lambda_integration" {
  api_id           = aws_apigatewayv2_api.api.id
  integration_type = "AWS_PROXY"
  integration_method = "POST"
  payload_format_version = "2.0"
  integration_uri    = aws_lambda_function.app.invoke_arn
}

# API Gateway Routes
resource "aws_apigatewayv2_route" "get_items" {
  api_id    = aws_apigatewayv2_api.api.id
  route_key = "GET /items"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}

resource "aws_apigatewayv2_route" "get_item_by_id" {
  api_id    = aws_apigatewayv2_api.api.id
  route_key = "GET /items/{id}"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}

resource "aws_apigatewayv2_route" "create_item" {
  api_id    = aws_apigatewayv2_api.api.id
  route_key = "POST /items"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}

resource "aws_apigatewayv2_route" "update_item" {
  api_id    = aws_apigatewayv2_api.api.id
  route_key = "PUT /items/{id}"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}

resource "aws_apigatewayv2_route" "delete_item" {
  api_id    = aws_apigatewayv2_api.api.id
  route_key = "DELETE /items/{id}"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}

# API Gateway Stage
resource "aws_apigatewayv2_stage" "api_stage" {
  api_id      = aws_apigatewayv2_api.api.id
  name        = var.environment
  auto_deploy = true

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_logs.arn
    format         = "$context.requestId $context.extendedRequestId $context.identity.sourceIp $context.requestTime $context.routeKey $context.status"
  }

  tags = {
    Name        = "${var.project_name}-stage"
    Environment = var.environment
  }
}

# CloudWatch Logs for API Gateway (Cost optimized - 3 day retention)
resource "aws_cloudwatch_log_group" "api_logs" {
  name              = "/aws/apigateway/${var.project_name}-${var.environment}"
  retention_in_days = 3

  tags = {
    Name        = "${var.project_name}-api-logs"
    Environment = var.environment
    CostOptimized = "true"
  }
}

# Lambda Permission for API Gateway
resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.app.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.api.execution_arn}/*/*"
}

# Data source for current AWS account
data "aws_caller_identity" "current" {}