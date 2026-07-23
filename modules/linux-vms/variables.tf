# ---------------------------------------------------------------------------------------------------------------------
# REQUIRED PARAMETERS
# ---------------------------------------------------------------------------------------------------------------------

variable "location" {
  description = "Azure region."
  type        = string
}

variable "resource_group_name" {
  description = "Existing resource group name."
  type        = string
}

variable "ssh_public_key" {
  description = "Shared OpenSSH public key."
  type        = string
  sensitive   = true
}

variable "instances" {
  description = "VM definitions keyed by stable logical name."
  type = map(object({
    subnet_id      = string
    size           = optional(string, "Standard_D2s_v3")
    admin_username = optional(string, "azureuser")
    custom_data    = optional(string)
  }))
  validation {
    condition     = length(var.instances) > 0
    error_message = "instances must contain at least one VM."

  }
}

# ---------------------------------------------------------------------------------------------------------------------
# OPTIONAL PARAMETERS
# ---------------------------------------------------------------------------------------------------------------------

variable "tags" {
  description = "Resource tags."
  type        = map(string)
  default     = {}
}
