# ---------------------------------------------------------------------------------------------------------------------
# REQUIRED PARAMETERS
# ---------------------------------------------------------------------------------------------------------------------

variable "key_vault_id" {
  description = "ID of an existing Key Vault, typically the key_vault_id output of the key-vault module. This module does not create a vault."
  type        = string
}

variable "name" {
  description = "Certificate name inside the vault."
  type        = string
  validation {
    condition     = can(regex("^[a-zA-Z0-9-]{1,127}$", var.name))
    error_message = "Certificate names must be 1-127 characters of letters, digits, or hyphens — no underscores or dots. Azure applies the same rule to keys and secrets."
  }
}

variable "subject" {
  description = "X.509 subject distinguished name, for example CN=example.com. Modern TLS clients ignore the common name and match on subject alternative names, so set dns_names too."
  type        = string
  validation {
    condition     = can(regex("CN=", var.subject))
    error_message = "subject must be a distinguished name containing a CN component, for example CN=example.com."
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# OPTIONAL PARAMETERS
# ---------------------------------------------------------------------------------------------------------------------

variable "dns_names" {
  description = "DNS subject alternative names. Browsers and Application Gateway health probes match on these, not on the subject CN, so a certificate without them will fail hostname verification even when the CN looks right. Empty omits the SAN block entirely."
  type        = set(string)
  default     = []
}

variable "issuer_name" {
  description = "Certificate issuer. 'Self' produces a self-signed certificate, which is what a learning environment wants and what no client will trust. 'Unknown' means the CSR is issued outside Terraform and merged in later. Any other value names a CA issuer already configured on the vault."
  type        = string
  default     = "Self"
}

variable "validity_in_months" {
  description = "Certificate lifetime in months."
  type        = number
  default     = 12
  validation {
    condition     = var.validity_in_months >= 1 && var.validity_in_months <= 120
    error_message = "validity_in_months must be between 1 and 120."
  }
}

variable "key_type" {
  description = "Key algorithm. RSA or EC only — the HSM-backed variants (RSA-HSM, EC-HSM) need a premium vault, and the key-vault module in this collection creates a standard one."
  type        = string
  default     = "RSA"
  validation {
    condition     = contains(["RSA", "EC"], var.key_type)
    error_message = "key_type must be RSA or EC. RSA-HSM and EC-HSM require a premium Key Vault SKU, which the key-vault module does not create."
  }
}

variable "key_size" {
  description = "RSA key size. Ignored when key_type is EC."
  type        = number
  default     = 2048
  validation {
    condition     = contains([2048, 3072, 4096], var.key_size)
    error_message = "key_size must be 2048, 3072, or 4096."
  }
}

variable "curve" {
  description = "Elliptic curve name. Ignored when key_type is RSA."
  type        = string
  default     = "P-256"
  validation {
    condition     = contains(["P-256", "P-256K", "P-384", "P-521"], var.curve)
    error_message = "curve must be P-256, P-256K, P-384, or P-521."
  }
}

variable "exportable" {
  description = "Whether the private key can be retrieved from the vault. Application Gateway and App Service read a certificate through its SECRET, which only works when the key is exportable — set false only when nothing needs to pull the PFX out."
  type        = bool
  default     = true
}

variable "reuse_key" {
  description = "Reuse the existing key material on renewal instead of generating a new key. False gives a fresh key each renewal, which is the safer default."
  type        = bool
  default     = false
}

variable "content_type" {
  description = "Format the certificate's backing secret is stored in. application/x-pkcs12 yields a PFX, which is what Application Gateway expects; application/x-pem-file yields PEM."
  type        = string
  default     = "application/x-pkcs12"
  validation {
    condition     = contains(["application/x-pkcs12", "application/x-pem-file"], var.content_type)
    error_message = "content_type must be application/x-pkcs12 or application/x-pem-file."
  }
}

variable "key_usage" {
  description = "X.509 key usage. Defaults to the pair a TLS server certificate actually needs. The provider's own example lists six including keyCertSign, which would let the certificate sign other certificates — deliberately not the default here."
  type        = set(string)
  default     = ["digitalSignature", "keyEncipherment"]
}

variable "extended_key_usage" {
  description = "Extended key usage OIDs. Defaults to serverAuth (1.3.6.1.5.5.7.3.1). Add clientAuth (1.3.6.1.5.5.7.3.2) for mutual TLS."
  type        = set(string)
  default     = ["1.3.6.1.5.5.7.3.1"]
}

variable "auto_renew" {
  description = "Have Key Vault reissue the certificate before it expires. Renewal produces a new version; consumers that reference the versionless secret ID pick it up, consumers pinned to a version do not."
  type        = bool
  default     = true
}

variable "renew_days_before_expiry" {
  description = "How many days before expiry auto-renewal fires. Ignored when auto_renew is false."
  type        = number
  default     = 30
  validation {
    condition     = var.renew_days_before_expiry >= 1 && var.renew_days_before_expiry <= 972
    error_message = "renew_days_before_expiry must be between 1 and 972."
  }
}

variable "tags" {
  description = "Resource tags."
  type        = map(string)
  default     = {}
}
