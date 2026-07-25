output "key_vault_id" {
  description = "Key Vault ID."
  value       = azurerm_key_vault.this.id
}
output "key_id" {
  description = "Versioned Key Vault key ID."
  value       = azurerm_key_vault_key.this.id
}
output "key_versionless_id" {
  description = "Versionless key ID for services that track rotation."
  value       = azurerm_key_vault_key.this.versionless_id
}

