# ---------------------------------------------------------------------------------------------------------------------
# REQUIRED PARAMETERS
# ---------------------------------------------------------------------------------------------------------------------

variable "key_vault_id" {
  description = "ID of an existing Key Vault, typically the key_vault_id output of the key-vault module. This module does not create a vault, so one vault can hold secrets, keys and certificates together."
  type        = string
}

# Metadata and values are split across two variables on purpose, and the reason
# is a hard Terraform constraint rather than taste.
#
# for_each cannot take a sensitive value, or anything derived from one. The
# moment a caller passes something like random_password.admin.result into a map,
# that whole map becomes sensitive and `for_each = var.<map>` fails with
# "Sensitive values ... cannot be used as for_each arguments". Since passing a
# generated password is the main reason to use this module, a single combined
# map would break in exactly the case it exists for.
#
# So: secrets carries the names and metadata and drives for_each, staying
# non-sensitive; secret_values carries the values and is marked sensitive.
variable "secrets" {
  description = "Secrets to create, keyed by secret name. Values live in secret_values under the same keys — see that variable for why they are separate."
  type = map(object({
    content_type    = optional(string)
    expiration_date = optional(string)
    not_before_date = optional(string)
    tags            = optional(map(string), {})
  }))
  validation {
    condition     = alltrue([for name in keys(var.secrets) : can(regex("^[a-zA-Z0-9-]{1,127}$", name))])
    error_message = "Secret names must be 1-127 characters of letters, digits, or hyphens."
  }
}

variable "secret_values" {
  description = "Secret values, keyed to match secrets. Marked sensitive so plan output and console never print them — but note the values still land in Terraform state in cleartext. Key Vault does not change that; protect the state file (remote backend, Entra-only access) or keep the value out of Terraform entirely."
  type        = map(string)
  sensitive   = true
}

# ---------------------------------------------------------------------------------------------------------------------
# OPTIONAL PARAMETERS
# ---------------------------------------------------------------------------------------------------------------------

variable "tags" {
  description = "Tags applied to every secret, merged under each secret's own tags."
  type        = map(string)
  default     = {}
}
