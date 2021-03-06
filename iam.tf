data "aws_iam_policy_document" "assume_role" {
  count = (var.create == true ? 1 : 0)

  statement {
    effect = "Allow"

    actions = [
      "sts:AssumeRole"]

    principals {
      type = "Service"
      identifiers = [
        "lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda" {
  count = (var.create == true ? 1 : 0)

  name_prefix = "lambda"
  assume_role_policy = data.aws_iam_policy_document.assume_role[0].json
}
