# IAM role for lambda execution
resource "aws_iam_role" "lambda" {
  name = "la_program_lambda"
  tags = local.application_tag

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "lambda.amazonaws.com"
        },
      },
    ],
  })
}

# allow lambdas to write to logs
resource "aws_iam_role_policy_attachment" "lambda_log" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# package all functions as zips
data "archive_file" "lambda_zips" {
  for_each    = local.lambda_names
  type        = "zip"
  source_file = "../backend/${each.key}"
  output_path = "../backend/${each.key}.zip"
}

# define all lambda functions
resource "aws_lambda_function" "api" {
  for_each = local.lambda_names

  function_name = "la_program_${each.value}"
  tags          = local.application_tag
  role          = aws_iam_role.lambda.arn

  filename    = data.archive_file.lambda_zips[each.key].output_path
  code_sha256 = data.archive_file.lambda_zips[each.key].output_base64sha256
  handler     = "${each.value}.lambda_handler"
  runtime     = "python3.14"
  timeout     = 10
}

# define log group for each lambda
resource "aws_cloudwatch_log_group" "api" {
  for_each = aws_lambda_function.api

  name = "/aws/lambda/${each.value.function_name}"
  tags = local.application_tag

  retention_in_days = 30
}

# define API Gateway
resource "aws_apigatewayv2_api" "api" {
  name                         = "la_program_api"
  tags                         = local.application_tag
  protocol_type                = "HTTP"
  disable_execute_api_endpoint = true

  cors_configuration {
    allow_origins = [
      "https://www.${local.domain}"
    ]
    allow_methods = [
      "*"
    ]
  }
}

resource "aws_apigatewayv2_integration" "api" {
  for_each = local.lambda_names

  api_id                 = aws_apigatewayv2_api.api.id
  integration_type       = "AWS_PROXY"
  integration_method     = "POST"
  integration_uri        = aws_lambda_function.api[each.key].invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "api" {
  for_each = local.lambda_names

  api_id    = aws_apigatewayv2_api.api.id
  route_key = "ANY /${each.value}"

  target = "integrations/${aws_apigatewayv2_integration.api[each.key].id}"
}

resource "aws_apigatewayv2_stage" "api" {
  api_id      = aws_apigatewayv2_api.api.id
  name        = "default_stage"
  auto_deploy = true
}

# allow API Gateway to call lambdas
resource "aws_lambda_permission" "api" {
  for_each = local.lambda_names

  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.api[each.key].function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.api.execution_arn}/*/*"
}

# set up API Gateway to serve through api. subdomain
resource "aws_apigatewayv2_domain_name" "api" {
  domain_name = local.api_domain

  domain_name_configuration {
    certificate_arn = aws_acm_certificate_validation.cert.certificate_arn
    endpoint_type   = "REGIONAL"
    security_policy = "TLS_1_2"
  }
}

resource "aws_route53_record" "api_alias" {
  zone_id = data.aws_route53_zone.zone.zone_id
  name    = "api"
  type    = "A"

  alias {
    name                   = aws_apigatewayv2_domain_name.api.domain_name_configuration[0].target_domain_name
    zone_id                = aws_apigatewayv2_domain_name.api.domain_name_configuration[0].hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_apigatewayv2_api_mapping" "api" {
  api_id      = aws_apigatewayv2_api.api.id
  domain_name = aws_apigatewayv2_domain_name.api.id
  stage       = aws_apigatewayv2_stage.api.id
}