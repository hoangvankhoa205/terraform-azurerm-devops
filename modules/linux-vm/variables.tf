# ---------------------------------------------------------------------------------------------------------------------
# REQUIRED PARAMETERS
# ---------------------------------------------------------------------------------------------------------------------

variable "name" {
  description = "VM name."
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
  description = "ID of the subnet for the private NIC."
  type        = string
}

variable "ssh_public_key" {
  description = "OpenSSH public key; private keys are never accepted."
  type        = string
  sensitive   = true
}

# ---------------------------------------------------------------------------------------------------------------------
# OPTIONAL PARAMETERS
# ---------------------------------------------------------------------------------------------------------------------

variable "public_ip_enabled" {
  description = "Create and attach a Standard static public IPv4 address. This does not create an inbound NSG rule. Intended for explicit, short-lived tests."
  type        = bool
  default     = false
}

variable "admin_username" {
  description = "Local administrator username."
  type        = string
  default     = "azureuser"
}

variable "size" {
  description = "Azure VM SKU. Defaults to a general-purpose x86 size with broad regional capacity; override for cheaper burstable SKUs (e.g. Standard_B1s/B2s) where your region and subscription have capacity."
  type        = string
  default     = "Standard_D2s_v3"
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
