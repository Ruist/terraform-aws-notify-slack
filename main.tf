data "aws_sns_topic" "this" {
  count = (1 - (var.create_sns_topic == true ? 1 : 0)) * (var.create == true ? 1 : 0)

  name = var.sns_topic_name
}

resource "aws_cloudwatch_log_group" "lambda" {
  count = (var.create == true ? 1 : 0)
  name = "/aws/lambda/${var.lambda_function_name}"
  retention_in_days = 30
}

resource "aws_sns_topic" "this" {
  count = (var.create_sns_topic == true ? 1 : 0) * (var.create == true ? 1 : 0)

  name = var.sns_topic_name
}

locals {
  sns_topic_arn = element(concat(aws_sns_topic.this.*.arn, data.aws_sns_topic.this.*.arn, [
    ""]), 0)

  lambda_policy_document = {
    sid       = "AllowWriteToCloudwatchLogs"
    effect    = "Allow"
    actions   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
    resources = [replace("${element(concat(aws_cloudwatch_log_group.lambda[*].arn, list("")), 0)}:*", ":*:*", ":*")]
  }

  lambda_policy_document_kms = {
    sid       = "AllowKMSDecrypt"
    effect    = "Allow"
    actions   = ["kms:Decrypt"]
    resources = [var.kms_key_arn]
  }
}

data "aws_iam_policy_document" "lambda" {
  count = var.create ? 1 : 0

  dynamic "statement" {
    for_each = concat([local.lambda_policy_document], var.kms_key_arn != "" ? [local.lambda_policy_document_kms] : [])
    content {
      sid       = statement.value.sid
      effect    = statement.value.effect
      actions   = statement.value.actions
      resources = statement.value.resources
    }
  }
}

resource "aws_sns_topic_subscription" "sns_notify_slack" {
  count = (var.create == true ? 1 : 0)

  topic_arn     = local.sns_topic_arn
  protocol      = "lambda"
  endpoint      = module.lambda.this_lambda_function_arn
  filter_policy = var.subscription_filter_policy
}

data "archive_file" "notify_slack" {
  count = (var.create == true ? 1 : 0)

  type = "zip"
  output_path = "${path.module}/files/dotfiles.zip"
  source {
    content = file("${path.module}/functions/notify_slack.py")
    filename = "notify_slack.py"
  }
}

module "lambda" {
  source  = "terraform-aws-modules/lambda/aws"
  version = "1.28.0"

  create = var.create

  function_name = var.lambda_function_name
  description   = var.lambda_description

  handler                        = "notify_slack.lambda_handler"
  source_path                    = "${path.module}/functions/notify_slack.py"
  runtime                        = "python3.8"
  timeout                        = 30
  kms_key_arn                    = var.kms_key_arn
  reserved_concurrent_executions = var.reserved_concurrent_executions

  # If publish is disabled, there will be "Error adding new Lambda Permission for notify_slack: InvalidParameterValueException: We currently do not support adding policies for $LATEST."
  publish = true

  environment_variables = {
    SLACK_WEBHOOK_URL = var.slack_webhook_url
    SLACK_CHANNEL     = var.slack_channel
    SLACK_USERNAME    = var.slack_username
    SLACK_EMOJI       = var.slack_emoji
    LOG_EVENTS        = var.log_events ? "True" : "False"
    ENVIRONMENT       = var.environment
  }

  lambda_role               = aws_iam_role.lambda[0].arn
  role_name                 = "${var.iam_role_name_prefix}-${var.lambda_function_name}"
  role_permissions_boundary = var.iam_role_boundary_policy_arn
  role_tags                 = var.iam_role_tags

  # Do not use Lambda's policy for cloudwatch logs, because we have to add a policy
  # for KMS conditionally. This way attach_policy_json is always true independenty of
  # the value of presense of KMS's famous "computed values in count" bug...
  attach_cloudwatch_logs_policy = false
  attach_policy_json            = true
  policy_json                   = element(concat(data.aws_iam_policy_document.lambda[*].json, [""]), 0)

  use_existing_cloudwatch_log_group = true
  attach_network_policy             = var.lambda_function_vpc_subnet_ids != null

  allowed_triggers = {
    AllowExecutionFromSNS = {
      principal  = "sns.amazonaws.com"
      source_arn = local.sns_topic_arn
    }
  }

  store_on_s3 = var.lambda_function_store_on_s3
  s3_bucket   = var.lambda_function_s3_bucket

  vpc_subnet_ids         = var.lambda_function_vpc_subnet_ids
  vpc_security_group_ids = var.lambda_function_vpc_security_group_ids

  tags = merge(var.tags, var.lambda_function_tags)

  depends_on = [aws_cloudwatch_log_group.lambda]
}

