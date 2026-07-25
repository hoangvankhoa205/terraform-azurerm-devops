# ---------------------------------------------------------------------------------------------------------------------
# REQUIRED PARAMETERS
# ---------------------------------------------------------------------------------------------------------------------

variable "url" {
  description = "HTTP(S) URL to test."
  type        = string
  validation {
    condition     = can(regex("^https?://", var.url))
    error_message = "url must start with http:// or https://."
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# OPTIONAL PARAMETERS
# ---------------------------------------------------------------------------------------------------------------------

variable "expected_status" {
  description = "Expected HTTP status code."
  type        = number
  default     = 200
}

variable "request_headers" {
  description = "Optional request headers; do not put long-lived secrets in configuration."
  type        = map(string)
  default     = {}
}

variable "timeout_ms" {
  description = "Request timeout in milliseconds."
  type        = number
  default     = 5000
  validation {
    condition     = var.timeout_ms > 0
    error_message = "timeout_ms must be positive."
  }
}
