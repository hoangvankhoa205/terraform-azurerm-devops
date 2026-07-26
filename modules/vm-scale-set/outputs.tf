output "scale_set_id" {
  description = "Scale set resource ID. Autoscale settings, instance repair, and a load balancer backend pool all attach at this scope."
  value       = azurerm_linux_virtual_machine_scale_set.this.id
}

output "principal_id" {
  description = "System-assigned identity principal ID, shared by every instance. Grant Azure roles to this so instances can reach Key Vault, Storage, or a registry without a stored credential."
  value       = azurerm_linux_virtual_machine_scale_set.this.identity[0].principal_id
}
