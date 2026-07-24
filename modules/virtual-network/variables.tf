# ---------------------------------------------------------------------------------------------------------------------
# REQUIRED PARAMETERS
# ---------------------------------------------------------------------------------------------------------------------

variable "name" {
  description = "Name of the virtual network."
  type        = string
}

variable "location" {
  description = "Azure region for the virtual network."
  type        = string
}

variable "resource_group_name" {
  description = "Name of an existing resource group."
  type        = string
}

variable "address_space" {
  description = "CIDR ranges assigned to the virtual network."
  type        = list(string)
  validation {
    condition     = length(var.address_space) > 0
    error_message = "address_space must contain at least one CIDR."

  }
}

variable "subnets" {
  description = "Subnets keyed by role. Azure subnets span availability zones."
  type = map(object({
    address_prefixes                = list(string)
    service_endpoints               = optional(list(string), [])
    default_outbound_access_enabled = optional(bool, false)
    delegation = optional(object({
      name         = optional(string, "service-delegation")
      service_name = string
      actions      = optional(list(string), [])
    }))
  }))
  validation {
    condition     = length(var.subnets) > 0 && alltrue([for subnet in values(var.subnets) : length(subnet.address_prefixes) > 0])
    error_message = "At least one subnet is required and every subnet needs an address prefix."

  }
}

# ---------------------------------------------------------------------------------------------------------------------
# OPTIONAL PARAMETERS
# ---------------------------------------------------------------------------------------------------------------------

variable "tags" {
  description = "Tags applied to all resources."
  type        = map(string)
  default     = {}
}
