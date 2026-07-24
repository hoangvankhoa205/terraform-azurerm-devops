# ---------------------------------------------------------------------------------------------------------------------
# REQUIRED PARAMETERS
# ---------------------------------------------------------------------------------------------------------------------

variable "name" {
  description = "Front Door profile name."
  type        = string
}

variable "endpoint_name" {
  description = "Globally unique Front Door endpoint name."
  type        = string
}

variable "resource_group_name" {
  description = "Existing resource group name."
  type        = string
}

variable "origin_host_name" {
  description = "Static website origin host without a URL scheme."
  type        = string
  validation {
    condition     = !can(regex("^https?://", var.origin_host_name))
    error_message = "origin_host_name must not include a URL scheme."
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# OPTIONAL PARAMETERS
# ---------------------------------------------------------------------------------------------------------------------

variable "sku_name" {
  description = "Front Door Standard or Premium SKU."
  type        = string
  default     = "Standard_AzureFrontDoor"
  validation {
    condition     = contains(["Standard_AzureFrontDoor", "Premium_AzureFrontDoor"], var.sku_name)
    error_message = "Use Front Door Standard or Premium; Classic is retired."
  }
}

variable "tags" {
  description = "Resource tags."
  type        = map(string)
  default     = {}
}
