output "identity_id" {
  description = "User-assigned managed identity ID."
  value       = azurerm_user_assigned_identity.this.id
}

output "client_id" {
  description = "Client ID used by Azure Login."
  value       = azurerm_user_assigned_identity.this.client_id
}

output "principal_id" {
  description = "Principal ID used for Azure role assignments."
  value       = azurerm_user_assigned_identity.this.principal_id
}

output "tenant_id" {
  description = "Microsoft Entra tenant ID used by Azure Login."
  value       = azurerm_user_assigned_identity.this.tenant_id
}
