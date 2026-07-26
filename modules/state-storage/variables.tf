# ---------------------------------------------------------------------------------------------------------------------
# REQUIRED PARAMETERS
# ---------------------------------------------------------------------------------------------------------------------

variable "name" {
  description = "Globally unique storage account name. Lowercase letters and digits only — no hyphens, which is a common first-apply failure."
  type        = string
  validation {
    condition     = can(regex("^[a-z0-9]{3,24}$", var.name))
    error_message = "name must be 3-24 lowercase alphanumeric characters, with no hyphens or underscores."
  }
}

variable "location" {
  description = "Azure region."
  type        = string
}

variable "resource_group_name" {
  description = "Existing bootstrap resource group name."
  type        = string
}

# ---------------------------------------------------------------------------------------------------------------------
# OPTIONAL PARAMETERS
# ---------------------------------------------------------------------------------------------------------------------

variable "container_name" {
  description = "Container the state blobs live in. One container holds many workspaces, separated by the backend's `key`, so there is rarely a reason to change this."
  type        = string
  default     = "tfstate"
}

variable "replication_type" {
  description = "Replication mode. ZRS keeps three copies across availability zones in the region and is the right default for state — losing state is far more expensive than the small premium over LRS. GRS adds a second region, but its secondary is only readable after a failover."
  type        = string
  default     = "ZRS"
}

variable "public_network_access_enabled" {
  description = "Expose the storage public endpoint. When true, deny-by-default network_rules still apply."
  type        = bool
  default     = false
}

variable "network_rules" {
  description = "Deny-by-default state storage exceptions for trusted runner IPs or connected subnets."
  type = object({
    bypass                     = optional(set(string), ["AzureServices"])
    ip_rules                   = optional(set(string), [])
    virtual_network_subnet_ids = optional(set(string), [])
  })
  default = {}
  validation {
    condition = (
      alltrue([
        for value in var.network_rules.bypass :
        contains(["AzureServices", "Logging", "Metrics", "None"], value)
      ]) &&
      !(contains(var.network_rules.bypass, "None") && length(var.network_rules.bypass) > 1)
    )
    error_message = "network_rules.bypass supports AzureServices, Logging, Metrics, or None; None cannot be combined with another value."
  }
}

variable "retention_days" {
  description = "How long a deleted state blob stays recoverable. Combined with versioning, this is the undo button for a corrupted apply. Azure permits 7-365."
  type        = number
  default     = 14
  validation {
    condition     = var.retention_days >= 7 && var.retention_days <= 365
    error_message = "retention_days must be between 7 and 365."
  }
}

variable "tags" {
  description = "Resource tags."
  type        = map(string)
  default     = {}
}
