output "certificate_id" {
  description = "Versioned certificate ID. Pins the version that existed at apply time."
  value       = azurerm_key_vault_certificate.this.id
}

output "versionless_id" {
  description = "Versionless certificate ID. Follows renewal rather than pinning a version."
  value       = azurerm_key_vault_certificate.this.versionless_id
}

# A certificate is stored twice: as a certificate object, and as a secret
# holding the PFX or PEM. Services that need the private key — Application
# Gateway, App Service — read the SECRET, not the certificate, which is a
# routine source of confusion when a listener rejects a perfectly good
# certificate ID.
output "secret_id" {
  description = "Versioned ID of the certificate's backing secret — the PFX or PEM. This, not certificate_id, is what an Application Gateway ssl_certificate block consumes."
  value       = azurerm_key_vault_certificate.this.secret_id
}

output "versionless_secret_id" {
  description = "Versionless ID of the backing secret. Prefer this in an Application Gateway: auto-renewal creates a new version, and a pinned secret_id keeps serving the old certificate until someone notices it expired."
  value       = azurerm_key_vault_certificate.this.versionless_secret_id
}

output "thumbprint" {
  description = "X.509 SHA-1 thumbprint, for matching what a client actually received against what the vault holds."
  value       = azurerm_key_vault_certificate.this.thumbprint
}
