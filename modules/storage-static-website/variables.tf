# ---------------------------------------------------------------------------------------------------------------------
# REQUIRED PARAMETERS
# ---------------------------------------------------------------------------------------------------------------------

variable "name" {
  description = "Globally unique storage account name."
  type        = string
  validation {
    condition     = can(regex("^[a-z0-9]{3,24}$", var.name))
    error_message = "name must be 3-24 lowercase alphanumeric characters."
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

# ---------------------------------------------------------------------------------------------------------------------
# OPTIONAL PARAMETERS
# ---------------------------------------------------------------------------------------------------------------------

variable "index_document" {
  description = "Default page filename."
  type        = string
  default     = "index.html"
}

variable "error_404_document" {
  description = "404 page filename."
  type        = string
  default     = "404.html"
}

variable "public_network_access_enabled" {
  description = "Expose the static website public endpoint. When true, deny-by-default network_rules still apply."
  type        = bool
  default     = false
}

variable "network_rules" {
  description = "Deny-by-default static website exceptions for trusted client IPs or connected subnets."
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

variable "tags" {
  description = "Resource tags."
  type        = map(string)
  default     = {}
}
