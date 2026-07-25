output "storage_account_id" {
  description = "Storage account ID."
  value       = azurerm_storage_account.this.id
}
output "primary_web_host" {
  description = "Static website origin hostname."
  value       = azurerm_storage_account.this.primary_web_host
}
output "primary_web_endpoint" {
  description = "Static website HTTPS endpoint."
  value       = azurerm_storage_account.this.primary_web_endpoint
}

