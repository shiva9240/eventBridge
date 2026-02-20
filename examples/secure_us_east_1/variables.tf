variable "region" {
  type    = string
  default = "us-east-1"
}

variable "event_bus_name" {
  type    = string
  default = "app-events"
}

variable "create_bus" {
  type    = bool
  default = true
}

variable "orders_lambda_name_param" {
  type    = string
  default = "/dev/lambda/orders_processor_name"
}

variable "dlq_arn" {
  type    = string
  default = null
}

variable "tags" {
  type = map(string)
  default = {
    owner   = "shiva"
    purpose = "manual-test"
  }
}
