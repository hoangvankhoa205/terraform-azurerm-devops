mock_provider "azurerm" {
  mock_resource "azurerm_storage_account" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/learn-state-rg/providers/Microsoft.Storage/storageAccounts/learnstate0001"
    }
  }
}

variables {
  name                = "learnstate0001"
  location            = "Southeast Asia"
  resource_group_name = "learn-state-rg"
}

# ---------------------------------------------------------------------------------------------------------------------
# THE ACCOUNT
# ---------------------------------------------------------------------------------------------------------------------

run "plans_protected_state" {
  command = plan

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

# Disabling the shared key is what forces every caller onto Entra ID, and it is
# the setting that makes the backend OIDC-only. If it ever flips, a leaked
# account key would be enough to read every workspace's state.
run "hardening_defaults_are_not_configurable" {
  command = plan

  assert {
    condition = (
      azurerm_storage_account.this.min_tls_version == "TLS1_2" &&
      !azurerm_storage_account.this.allow_nested_items_to_be_public &&
      azurerm_storage_account.this.account_tier == "Standard"
    )
    error_message = "TLS floor, nested-item privacy, and account tier are hard-coded and must not drift."
  }
}

run "retention_reaches_the_delete_policy" {
  command = plan

  assert {
    condition     = azurerm_storage_account.this.blob_properties[0].delete_retention_policy[0].days == 14
    error_message = "retention_days must default to 14 and reach delete_retention_policy."
  }
}

run "retention_is_overridable" {
  command = plan
  variables {
    retention_days = 30
  }

  assert {
    condition     = azurerm_storage_account.this.blob_properties[0].delete_retention_policy[0].days == 30
    error_message = "A caller-supplied retention_days must reach delete_retention_policy."
  }
}

run "replication_type_is_overridable" {
  command = plan
  variables {
    replication_type = "GRS"
  }

  assert {
    condition     = azurerm_storage_account.this.account_replication_type == "GRS"
    error_message = "replication_type must reach the account."
  }
}

run "defaults_to_zone_redundant_replication" {
  command = plan

  assert {
    condition     = azurerm_storage_account.this.account_replication_type == "ZRS"
    error_message = "State storage must default to zone-redundant replication."
  }
}

run "network_rule_exceptions_reach_the_account" {
  command = plan
  variables {
    network_rules = {
      bypass                     = ["Logging", "Metrics"]
      ip_rules                   = ["203.0.113.10"]
      virtual_network_subnet_ids = ["/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/learn-rg/providers/Microsoft.Network/virtualNetworks/learn-vnet/subnets/runners"]
    }
  }

  assert {
    condition = (
      contains(azurerm_storage_account.this.network_rules[0].ip_rules, "203.0.113.10") &&
      length(azurerm_storage_account.this.network_rules[0].virtual_network_subnet_ids) == 1 &&
      length(azurerm_storage_account.this.network_rules[0].bypass) == 2
    )
    error_message = "Allowlisted runner IPs and subnets must reach network_rules."
  }

  # Exceptions are additive; granting one must not open the account.
  assert {
    condition     = azurerm_storage_account.this.network_rules[0].default_action == "Deny"
    error_message = "Adding an exception must not change default_action away from Deny."
  }
}

run "public_access_is_opt_in" {
  command = plan
  variables {
    public_network_access_enabled = true
  }

  assert {
    condition     = azurerm_storage_account.this.public_network_access_enabled
    error_message = "public_network_access_enabled must be honoured when a caller opts in."
  }
}

run "tags_reach_the_account" {
  command = plan
  variables {
    tags = { env = "learn" }
  }

  assert {
    condition     = azurerm_storage_account.this.tags["env"] == "learn"
    error_message = "Tags must reach the storage account."
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# THE CONTAINER
# ---------------------------------------------------------------------------------------------------------------------

# The container holds every workspace's state file. `private` is the only
# acceptable access type here — `blob` or `container` would make state readable
# anonymously over the public endpoint.
run "creates_a_private_state_container" {
  command = plan

  assert {
    condition = (
      azurerm_storage_container.this.name == "tfstate" &&
      azurerm_storage_container.this.container_access_type == "private"
    )
    error_message = "The state container must be named tfstate by default and never be publicly readable."
  }
}

run "container_name_is_overridable" {
  command = plan
  variables {
    container_name = "tfstate-prod"
  }

  assert {
    condition     = azurerm_storage_container.this.name == "tfstate-prod"
    error_message = "container_name must reach the container."
  }
}

# storage_account_id is computed, so the parent edge only resolves at apply.
run "container_lives_in_the_account_this_module_owns" {
  command = apply

  assert {
    condition     = azurerm_storage_container.this.storage_account_id == azurerm_storage_account.this.id
    error_message = "The container must be created in the account this module creates."
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# OUTPUTS
# ---------------------------------------------------------------------------------------------------------------------

# backend_example exists so a caller can paste the three values an azurerm
# backend block needs without hand-assembling them. It deliberately carries no
# secret: shared-key auth is disabled, so there is no access key to leak.
run "backend_example_matches_the_real_resources" {
  command = apply

  assert {
    condition = (
      output.backend_example.resource_group_name == "learn-state-rg" &&
      output.backend_example.storage_account_name == output.storage_account_name &&
      output.backend_example.container_name == output.container_name
    )
    error_message = "backend_example must agree with the account and container actually created."
  }

  assert {
    condition = (
      output.storage_account_id == azurerm_storage_account.this.id &&
      output.storage_account_name == "learnstate0001" &&
      output.container_name == "tfstate"
    )
    error_message = "Account id, account name, and container name must all be exposed."
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# VALIDATION
# ---------------------------------------------------------------------------------------------------------------------

run "rejects_mixed_none_bypass" {
  command = plan
  variables {
    network_rules = {
      bypass = ["None", "AzureServices"]
    }
  }

  expect_failures = [var.network_rules]
}

# The other half of the same compound validation: an outright unknown value,
# rather than a legal value in an illegal combination.
run "rejects_unknown_bypass_value" {
  command = plan
  variables {
    network_rules = {
      bypass = ["Everything"]
    }
  }

  expect_failures = [var.network_rules]
}

run "rejects_uppercase_in_name" {
  command = plan
  variables {
    name = "LearnState0001"
  }

  expect_failures = [var.name]
}

run "rejects_name_shorter_than_three_characters" {
  command = plan
  variables {
    name = "ab"
  }

  expect_failures = [var.name]
}

run "rejects_name_longer_than_24_characters" {
  command = plan
  variables {
    name = "learnstateaccountwaytoolong"
  }

  expect_failures = [var.name]
}

run "rejects_retention_below_the_minimum" {
  command = plan
  variables {
    retention_days = 6
  }

  expect_failures = [var.retention_days]
}

run "rejects_retention_beyond_the_maximum" {
  command = plan
  variables {
    retention_days = 366
  }

  expect_failures = [var.retention_days]
}
