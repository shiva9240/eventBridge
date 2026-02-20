provider "aws" {
  region = var.region
}

# 1) Read the Lambda *name* from SSM (sensitive by default)
data "aws_ssm_parameter" "orders_processor_name" {
  name            = var.orders_lambda_name_param
  with_decryption = false
}

# 2) Use nonsensitive() and resolve the Lambda ARN here (not in the module)
data "aws_lambda_function" "orders" {
  function_name = nonsensitive(data.aws_ssm_parameter.orders_processor_name.value)
}

module "eventbridge_secure" {
  source         = "../../modules/eventbridge_secure"
  event_bus_name = var.event_bus_name
  create_bus     = var.create_bus
  tags           = var.tags

  rules = [
    {
      name        = "manual-test-rule"
      description = "Rule to test manual events with minimal payload"
      event_pattern = {
        source        = ["my.test"]
        "detail-type" = ["testEvent"]
      }
      targets = [
        {
          target_id = "orders-lambda"
          # 3) Pass the *ARN* to the module; do NOT pass function_name here
          arn = data.aws_lambda_function.orders.arn

          # safe/minimal payload to the function
          input_transformer = {
            input_template = "{\"message\": <msg>, \"requestId\": <id>}"
            input_paths = {
              msg = "$.detail.message"
              id  = "$.id"
            }
          }
          retry_policy = {
            maximum_event_age_in_seconds = 3600
            maximum_retry_attempts       = 2
          }
          # dlq_arn = var.dlq_arn
        }
      ]
    }
  ]
}
