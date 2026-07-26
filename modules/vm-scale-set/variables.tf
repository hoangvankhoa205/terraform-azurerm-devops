# ---------------------------------------------------------------------------------------------------------------------
# REQUIRED PARAMETERS
# ---------------------------------------------------------------------------------------------------------------------

variable "name" {
  description = "Scale set name. Instance computer names are derived from it by Azure."
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
  description = "Subnet every instance joins. Take this from virtual-network's subnet_ids output, and size the subnet for the highest instance count you expect — a scale set that cannot allocate addresses fails to scale out."
  type        = string
}

variable "ssh_public_key" {
  description = "OpenSSH public key shared by every instance. Pass the contents of a .pub file, never the private key. Password login is disabled, so this is the only way onto an instance."
  type        = string
  sensitive   = true
  validation {
    # Also the guard against pasting a private key: an OpenSSH private key
    # begins "-----BEGIN", so requiring a public-key algorithm prefix rejects it.
    condition     = can(regex("^(ssh-ed25519|ssh-rsa|ecdsa-sha2-nistp(256|384|521)|sk-ssh-ed25519@openssh\\.com) ", var.ssh_public_key))
    error_message = "ssh_public_key must be an OpenSSH public key beginning with ssh-ed25519, ssh-rsa, or ecdsa-sha2-nistp256/384/521. Pass the .pub file contents, never the private key."
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# OPTIONAL PARAMETERS
# ---------------------------------------------------------------------------------------------------------------------

variable "admin_username" {
  description = "Local administrator username on every instance. Azure rejects a list of reserved names (root, admin, administrator and similar) at create time, so a typo here fails the apply rather than the boot."
  type        = string
  default     = "azureuser"
  validation {
    condition = (
      can(regex("^[a-z_][a-z0-9_-]{0,31}$", var.admin_username)) &&
      !contains(["root", "admin", "administrator", "adm", "backup", "console", "guest", "owner", "server", "support", "sys", "test", "user"], var.admin_username)
    )
    error_message = "admin_username must be a lowercase Linux username of at most 32 characters and must not be one of the names Azure reserves (root, admin, administrator, guest, test, user and similar)."
  }
}

variable "sku" {
  description = "Azure VM size for every instance, such as Standard_B2s or Standard_D2s_v3. Burstable B-series is cheapest for a lab; check the size is available in your region and zones before relying on it."
  type        = string
  default     = "Standard_B2s"
}

variable "instances" {
  description = "Fixed instance count. This module ships no autoscale rules, so the count only changes when you change it here. Scaling out needs spare addresses in the subnet."
  type        = number
  default     = 2
  validation {
    condition     = var.instances >= 1
    error_message = "instances must be at least one."
  }
}

variable "zones" {
  description = "Availability zones to spread instances across. Empty is both the default and correct in regions that have no zones — a zone list Azure does not recognise fails the apply."
  type        = list(string)
  default     = []
}

variable "custom_data" {
  description = "Optional cloud-init text, passed as plain text. The module base64-encodes it, so encoding it yourself first produces instances that boot and silently ignore the configuration. With Manual upgrade mode, changing this affects new instances only until existing ones are rolled."
  type        = string
  default     = null
  sensitive   = true
}

variable "tags" {
  description = "Resource tags."
  type        = map(string)
  default     = {}
}
