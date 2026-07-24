output "id" {
  description = "Scale set ID."
  value       = azurerm_linux_virtual_machine_scale_set.this.id
}
output "principal_id" {
  description = "Scale set managed identity principal ID."
  value       = azurerm_linux_virtual_machine_scale_set.this.identity[0].principal_id
}

