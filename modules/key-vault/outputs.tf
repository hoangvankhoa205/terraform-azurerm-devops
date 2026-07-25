output "key_vault_id" {
  description = "Key Vault ID. Pass this to key-vault-secret, or to any azurerm_key_vault_key / _secret / _certificate the caller manages directly."
  value       = azurerm_key_vault.this.id
}
output "vault_uri" {
  description = "Data-plane URI, https://<name>.vault.azure.net/. What an application or the Secrets Store CSI driver talks to."
  value       = azurerm_key_vault.this.vault_uri
}
output "name" {
  description = "Vault name, for az CLI calls that take --vault-name rather than an ID."
  value       = azurerm_key_vault.this.name
}
