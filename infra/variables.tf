variable "name" {
  description = "Prefix for every resource name"
  type        = string
  default     = "aws-cicd-showcase"
}

variable "region" {
  type    = string
  default = "us-east-1"
}

variable "azs" {
  description = "Two availability zones in the region (listed here so planning needs no AWS calls)"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "image_tag" {
  description = "Image tag to run (the git SHA in CI). Required: there is deliberately no default like \"latest\"."
  type        = string
}

variable "desired_count" {
  type    = number
  default = 2
}

variable "min_count" {
  type    = number
  default = 2
}

variable "max_count" {
  type    = number
  default = 4
}

variable "alert_email" {
  description = "If set, unhealthy-target alarms are emailed here (the subscription must be confirmed from the inbox)"
  type        = string
  default     = ""
}

variable "offline" {
  description = "Skip all AWS API calls (credential-free plan for CI checks)"
  type        = bool
  default     = false
}
