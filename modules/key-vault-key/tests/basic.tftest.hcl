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
  # Not covered by the assert above, and it is the property the whole module
  # hangs on: with RBAC authorization the vault ignores access policies, so
  # every data-plane call needs an Entra role and control-plane rights alone
  # grant nothing.
  assert {
    condition     = azurerm_key_vault.this.rbac_authorization_enabled
    error_message = "The vault must authorize the data plane through Entra RBAC, not access policies."

  }
}

run "rejects_short_retention" {
  command = plan
  variables {
    name                       = "learn-key-vault-001"
    location                   = "Southeast Asia"
    resource_group_name        = "learn-rg"
    tenant_id                  = "00000000-0000-0000-0000-000000000000"
    soft_delete_retention_days = 6
  }

  expect_failures = [var.soft_delete_retention_days]
}

run "rejects_consecutive_hyphens_in_name" {
  command = plan
  variables {
    name                = "learn--key-vault"
    location            = "Southeast Asia"
    resource_group_name = "learn-rg"
    tenant_id           = "00000000-0000-0000-0000-000000000000"
  }

  expect_failures = [var.name]
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
