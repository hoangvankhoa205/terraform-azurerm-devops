# ---------------------------------------------------------------------------------------------------------------------
# REQUIRED PARAMETERS
# ---------------------------------------------------------------------------------------------------------------------

variable "name" {
  description = "Globally unique Key Vault name."
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

variable "tenant_id" {
  description = "Microsoft Entra tenant ID."
  type        = string
}

# ---------------------------------------------------------------------------------------------------------------------
# OPTIONAL PARAMETERS
# ---------------------------------------------------------------------------------------------------------------------

variable "key_name" {
  description = "Key name."
  type        = string
  default     = "learning-key"
}

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

variable "tags" {
  description = "Resource tags."
  type        = map(string)
  default     = {}
}
