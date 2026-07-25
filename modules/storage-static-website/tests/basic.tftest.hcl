mock_provider "azurerm" {
  mock_resource "azurerm_storage_account" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/learn-rg/providers/Microsoft.Storage/storageAccounts/learnstaticweb001"
    }
  }
}

run "plans_https_website" {
  command = plan
  variables {
    name                = "learnstaticweb001"
    location            = "Southeast Asia"
    resource_group_name = "learn-rg"

  }
  assert {
    condition = (
      azurerm_storage_account.this.https_traffic_only_enabled &&
      !azurerm_storage_account.this.shared_access_key_enabled &&
      !azurerm_storage_account.this.public_network_access_enabled &&
      azurerm_storage_account.this.network_rules[0].default_action == "Deny"
    )
    error_message = "Static hosting must use HTTPS, Entra management, and default-deny networking."

  }
}

run "rejects_mixed_none_bypass" {
  command = plan
  variables {
    name                = "learnstaticweb001"
    location            = "Southeast Asia"
    resource_group_name = "learn-rg"
    network_rules = {
      bypass = ["None", "Logging"]
    }
  }

  expect_failures = [var.network_rules]
}
