variable "event_bus_name" {
  description = "Name of the EventBridge bus to use. Use 'default' for the default bus."
  type        = string
  default     = "app-events"
}

variable "create_bus" {
  description = "Whether to create the event bus (ignored if event_bus_name == 'default')."
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags to apply to EventBridge rules."
  type        = map(string)
  default     = {}
}

variable "rules" {
  description = <<EOT
List of rules with targets. For each target you can provide either `arn` OR `function_name` (+ optional `qualifier`).
Optionally specify `input_transformer` to minimize payload, and DLQ/retry policy for reliability.
EOT
  type = list(object({
    name                = string
    description         = optional(string)
    event_pattern       = optional(any)
    schedule_expression = optional(string)
    state               = optional(string, "ENABLED")
    targets = list(object({
      target_id  = string
      type       = optional(string, "lambda")

      # One of the following:
      arn           = optional(string)
      function_name = optional(string)
      qualifier     = optional(string)

      # Safer ways to pass data
      input            = optional(string)
      input_path       = optional(string)
      input_transformer = optional(object({
        input_template = string
        input_paths    = optional(map(string))
      }))

      # Reliability
      dlq_arn      = optional(string)
      retry_policy = optional(object({
        maximum_event_age_in_seconds = optional(number)
        maximum_retry_attempts       = optional(number)
      }))
    }))
  }))
  default = []
}

variable "bus_policy_json" {
  description = "Optional JSON policy for the event bus (use for cross-account only; keep strict)."
  type        = string
  default     = null
}
