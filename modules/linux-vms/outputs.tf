# Every output is a map keyed by the same logical name used in var.instances, so
# a caller can look a VM up with the key they declared it with.

output "ids" {
  description = "Virtual machine resource IDs keyed by logical name."
  value       = { for key, vm in azurerm_linux_virtual_machine.this : key => vm.id }
}

output "private_ip_addresses" {
  description = "Private addresses keyed by logical name. These are the only addresses these VMs have; there is no public IP."
  value       = { for key, nic in azurerm_network_interface.this : key => nic.private_ip_address }
}

output "principal_ids" {
  description = "System-assigned identity principal IDs keyed by logical name. Grant Azure roles to these so each VM can reach Key Vault, Storage, or a registry without a stored credential."
  value       = { for key, vm in azurerm_linux_virtual_machine.this : key => vm.identity[0].principal_id }
}
