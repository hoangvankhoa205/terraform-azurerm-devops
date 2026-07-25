output "storage_account_id" {
  description = "Storage account ID."
  value       = azurerm_storage_account.this.id
}
# Anchored on the static website resource, not the account, and that is the
# whole point. $web is created by enabling static website hosting, so a caller
# that composes this ID from storage_account_id instead only depends on the
# ACCOUNT and races the enablement — Azure answers the blob write with 404
# ContainerNotFound. Referencing this output orders the caller correctly
# without depends_on. Azure gives this resource the account's own ID, so the
# string is identical either way; only the dependency edge differs.
output "web_container_id" {
  description = "ID of the implicit $web container. Prefer this over composing the ID from storage_account_id: it is anchored on the static website resource, so blob writes are ordered after hosting is enabled."
  value       = "${azurerm_storage_account_static_website.this.id}/blobServices/default/containers/$web"
}
output "primary_web_host" {
  description = "Static website origin hostname."
  value       = azurerm_storage_account.this.primary_web_host
}
output "primary_web_endpoint" {
  description = "Static website HTTPS endpoint."
  value       = azurerm_storage_account.this.primary_web_endpoint
}

