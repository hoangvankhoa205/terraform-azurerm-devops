output "vm_id" {
  description = "Virtual machine resource ID."
  value       = azurerm_linux_virtual_machine.this.id
}

output "private_ip_address" {
  description = "Private address on the workload subnet. This is how to reach the VM from a bastion, a VPN, or a peered network."
  value       = azurerm_network_interface.this.private_ip_address
}

output "network_interface_id" {
  description = "Network interface resource ID, for attaching a load balancer backend pool or an application security group."
  value       = azurerm_network_interface.this.id
}

# Both public IP outputs are count-dependent. one() collapses the empty list to
# null, so a caller can reference them unconditionally rather than guarding on
# public_ip_enabled themselves.
output "public_ip_id" {
  description = "Public IP resource ID when public_ip_enabled is true; otherwise null."
  value       = one(azurerm_public_ip.this[*].id)
}

output "public_ip_address" {
  description = "Allocated public IPv4 address when public_ip_enabled is true; otherwise null. Reaching it still needs an inbound NSG rule, which this module does not create."
  value       = one(azurerm_public_ip.this[*].ip_address)
}

output "principal_id" {
  description = "System-assigned identity principal ID. Grant Azure roles to this so the VM can reach Key Vault, Storage, or a registry without a stored credential."
  value       = azurerm_linux_virtual_machine.this.identity[0].principal_id
}
