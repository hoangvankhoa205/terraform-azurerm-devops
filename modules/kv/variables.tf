# ---------------------------------------------------------------------------------------------------------------------
# REQUIRED PARAMETERS
# ---------------------------------------------------------------------------------------------------------------------

variable "name" {
  description = "Globally unique Key Vault name."
  type        = string
  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9-]{1,22}[a-zA-Z0-9]$", var.name)) && !can(regex("--", var.name))
    error_message = "name must be 3-24 characters, alphanumeric or hyphen, start with a letter, end with a letter or digit, and contain no consecutive hyphens."
  }
}

variable "location" {
  description = "Azure region."
  type        = string
}

variable "resource_group_name" {
  description = "Existing resource group name."
  type        = string
}

variable "tenant_id" {
  description = "Microsoft Entra tenant ID."
  type        = string
}

# ---------------------------------------------------------------------------------------------------------------------
# OPTIONAL PARAMETERS
# ---------------------------------------------------------------------------------------------------------------------

variable "public_network_access_enabled" {
  description = "Expose the Key Vault public endpoint. When true, deny-by-default network_acls still apply."
  type        = bool
  default     = false
}

variable "network_acls" {
  description = "Deny-by-default vault exceptions for trusted deployment IPs or connected subnets."
  type = object({
    bypass                     = optional(string, "AzureServices")
    ip_rules                   = optional(set(string), [])
    virtual_network_subnet_ids = optional(set(string), [])
  })
  default = {}
  validation {
    condition     = contains(["AzureServices", "None"], var.network_acls.bypass)
    error_message = "network_acls.bypass must be AzureServices or None."
  }
}

variable "purge_protection_enabled" {
  description = "Block permanent deletion until the soft-delete window expires. IRREVERSIBLE — Azure does not allow turning this off once a vault has it, so a destroyed vault cannot be purged early and its globally unique name stays reserved for soft_delete_retention_days. Required by services that accept a customer-managed key. Set false only for throwaway vaults you expect to destroy and recreate under the same name."
  type        = bool
  default     = true
}

variable "soft_delete_retention_days" {
  description = "Days a deleted vault stays recoverable before it can be purged. With purge_protection_enabled the vault CANNOT be purged before this elapses, and the name is unusable for the whole window — so a long value is expensive in a destroy/recreate loop. Azure permits 7-90."
  type        = number
  default     = 7
  validation {
    condition     = var.soft_delete_retention_days >= 7 && var.soft_delete_retention_days <= 90
    error_message = "soft_delete_retention_days must be between 7 and 90."
  }
}

variable "tags" {
  description = "Resource tags."
  type        = map(string)
  default     = {}
}
