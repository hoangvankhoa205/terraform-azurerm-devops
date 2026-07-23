output "id" {
  description = "VM resource ID."
  value       = azurerm_linux_virtual_machine.this.id
}
output "private_ip_address" {
  description = "Private NIC address."
  value       = azurerm_network_interface.this.private_ip_address
}
output "network_interface_id" {
  description = "Network interface resource ID."
  value       = azurerm_network_interface.this.id
}
output "public_ip_id" {
  description = "Public IP resource ID when public_ip_enabled is true; otherwise null."
  value       = one(azurerm_public_ip.this[*].id)
}
output "public_ip_address" {
  description = "Allocated public IPv4 address when public_ip_enabled is true; otherwise null."
  value       = one(azurerm_public_ip.this[*].ip_address)
}
output "principal_id" {
  description = "System-assigned identity principal ID."
  value       = azurerm_linux_virtual_machine.this.identity[0].principal_id
}
