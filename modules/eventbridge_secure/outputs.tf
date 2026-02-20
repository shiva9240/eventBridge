output "event_bus_name" {
  value       = local.effective_bus_name
  description = "Effective event bus name used by rules/targets."
}

output "rule_arns" {
  value       = { for k, v in aws_cloudwatch_event_rule.rules : k => v.arn }
  description = "ARNs of all created rules."
}
