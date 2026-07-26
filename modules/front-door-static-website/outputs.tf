output "profile_id" {
  description = "Front Door profile resource ID. Attach a WAF policy or a custom domain at this scope."
  value       = azurerm_cdn_frontdoor_profile.this.id
}

output "endpoint_id" {
  description = "Front Door endpoint resource ID."
  value       = azurerm_cdn_frontdoor_endpoint.this.id
}

output "endpoint_host_name" {
  description = "Public hostname Front Door serves the site on, <endpoint_name>.z01.azurefd.net. Azure allocates the middle segment, so it cannot be predicted before apply. Pass https://<this> to endpoint-test to verify the site end to end."
  value       = azurerm_cdn_frontdoor_endpoint.this.host_name
}
