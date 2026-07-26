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
  description = "Exact GitHub OIDC subject, such as repo:owner/repository:environment:dev. Entra matches this string literally against the token GitHub presents, so it must name one environment, one ref, or pull_request — anything broader hands every workflow in the repository the same Azure access."
  type        = string
  validation {
    condition = (
      can(regex("^repo:[^/]+/[^:]+:(environment:[^:]+|ref:refs/(heads|tags)/.+|pull_request)$", var.subject)) &&
      # The pattern above would otherwise accept "environment:*", because an
      # asterisk is not a colon. A standard federated credential matches the
      # subject literally, so a wildcard silently never matches anything.
      !can(regex("\\*", var.subject))
    )
    error_message = "subject must be an exact GitHub repository environment, ref, or pull_request subject, with no wildcards."
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
  description = "OIDC audience the token must carry. Entra ID expects api://AzureADTokenExchange and there is rarely a reason to change it. Kept as a list because that is the shape the provider takes, but Azure accepts only one entry."
  type        = list(string)
  default     = ["api://AzureADTokenExchange"]
  validation {
    # The provider rejects a second entry with "Attribute audience supports 1
    # item maximum", which surfaces as a confusing plan-time error rather than
    # pointing at the variable. Catching it here names the actual problem.
    condition     = length(var.audiences) == 1
    error_message = "audiences must contain exactly one entry; Azure federated credentials accept a single audience."
  }
}

variable "tags" {
  description = "Resource tags."
  type        = map(string)
  default     = {}
}
