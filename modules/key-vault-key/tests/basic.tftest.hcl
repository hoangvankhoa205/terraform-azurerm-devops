mock_provider "azurerm" {
  mock_resource "azurerm_key_vault" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/learn-rg/providers/Microsoft.KeyVault/vaults/learn-key-vault-001"
    }
  }
}

run "plans_protected_vault" {
  command = plan
  variables {
    name                = "learn-key-vault-001"
    location            = "Southeast Asia"
    resource_group_name = "learn-rg"
    tenant_id           = "00000000-0000-0000-0000-000000000000"

  }
  assert {
    condition = (
      azurerm_key_vault.this.purge_protection_enabled &&
      !azurerm_key_vault.this.public_network_access_enabled &&
      azurerm_key_vault.this.network_acls[0].default_action == "Deny"
    )
    error_message = "The vault must retain purge protection and default-deny private access."

  }
}

run "rejects_unknown_bypass" {
  command = plan
  variables {
    name                = "learn-key-vault-001"
    location            = "Southeast Asia"
    resource_group_name = "learn-rg"
    tenant_id           = "00000000-0000-0000-0000-000000000000"
    network_acls = {
      bypass = "Everything"
    }
  }

  expect_failures = [var.network_acls]
}
