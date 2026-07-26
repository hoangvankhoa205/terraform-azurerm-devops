# Deliberately no output for the values. Reading a secret back out of Terraform
# defeats the point of putting it in a vault — consumers should fetch it from
# the vault at runtime, not receive it through a module output.
output "secret_ids" {
  description = "Versioned secret IDs, keyed by secret name. Pins the version that existed at apply time."
  value       = { for name, secret in azurerm_key_vault_secret.this : name => secret.id }
}
output "secret_versionless_ids" {
  description = "Versionless secret IDs, keyed by secret name. Use these where a consumer should follow rotation rather than pin a version."
  value       = { for name, secret in azurerm_key_vault_secret.this : name => secret.versionless_id }
}
output "secret_names" {
  description = "Names of the secrets created, for az CLI calls that take --name."
  value       = keys(azurerm_key_vault_secret.this)
}
