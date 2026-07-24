mock_provider "azurerm" {}

run "plans_private_registry" {
  command = plan
  variables {
    name                = "learndevopsacr"
    location            = "Southeast Asia"
    resource_group_name = "learn-rg"

  }
  assert {
    condition     = !azurerm_container_registry.this.admin_enabled && !azurerm_container_registry.this.public_network_access_enabled
    error_message = "The registry must default to managed identity and private access."

  }
}
