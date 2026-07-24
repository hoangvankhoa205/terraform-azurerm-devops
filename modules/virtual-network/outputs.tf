output "vnet_id" {
  description = "ID of the virtual network."
  value       = azurerm_virtual_network.this.id
}

output "vnet_name" {
  description = "Name of the virtual network."
  value       = azurerm_virtual_network.this.name
}

output "subnet_ids" {
  description = "Subnet IDs keyed by the supplied role names."
  value = { for key, subnet in azurerm_subnet.this : key => subnet.id

  }
}

output "network_security_group_ids" {
  description = "Network security group IDs keyed by subnet role."
  value = { for key, nsg in azurerm_network_security_group.this : key => nsg.id

  }
}

output "network_security_group_names" {
  description = "Network security group names keyed by subnet role."
  value = { for key, nsg in azurerm_network_security_group.this : key => nsg.name

  }
}
