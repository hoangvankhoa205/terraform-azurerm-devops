# ---------------------------------------------------------------------------------------------------------------------
# REQUIRED PARAMETERS
# ---------------------------------------------------------------------------------------------------------------------

variable "name" {
  description = "Managed identity name."
  type        = string
}

variable "location" {
  description = "Azure region."
  type        = string
}

variable "resource_group_name" {
  description = "Existing resource group name."
  type        = string
}

variable "subject" {
  description = "Exact GitHub OIDC subject, such as repo:owner/repository:environment:dev."
  type        = string
  validation {
    condition     = can(regex("^repo:[^/]+/[^:]+:(environment:[^:]+|ref:refs/(heads|tags)/.+|pull_request)$", var.subject))
    error_message = "subject must be an exact GitHub repository environment, ref, or pull_request subject."
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# OPTIONAL PARAMETERS
# ---------------------------------------------------------------------------------------------------------------------

variable "credential_name" {
  description = "Federated credential name."
  type        = string
  default     = "github-actions"
}

variable "audiences" {
  description = "OIDC audiences."
  type        = list(string)
  default     = ["api://AzureADTokenExchange"]
}

variable "tags" {
  description = "Resource tags."
  type        = map(string)
  default     = {}
}
