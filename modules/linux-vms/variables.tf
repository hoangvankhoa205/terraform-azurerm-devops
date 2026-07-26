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
  description = "OpenSSH public key shared by every VM in the map. Pass the contents of a .pub file, never the private key. Password login is disabled, so this is the only way in."
  type        = string
  sensitive   = true
  validation {
    # Also the guard against pasting a private key: an OpenSSH private key
    # begins "-----BEGIN", so requiring a public-key algorithm prefix rejects it.
    condition     = can(regex("^(ssh-ed25519|ssh-rsa|ecdsa-sha2-nistp(256|384|521)|sk-ssh-ed25519@openssh\\.com) ", var.ssh_public_key))
    error_message = "ssh_public_key must be an OpenSSH public key beginning with ssh-ed25519, ssh-rsa, or ecdsa-sha2-nistp256/384/521. Pass the .pub file contents, never the private key."
  }
}

variable "instances" {
  description = "VM definitions keyed by stable logical name. The key becomes the VM name and its NIC name, so renaming a key destroys and recreates that VM — choose keys you can live with."
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
  validation {
    condition = alltrue([
      for instance in values(var.instances) : (
        can(regex("^[a-z_][a-z0-9_-]{0,31}$", instance.admin_username)) &&
        !contains(["root", "admin", "administrator", "adm", "backup", "console", "guest", "owner", "server", "support", "sys", "test", "user"], instance.admin_username)
      )
    ])
    error_message = "Every instance admin_username must be a lowercase Linux username of at most 32 characters and must not be one of the names Azure reserves (root, admin, administrator, guest, test, user and similar)."
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
