output "storage_account_id" {
  description = "State storage account resource ID. Grant Storage Blob Data Contributor at this scope to whatever principal runs Terraform, since shared-key auth is disabled."
  value       = azurerm_storage_account.this.id
}

output "storage_account_name" {
  description = "State storage account name."
  value       = azurerm_storage_account.this.name
}

output "container_name" {
  description = "State container name."
  value       = azurerm_storage_container.this.name
}

# Carries no secret: shared-key auth is disabled on the account, so there is no
# access key for a backend block to hold. Authentication comes from Entra ID —
# `use_azuread_auth = true`, plus OIDC or a logged-in az CLI.
output "backend_example" {
  description = "The non-secret values an azurerm backend block needs, ready to paste. Resource group is included for convenience. A backend cannot be configured by a module, so this is a starting point for the root configuration rather than something applied here."
  value = {
    resource_group_name  = var.resource_group_name
    storage_account_name = azurerm_storage_account.this.name
    container_name       = azurerm_storage_container.this.name
  }
}
