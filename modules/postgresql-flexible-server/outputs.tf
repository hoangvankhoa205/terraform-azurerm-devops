output "id" {
  description = "PostgreSQL server ID."
  value       = azurerm_postgresql_flexible_server.this.id
}
output "fqdn" {
  description = "Private PostgreSQL server FQDN."
  value       = azurerm_postgresql_flexible_server.this.fqdn
}

