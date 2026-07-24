output "storage_account_id" {
  description = "State storage account ID."
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
output "backend_example" {
  description = "Non-secret values used by an azurerm backend. Resource group is included for convenience."
  value = {
    resource_group_name  = var.resource_group_name
    storage_account_name = azurerm_storage_account.this.name
    container_name       = azurerm_storage_container.this.name

  }
}

