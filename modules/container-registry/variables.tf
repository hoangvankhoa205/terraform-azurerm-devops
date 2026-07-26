# ---------------------------------------------------------------------------------------------------------------------
# REQUIRED PARAMETERS
# ---------------------------------------------------------------------------------------------------------------------

variable "name" {
  description = "Globally unique registry name. Alphanumeric only — no hyphens, unlike almost every other Azure resource name, which is a common first-apply failure. It becomes the <name>.azurecr.io login server, so it has to be unique across all of Azure."
  type        = string
  validation {
    condition     = can(regex("^[a-zA-Z0-9]{5,50}$", var.name))
    error_message = "name must contain 5-50 alphanumeric characters, with no hyphens or underscores."
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

variable "sku" {
  description = "Registry tier. Basic and Standard differ only in included storage and throughput. Premium is the one that changes what is possible: it is required for Private Endpoints, geo-replication, customer-managed keys, and content trust. Leaving public_network_access_enabled false on a Basic registry therefore produces a registry nothing can reach."
  type        = string
  default     = "Basic"
  validation {
    condition     = contains(["Basic", "Standard", "Premium"], var.sku)
    error_message = "sku must be Basic, Standard, or Premium."
  }
}

variable "public_network_access_enabled" {
  description = "Allow the public data endpoint. Disabled by default. Reaching a private registry needs a Private Endpoint and a privatelink.azurecr.io DNS zone, neither of which this module creates, and both of which need the Premium SKU."
  type        = bool
  default     = false
}

variable "tags" {
  description = "Resource tags."
  type        = map(string)
  default     = {}
}
