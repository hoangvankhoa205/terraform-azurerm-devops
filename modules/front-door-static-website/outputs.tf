output "profile_id" {
  description = "Front Door profile ID."
  value       = azurerm_cdn_frontdoor_profile.this.id
}
output "endpoint_id" {
  description = "Front Door endpoint ID."
  value       = azurerm_cdn_frontdoor_endpoint.this.id
}
output "endpoint_host_name" {
  description = "Front Door default hostname."
  value       = azurerm_cdn_frontdoor_endpoint.this.host_name
}

