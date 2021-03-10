variable "create" {
  description = "Whether to create all resources"
  type        = bool
  default     = true
}

variable "tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
  default     = {}
}

variable "create_sns_topic" {
  description = "Whether to create new SNS topic"
  type        = bool
  default     = true
}

variable "lambda_role" {
  description = "IAM role attached to the Lambda Function.  If this is set then a role will not be created for you."
  type        = string
  default     = ""
}

variable "create_with_kms_key" {
  description = "Whether to create resources with KMS encryption"
  type        = bool
  default     = false
}

variable "reserved_concurrent_executions" {
  description = "The amount of reserved concurrent executions for this lambda function. A value of 0 disables lambda from being triggered and -1 removes any concurrency limitations"
  type        = number
  default     = -1
}

variable "subscription_filter_policy" {
  description = "(Optional) A valid filter policy that will be used in the subscription to filter messages seen by the target resource."
  type        = string
  default     = null
}

variable "iam_role_name_prefix" {
  description = "A unique role name beginning with the specified prefix"
  type        = string
  default     = "notify-slack"
}

variable "lambda_function_name" {
  description = "The name of the Lambda function to create"
  type        = string
  default     = "notify_slack"
}

variable "lambda_description" {
  description = "The description of the Lambda function"
  type        = string
  default     = null
}

variable "lambda_function_tags" {
  description = "Additional tags for the Lambda function"
  type        = map(string)
  default     = {}
}

variable "lambda_function_store_on_s3" {
  description = "Whether to store produced artifacts on S3 or locally."
  type        = bool
  default     = false
}

variable "lambda_function_s3_bucket" {
  description = "S3 bucket to store artifacts"
  type        = string
  default     = null
}

variable "lambda_function_vpc_subnet_ids" {
  description = "List of subnet ids when Lambda Function should run in the VPC. Usually private or intra subnets."
  type        = list(string)
  default     = null
}

variable "lambda_function_vpc_security_group_ids" {
  description = "List of security group ids when Lambda Function should run in the VPC."
  type        = list(string)
  default     = null
}

variable "sns_topic_name" {
  description = "The name of the SNS topic to create"
}

variable "slack_webhook_url" {
  description = "The URL of Slack webhook"
}

variable "slack_channel" {
  description = "The name of the channel in Slack for notifications"
}

variable "slack_username" {
  description = "The username that will appear on Slack messages"
}

variable "slack_emoji" {
  description = "A custom emoji that will appear on Slack messages"
  default     = ":aws:"
}

variable "kms_key_arn" {
  description = "ARN of the KMS key used for decrypting slack webhook url"
  default     = ""
}

variable "environment" {
  description = "Environment of the notification"
  default     = "none"
}

variable "iam_role_tags" {
  description = "Additional tags for the IAM role"
  type        = map(string)
  default     = {}
}

variable "iam_role_boundary_policy_arn" {
  description = "The ARN of the policy that is used to set the permissions boundary for the role"
  type        = string
  default     = null
}

variable "log_events" {
  description = "Boolean flag to enabled/disable logging of incoming events"
  type        = bool
  default     = false
}
