output "ids" {
  description = "VM IDs keyed by logical name."
  value = { for key, vm in azurerm_linux_virtual_machine.this : key => vm.id
  }
}
output "private_ip_addresses" {
  description = "Private IPs keyed by logical name."
  value = { for key, nic in azurerm_network_interface.this : key => nic.private_ip_address
  }
}
output "principal_ids" {
  description = "Managed identity principal IDs keyed by name."
  value = { for key, vm in azurerm_linux_virtual_machine.this : key => vm.identity[0].principal_id
  }
}

