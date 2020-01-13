data "aws_sns_topic" "this" {
  count = (1 - (var.create_sns_topic == true ? 1 : 0)) * (var.create == true ? 1 : 0)

  name = var.sns_topic_name
}

resource "aws_sns_topic" "this" {
  count = (var.create_sns_topic == true ? 1 : 0) * (var.create == true ? 1 : 0)

  name = var.sns_topic_name
}

locals {
  sns_topic_arn = element(concat(aws_sns_topic.this.*.arn, data.aws_sns_topic.this.*.arn, [
    ""]), 0)
}

resource "aws_sns_topic_subscription" "sns_notify_slack" {
  count = (var.create == true ? 1 : 0)

  topic_arn = local.sns_topic_arn
  protocol = "lambda"
  endpoint = aws_lambda_function.notify_slack[0].arn
}

resource "aws_lambda_permission" "sns_notify_slack" {
  count = (var.create == true ? 1 : 0)

  statement_id = "AllowExecutionFromSNS"
  action = "lambda:InvokeFunction"
  function_name = aws_lambda_function.notify_slack[0].function_name
  principal = "sns.amazonaws.com"
  source_arn = local.sns_topic_arn
}

resource "random_id" "id" {
  keepers = {
    timestamp = timestamp()
  }
  byte_length = 8
}

data "archive_file" "notify_slack" {
  count = (var.create == true ? 1 : 0)

  type = "zip"
  source_file = "${path.module}/functions/notify_slack.py"
  output_path = "${path.module}/functions/notify_slack.${random_id.id.dec}.zip"
}

resource "aws_lambda_function" "notify_slack" {
  depends_on = [
    data.archive_file.notify_slack]

  count = (var.create == true ? 1 : 0)

  filename = "${path.module}/functions/notify_slack.${random_id.id.dec}.zip"

  function_name = var.lambda_function_name

  role = aws_iam_role.lambda[0].arn
  handler = "notify_slack.lambda_handler"
  runtime = "python3.6"
  timeout = 30
  kms_key_arn = var.kms_key_arn

  environment {
    variables = {
      SLACK_WEBHOOK_URL = var.slack_webhook_url
      SLACK_CHANNEL = var.slack_channel
      SLACK_USERNAME = var.slack_username
      SLACK_EMOJI = var.slack_emoji
      ENVIRONMENT = var.environment
    }
  }

  lifecycle {
    ignore_changes = [
      filename,
      last_modified,
    ]
  }
}

resource "aws_cloudwatch_log_group" "lambda_logs" {
  count = (var.create == true ? 1 : 0)
  name = "/aws/lambda/${var.lambda_function_name}"
  retention_in_days = 30
}
