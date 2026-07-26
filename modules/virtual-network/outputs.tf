output "vnet_id" {
  description = "Virtual network resource ID."
  value       = azurerm_virtual_network.this.id
}

output "vnet_name" {
  description = "Virtual network name."
  value       = azurerm_virtual_network.this.name
}

# All three maps are keyed by the caller's role name, not by the Azure resource
# name, so a subnet can be looked up with the same key it was declared with even
# though its Azure name has had underscores rewritten to hyphens.
output "subnet_ids" {
  description = "Subnet IDs keyed by the supplied role names. Pass one of these to linux-vm, vm-scale-set, or postgresql-flexible-server."
  value       = { for key, subnet in azurerm_subnet.this : key => subnet.id }
}

output "network_security_group_ids" {
  description = "Network security group IDs keyed by subnet role. Add azurerm_network_security_rule resources at these scopes; the groups this module creates are empty."
  value       = { for key, nsg in azurerm_network_security_group.this : key => nsg.id }
}

output "network_security_group_names" {
  description = "Network security group names keyed by subnet role, for az CLI calls that take --nsg-name."
  value       = { for key, nsg in azurerm_network_security_group.this : key => nsg.name }
}
