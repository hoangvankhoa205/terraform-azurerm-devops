# ---------------------------------------------------------------------------------------------------------------------
# REQUIRED PARAMETERS
# ---------------------------------------------------------------------------------------------------------------------

variable "principal_id" {
  description = "Managed identity principal ID."
  type        = string
}

variable "assignments" {
  description = "Narrow Azure RBAC assignments keyed by a stable label."
  type = map(object({
    scope                = string
    role_definition_name = string
  }))
  validation {
    condition     = length(var.assignments) > 0 && alltrue([for item in values(var.assignments) : item.role_definition_name != "Owner"])
    error_message = "At least one assignment is required and the broad Owner role is not allowed by this learning module."
  }
}
