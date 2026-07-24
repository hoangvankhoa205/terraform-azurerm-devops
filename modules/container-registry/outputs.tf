output "id" {
  description = "Registry ID."
  value       = azurerm_container_registry.this.id
}
output "login_server" {
  description = "Registry login hostname."
  value       = azurerm_container_registry.this.login_server
}

