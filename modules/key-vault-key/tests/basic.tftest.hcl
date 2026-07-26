mock_provider "azurerm" {
  mock_resource "azurerm_key_vault" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/learn-rg/providers/Microsoft.KeyVault/vaults/learn-key-vault-001"
    }
  }
  mock_resource "azurerm_key_vault_key" {
    defaults = {
      id             = "https://learn-key-vault-001.vault.azure.net/keys/learning-key/abc123"
      versionless_id = "https://learn-key-vault-001.vault.azure.net/keys/learning-key"
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

# ---------------------------------------------------------------------------------------------------------------------
# THE VAULT
# ---------------------------------------------------------------------------------------------------------------------

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

# The SKU is hard-coded rather than exposed, and that is load-bearing: RSA-HSM
# and EC-HSM keys need a premium vault, so pinning standard is what makes the
# key-type choice below safe to hard-code too.
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
    error_message = "Allowlisted IPs and subnets must reach network_acls; default_action stays Deny regardless."
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
# THE KEY — the reason this module exists rather than just key-vault
# ---------------------------------------------------------------------------------------------------------------------

run "creates_an_rsa_2048_key" {
  command = plan

  assert {
    condition = (
      azurerm_key_vault_key.this.key_type == "RSA" &&
      azurerm_key_vault_key.this.key_size == 2048
    )
    error_message = "The key must be RSA 2048; those values are hard-coded and must not drift."
  }

  assert {
    condition     = azurerm_key_vault_key.this.name == "learning-key"
    error_message = "key_name must default to learning-key."
  }
}

run "key_name_is_overridable" {
  command = plan
  variables {
    key_name = "cmk"
  }

  assert {
    condition     = azurerm_key_vault_key.this.name == "cmk"
    error_message = "key_name must reach the key resource."
  }
}

# A customer-managed key is used for both envelope encryption (wrap/unwrap) and
# direct crypto, so the full six operations are granted. Terraform has no
# setequal, so subtracting both directions tests equality regardless of ordering.
run "key_opts_cover_every_cmk_operation" {
  command = plan

  assert {
    condition = (
      length(setsubtract(azurerm_key_vault_key.this.key_opts, ["decrypt", "encrypt", "sign", "unwrapKey", "verify", "wrapKey"])) == 0 &&
      length(setsubtract(["decrypt", "encrypt", "sign", "unwrapKey", "verify", "wrapKey"], azurerm_key_vault_key.this.key_opts)) == 0
    )
    error_message = "key_opts must be exactly the six CMK operations."
  }
}

# key_vault_id is computed, so the parent edge is only observable once the
# mocked apply has resolved the vault's id.
run "key_is_created_in_the_vault_this_module_owns" {
  command = apply

  assert {
    condition     = azurerm_key_vault_key.this.key_vault_id == azurerm_key_vault.this.id
    error_message = "The key must be created in the vault this module creates, not an unrelated one."
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# OUTPUTS
# ---------------------------------------------------------------------------------------------------------------------

# Both key ids are computed, so outputs can only be read after a mocked apply.
run "exposes_vault_and_key_ids" {
  command = apply

  assert {
    condition     = output.key_vault_id == azurerm_key_vault.this.id
    error_message = "key_vault_id output must expose the vault id."
  }

  # The versionless id is the one a CMK consumer should bind to: it keeps
  # pointing at the current version as the key rotates, where the versioned id
  # pins the caller to the version that existed at apply time.
  assert {
    condition = (
      output.key_id == azurerm_key_vault_key.this.id &&
      output.key_versionless_id == azurerm_key_vault_key.this.versionless_id &&
      output.key_id != output.key_versionless_id
    )
    error_message = "Both key ids must be exposed, and they must be distinct values."
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
