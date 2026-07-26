mock_provider "azurerm" {
  mock_resource "azurerm_key_vault" {
    defaults = {
      id        = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/learn-rg/providers/Microsoft.KeyVault/vaults/learn-key-vault-001"
      vault_uri = "https://learn-key-vault-001.vault.azure.net/"
    }
  }
}

# Every run needs the same four required inputs; hoisting them keeps each run
# block down to the one thing it is actually testing.
variables {
  name                = "learn-key-vault-001"
  location            = "Southeast Asia"
  resource_group_name = "learn-rg"
  tenant_id           = "00000000-0000-0000-0000-000000000000"
}

run "plans_protected_vault" {
  command = plan

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

# The SKU is hard-coded rather than exposed. That is deliberate: HSM-backed key
# types need a premium vault, and this module documents itself as not offering
# them, so pinning standard keeps the two statements consistent.
run "vault_sku_is_standard" {
  command = plan

  assert {
    condition     = azurerm_key_vault.this.sku_name == "standard"
    error_message = "The vault SKU must be standard; premium is not offered by this module."
  }
}

run "network_acl_exceptions_reach_the_vault" {
  command = plan
  variables {
    network_acls = {
      bypass                     = "None"
      ip_rules                   = ["203.0.113.0/24"]
      virtual_network_subnet_ids = ["/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/learn-rg/providers/Microsoft.Network/virtualNetworks/learn-vnet/subnets/workload"]
    }
  }

  assert {
    condition = (
      azurerm_key_vault.this.network_acls[0].bypass == "None" &&
      contains(azurerm_key_vault.this.network_acls[0].ip_rules, "203.0.113.0/24") &&
      length(azurerm_key_vault.this.network_acls[0].virtual_network_subnet_ids) == 1
    )
    error_message = "Allowlisted IPs and subnets must reach network_acls."
  }

  # The exceptions are additive. Granting one does not flip the vault open.
  assert {
    condition     = azurerm_key_vault.this.network_acls[0].default_action == "Deny"
    error_message = "Adding an exception must not change default_action away from Deny."
  }
}

run "purge_protection_can_be_disabled_for_throwaway_vaults" {
  command = plan
  variables {
    purge_protection_enabled = false
  }

  assert {
    condition     = !azurerm_key_vault.this.purge_protection_enabled
    error_message = "purge_protection_enabled must be honoured when a caller opts out."
  }
}

run "public_access_is_opt_in" {
  command = plan
  variables {
    public_network_access_enabled = true
  }

  assert {
    condition     = azurerm_key_vault.this.public_network_access_enabled
    error_message = "public_network_access_enabled must be honoured when a caller opts in."
  }
}

run "tags_reach_the_vault" {
  command = plan
  variables {
    tags = { env = "learn" }
  }

  assert {
    condition     = azurerm_key_vault.this.tags["env"] == "learn"
    error_message = "Tags must reach the vault."
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# OUTPUTS
# ---------------------------------------------------------------------------------------------------------------------

# id and vault_uri are computed, so the outputs are only readable once the
# mocked apply has resolved them.
run "exposes_the_three_ways_to_address_a_vault" {
  command = apply

  # Three outputs because three consumers need three shapes: an ARM id for
  # other Terraform resources, a data-plane URI for applications, and a bare
  # name for `az keyvault --vault-name`.
  assert {
    condition = (
      output.key_vault_id == azurerm_key_vault.this.id &&
      output.vault_uri == azurerm_key_vault.this.vault_uri &&
      output.name == "learn-key-vault-001"
    )
    error_message = "The vault must be addressable by ARM id, data-plane URI, and name."
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# VALIDATION
# ---------------------------------------------------------------------------------------------------------------------

run "rejects_short_retention" {
  command = plan
  variables {
    soft_delete_retention_days = 6
  }

  expect_failures = [var.soft_delete_retention_days]
}

run "rejects_retention_beyond_the_azure_maximum" {
  command = plan
  variables {
    soft_delete_retention_days = 91
  }

  expect_failures = [var.soft_delete_retention_days]
}

run "rejects_consecutive_hyphens_in_name" {
  command = plan
  variables {
    name = "learn--key-vault"
  }

  expect_failures = [var.name]
}

run "rejects_name_starting_with_a_digit" {
  command = plan
  variables {
    name = "1learn-key-vault"
  }

  expect_failures = [var.name]
}

run "rejects_name_ending_with_a_hyphen" {
  command = plan
  variables {
    name = "learn-key-vault-"
  }

  expect_failures = [var.name]
}

run "rejects_name_longer_than_24_characters" {
  command = plan
  variables {
    name = "learn-key-vault-far-too-long"
  }

  expect_failures = [var.name]
}

run "rejects_unknown_bypass" {
  command = plan
  variables {
    network_acls = {
      bypass = "Everything"
    }
  }

  expect_failures = [var.network_acls]
}
