mock_provider "azurerm" {
  mock_resource "azurerm_storage_account" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/learn-state-rg/providers/Microsoft.Storage/storageAccounts/learnstate0001"
    }
  }
}

run "plans_protected_state" {
  command = plan
  variables {
    name                = "learnstate0001"
    location            = "Southeast Asia"
    resource_group_name = "learn-state-rg"

  }
  assert {
    condition = (
      !azurerm_storage_account.this.shared_access_key_enabled &&
      !azurerm_storage_account.this.public_network_access_enabled &&
      azurerm_storage_account.this.network_rules[0].default_action == "Deny" &&
      azurerm_storage_account.this.blob_properties[0].versioning_enabled
    )
    error_message = "State storage must use Entra authentication, default-deny networking, and versioning."
  }
}

run "rejects_mixed_none_bypass" {
  command = plan
  variables {
    name                = "learnstate0001"
    location            = "Southeast Asia"
    resource_group_name = "learn-state-rg"
    network_rules = {
      bypass = ["None", "AzureServices"]
    }
  }
  expect_failures = [var.network_rules]
}
