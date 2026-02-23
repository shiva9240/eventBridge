provider "aws" {
  region = "us-east-1"
}

module "eventbridge" {
  source = "../../modules/eventbridge_org"

  create_event_bus = true
  event_bus_name   = "org-events"

  # Allow entire AWS Organization to PutEvents
  allow_org_id = "o-xxxxxxxxxx" # <-- replace with your Org ID

  rules = [
    {
      name        = "app-errors"
      description = "Route application error events to Lambda"
      event_pattern = {
        "source"      = ["my.app"]
        "detail-type" = ["app.error"]
        "detail"      = { "env" = ["dev", "prod"] }
      }
      targets = [
        {
          id             = "errors-lambda"
          ssm_param_name = "/prod/lambda/errors_function_arn" # Lambda team stores ARN in SSM
          type           = "lambda"

          # ---------- Input Transformer (NEW) ----------
          # pick fields from incoming event:
          input_paths = {
            env = "$.detail.env"
            msg = "$.detail.message"
            typ = "$.detail-type"
          }
          # shape the final JSON delivered to Lambda:
          input_template = "{\"environment\": <env>, \"message\": <msg>, \"event_type\": <typ>}"
          # --------------------------------------------

          maximum_retries   = 24
          maximum_event_age = 3600
          # Optional DLQ on EventBridge->Lambda path
          dead_letter_arn = "arn:aws:sqs:us-east-1:111111111111:eb-target-dlq"
        }
      ]
    }
  ]

  create_archive         = true
  archive_name           = "org-events-archive"
  archive_retention_days = 30
}
