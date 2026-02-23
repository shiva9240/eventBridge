provider "aws" {
  region = "us-east-1"
}

module "eventbridge" {
  source = "../../modules/eventbridge_org"

  create_event_bus = false # reuse an existing shared bus
  event_bus_name   = "org-events"

  # Explicitly allow a producer account to PutEvents
  allow_account_ids = ["222222222222"] # replace

  rules = [
    {
      name = "infra-alarms"
      event_pattern = {
        "source"      = ["aws.cloudwatch"]
        "detail-type" = ["CloudWatch Alarm State Change"]
        "detail"      = { "state" = { "value" = ["ALARM"] } }
      }
      targets = [
        {
          id                = "infra-queue"
          arn               = "arn:aws:sqs:us-east-1:111111111111:infra-alerts" # SQS team provides
          type              = "sqs"
          role_arn          = "arn:aws:iam::111111111111:role/eb-to-sqs-role" # SQS team provides
          maximum_retries   = 10
          maximum_event_age = 3600
          dead_letter_arn   = "arn:aws:sqs:us-east-1:111111111111:infra-alerts-dlq" # SQS team provides
        }
      ]
    }
  ]
}
