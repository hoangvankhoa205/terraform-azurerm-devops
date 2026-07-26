# Deliberately no output for the administrator password. The caller already has
# it, and returning it would copy it into every consumer's state as well.

output "server_id" {
  description = "PostgreSQL Flexible Server resource ID."
  value       = azurerm_postgresql_flexible_server.this.id
}

output "fqdn" {
  description = "Private FQDN clients connect to. It resolves only through the private DNS zone supplied to this module, so a client outside the VNet gets no answer rather than a refused connection."
  value       = azurerm_postgresql_flexible_server.this.fqdn
}
