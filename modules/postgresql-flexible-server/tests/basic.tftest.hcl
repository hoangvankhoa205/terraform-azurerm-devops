mock_provider "azurerm" {}

run "plans_private_database" {
  command = plan
  variables {
    name                   = "learn-postgres-001"
    location               = "Southeast Asia"
    resource_group_name    = "learn-rg"
    delegated_subnet_id    = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/learn-rg/providers/Microsoft.Network/virtualNetworks/learn-vnet/subnets/data-private"
    private_dns_zone_id    = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/learn-rg/providers/Microsoft.Network/privateDnsZones/learn.postgres.database.azure.com"
    administrator_password = "TestOnly-ChangeMe-123!"
  }
  assert {
    condition     = !azurerm_postgresql_flexible_server.this.public_network_access_enabled
    error_message = "The database must not expose a public endpoint."
  }
}