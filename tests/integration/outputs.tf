output "resource_group_name" {
  description = "Resource group holding everything this run created. Destroying it removes the lot."
  value       = azurerm_resource_group.this.name
}

output "vm_private_ip" {
  description = "Private address of the integration VM."
  value       = module.vm.private_ip_address
}
