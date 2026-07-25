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
  # Azure permits only alphanumerics and hyphens here — db_password is invalid,
  # db-password is fine. Catching it at plan time beats a 400 partway through
  # an apply.
  validation {
    condition     = alltrue([for name in keys(var.secrets) : can(regex("^[a-zA-Z0-9-]{1,127}$", name))])
    error_message = "Secret names must be 1-127 characters of letters, digits, or hyphens — no underscores or dots. Use db-password, not db_password."
  }

  # Without this, a name with no matching value fails deep in the resource as
  # "Invalid index" on var.secret_values[each.key] — which does not say which
  # variable is wrong or which key is missing, and cannot be asserted on in a
  # test because expect_failures only catches checkable objects.
  #
  # nonsensitive() is safe here and always valid: secret_values is declared
  # sensitive, so the value is unconditionally marked, and only the KEYS are
  # unwrapped. Secret names are already public — they are the keys of this very
  # variable. No value is exposed.
  validation {
    condition = alltrue([
      for name in keys(var.secrets) : contains(nonsensitive(keys(var.secret_values)), name)
    ])
    error_message = "Every key in secrets needs a value under the same key in secret_values."
  }
}

variable "secret_values" {
  description = "Secret values, keyed to match secrets. Marked sensitive so plan output and console never print them — but note the values still land in Terraform state in cleartext. Key Vault does not change that; protect the state file (remote backend, Entra-only access) or keep the value out of Terraform entirely."
  type        = map(string)
  sensitive   = true

  # The mirror of the check on var.secrets. An orphaned value is almost always
  # a typo in one of the two maps — silently ignoring it would create the wrong
  # secret and skip the intended one.
  validation {
    condition = alltrue([
      for name in nonsensitive(keys(var.secret_values)) : contains(keys(var.secrets), name)
    ])
    error_message = "Every key in secret_values must have a matching entry in secrets, otherwise the value is silently ignored."
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# OPTIONAL PARAMETERS
# ---------------------------------------------------------------------------------------------------------------------

variable "tags" {
  description = "Tags applied to every secret, merged under each secret's own tags."
  type        = map(string)
  default     = {}
}
