# ---------------------------------------------------------------------------------------------------------------------
# REQUIRED PARAMETERS
# ---------------------------------------------------------------------------------------------------------------------

variable "name" {
  description = "Scale set name."
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

variable "subnet_id" {
  description = "Private workload subnet ID."
  type        = string
}

variable "ssh_public_key" {
  description = "OpenSSH public key."
  type        = string
  sensitive   = true
}

# ---------------------------------------------------------------------------------------------------------------------
# OPTIONAL PARAMETERS
# ---------------------------------------------------------------------------------------------------------------------

variable "admin_username" {
  description = "Local administrator username."
  type        = string
  default     = "azureuser"
}

variable "sku" {
  description = "VM SKU."
  type        = string
  default     = "Standard_B2s"
}

variable "instances" {
  description = "Desired instance count."
  type        = number
  default     = 2
  validation {
    condition     = var.instances >= 1
    error_message = "instances must be at least one."
  }
}

variable "zones" {
  description = "Availability zones; empty is allowed in regions without zones."
  type        = list(string)
  default     = []
}

variable "custom_data" {
  description = "Optional cloud-init text."
  type        = string
  default     = null
  sensitive   = true
}

variable "tags" {
  description = "Resource tags."
  type        = map(string)
  default     = {}
}
