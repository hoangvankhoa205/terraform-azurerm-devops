output "registry_id" {
  description = "Container registry resource ID. Grant AcrPull or AcrPush at this scope to let a managed identity authenticate, since the admin account is disabled."
  value       = azurerm_container_registry.this.id
}

output "login_server" {
  description = "Registry login hostname, <name>.azurecr.io. This is the prefix an image reference needs — <login_server>/<repository>:<tag> — and what `az acr login --name` resolves to."
  value       = azurerm_container_registry.this.login_server
}
