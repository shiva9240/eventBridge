#############################################
# Secure EventBridge module: no hardcoding
# - Optional bus creation
# - Rules with Lambda targets
# - Lambda ARNs can be computed from function names (no ARNs in code)
# - Optional DLQ + retry policy per target
# - Optional input_transformer to minimize data passed
# - Least-privilege Lambda permission per rule
#############################################

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Create an EventBridge bus only if requested and not default
resource "aws_cloudwatch_event_bus" "this" {
  count = var.create_bus && var.event_bus_name != "default" ? 1 : 0
  name  = var.event_bus_name
}

locals {
  effective_bus_name = length(aws_cloudwatch_event_bus.this) > 0 ? aws_cloudwatch_event_bus.this[0].name : var.event_bus_name

  # Collect unique Lambda function names referenced by targets so we can look them up
  lambda_function_names = toset(flatten([
    for r in var.rules : [
      for t in r.targets : (
        contains(keys(t), "function_name") && t.function_name != null ? t.function_name : null
      )
    ]
  ]))
}

# Remove nulls from the set
locals {
  lambda_function_names_clean = toset([for n in local.lambda_function_names : n if n != null])
}

# Lookup Lambda ARNs by function name (resolves latest version/qualifier externally via alias if you use one)
# This avoids hardcoding ARNs in code. Users can pass either function_name or a raw arn per target.
data "aws_lambda_function" "by_name" {
  for_each      = local.lambda_function_names_clean
  function_name = each.key
}

resource "aws_cloudwatch_event_rule" "rules" {
  for_each            = { for r in var.rules : r.name => r }
  name                = each.value.name
  description         = lookup(each.value, "description", null)
  event_bus_name      = local.effective_bus_name
  event_pattern       = contains(keys(each.value), "event_pattern") && each.value.event_pattern != null ? jsonencode(each.value.event_pattern) : null
  schedule_expression = lookup(each.value, "schedule_expression", null)
  state               = upper(lookup(each.value, "state", "ENABLED"))
  tags                = var.tags
}

# Flatten rules -> targets for per-target resources
locals {
  targets = flatten([
    for r in var.rules : [
      for t in r.targets : {
        rule_name = r.name
        target    = t
      }
    ]
  ])
}

# Wire targets to rules with optional DLQ/retry and input_transformer
resource "aws_cloudwatch_event_target" "targets" {
  for_each       = { for t in local.targets : "${t.rule_name}-${t.target.target_id}" => t }
  rule           = aws_cloudwatch_event_rule.rules[each.value.rule_name].name
  event_bus_name = local.effective_bus_name
  target_id      = each.value.target.target_id

  # Choose ARN: prefer explicit arn; else resolve by function_name
  arn = coalesce(
    try(each.value.target.arn, null),
    try(
      length(lookup(each.value.target, "qualifier", "")) > 0 ?
        "${data.aws_lambda_function.by_name[each.value.target.function_name].arn}:${each.value.target.qualifier}" :
        data.aws_lambda_function.by_name[each.value.target.function_name].arn,
      null
    )
  )

  # Minimize what you pass to targets; prefer transformers over raw input
  dynamic "input_transformer" {
    for_each = contains(keys(each.value.target), "input_transformer") && each.value.target.input_transformer != null ? [1] : []
    content {
      input_paths    = lookup(each.value.target.input_transformer, "input_paths", null)
      input_template = each.value.target.input_transformer.input_template
    }
  }

  # Optional basic input or input_path (avoid using both with transformer)
  input      = lookup(each.value.target, "input", null)
  input_path = lookup(each.value.target, "input_path", null)

  # Optional DLQ and retry policy (recommended for reliability)
  dynamic "dead_letter_config" {
    for_each = lookup(each.value.target, "dlq_arn", null) != null ? [1] : []
    content {
      arn = each.value.target.dlq_arn
    }
  }

  dynamic "retry_policy" {
    for_each = lookup(each.value.target, "retry_policy", null) != null ? [1] : []
    content {
      maximum_event_age_in_seconds = lookup(each.value.target.retry_policy, "maximum_event_age_in_seconds", null)
      maximum_retry_attempts       = lookup(each.value.target.retry_policy, "maximum_retry_attempts", null)
    }
  }
}

# Allow EventBridge to invoke target Lambdas (only when target.type == "lambda")
resource "aws_lambda_permission" "allow_events" {
  for_each      = {
    for t in local.targets :
    "${t.rule_name}-${t.target.target_id}" => t
    if lower(lookup(t.target, "type", "lambda")) == "lambda"
  }

  statement_id  = "AllowExecutionFromEventBridge-${each.key}"
  action        = "lambda:InvokeFunction"
  function_name = coalesce(
    try(each.value.target.arn, null),
    try(
      length(lookup(each.value.target, "qualifier", "")) > 0 ?
        "${data.aws_lambda_function.by_name[each.value.target.function_name].arn}:${each.value.target.qualifier}" :
        data.aws_lambda_function.by_name[each.value.target.function_name].arn,
      null
    )
  )
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.rules[each.value.rule_name].arn
}

# Optional: strict bus permission policy (use only if cross-account is needed)
resource "aws_cloudwatch_event_bus_policy" "bus_policy" {
  count         = var.bus_policy_json == null ? 0 : 1
  event_bus_name = local.effective_bus_name
  policy         = var.bus_policy_json
}
