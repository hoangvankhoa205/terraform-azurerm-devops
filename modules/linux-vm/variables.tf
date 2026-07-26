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
  description = "OpenSSH public key; private keys are never accepted. Pass the contents of a .pub file, e.g. file(\"~/.ssh/id_ed25519.pub\") — not the matching private key. There is no password login to fall back on, so a key you cannot use means a VM you cannot reach."
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

variable "public_ip_enabled" {
  description = "Create and attach a Standard static public IPv4 address. This does not create an inbound NSG rule. Intended for explicit, short-lived tests."
  type        = bool
  default     = false
}

variable "admin_username" {
  description = "Local administrator username. Azure rejects a list of reserved names (root, admin, administrator and similar) at create time, so a typo here fails the apply rather than the boot."
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
