# ---------------------------------------------------------------------------------------------------------------------
# REQUIRED PARAMETERS
# ---------------------------------------------------------------------------------------------------------------------

variable "name" {
  description = "Virtual network name. Also prefixes every generated network security group name, as <name>-<subnet key>-nsg."
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

variable "address_space" {
  description = "CIDR ranges assigned to the virtual network. Every subnet prefix must fall inside one of these. Adding a range later is non-disruptive; shrinking one that subnets already occupy is not."
  type        = list(string)
  validation {
    condition     = length(var.address_space) > 0
    error_message = "address_space must contain at least one CIDR."
  }
}

variable "subnets" {
  description = "Subnets keyed by role, such as workload_private or data_private. The key becomes the subnet name with underscores rewritten to hyphens, and is the key of every map this module outputs — so renaming a key replaces the subnet. Azure subnets are regional and span all availability zones in the region, so a role name describes what runs there rather than where it sits; there is no AWS-style public and private subnet per zone."
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
  description = "Resource tags. Applied to the virtual network and to every generated network security group."
  type        = map(string)
  default     = {}
}
