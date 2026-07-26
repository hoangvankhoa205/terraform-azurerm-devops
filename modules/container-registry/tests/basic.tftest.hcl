mock_provider "azurerm" {
  mock_resource "azurerm_container_registry" {
    defaults = {
      id           = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/learn-rg/providers/Microsoft.ContainerRegistry/registries/learndevopsacr"
      login_server = "learndevopsacr.azurecr.io"
    }
  }
}

variables {
  name                = "learndevopsacr"
  location            = "Southeast Asia"
  resource_group_name = "learn-rg"
}

# admin_enabled is hard-coded false rather than exposed. The admin account is a
# shared username and password stored on the registry itself — enabling it hands
# every caller the same long-lived credential and bypasses Entra entirely, which
# is the one thing this module is trying to prevent.
run "plans_private_registry" {
  command = plan

  assert {
    condition     = !azurerm_container_registry.this.admin_enabled && !azurerm_container_registry.this.public_network_access_enabled
    error_message = "The registry must default to managed identity and private access."
  }
}

run "defaults_to_the_basic_sku" {
  command = plan

  assert {
    condition     = azurerm_container_registry.this.sku == "Basic"
    error_message = "sku must default to Basic."
  }
}

# Premium is the tier that unlocks private endpoints, geo-replication and
# customer-managed keys. A caller who disables public access on Basic has a
# registry nothing can reach, so the two settings are tested together.
run "premium_sku_reaches_the_registry" {
  command = plan
  variables {
    sku = "Premium"
  }

  assert {
    condition     = azurerm_container_registry.this.sku == "Premium"
    error_message = "sku must reach the registry."
  }
}

run "public_access_is_opt_in" {
  command = plan
  variables {
    public_network_access_enabled = true
  }

  assert {
    condition     = azurerm_container_registry.this.public_network_access_enabled
    error_message = "public_network_access_enabled must be honoured when a caller opts in."
  }

  # Opting into the public endpoint must not also re-enable the admin account.
  assert {
    condition     = !azurerm_container_registry.this.admin_enabled
    error_message = "The admin account must stay disabled regardless of network access."
  }
}

run "tags_reach_the_registry" {
  command = plan
  variables {
    tags = { env = "learn" }
  }

  assert {
    condition     = azurerm_container_registry.this.tags["env"] == "learn"
    error_message = "Tags must reach the registry."
  }
}

# login_server is computed, so the outputs only resolve after a mocked apply.
run "exposes_id_and_login_server" {
  command = apply

  assert {
    condition = (
      output.id == azurerm_container_registry.this.id &&
      output.login_server == azurerm_container_registry.this.login_server
    )
    error_message = "The registry id and login hostname must be exposed."
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# VALIDATION
# ---------------------------------------------------------------------------------------------------------------------

run "rejects_an_unknown_sku" {
  command = plan
  variables {
    sku = "Ultra"
  }

  expect_failures = [var.sku]
}

# Registry names are alphanumeric only — no hyphens, unlike almost every other
# Azure resource name. This is a common first-apply failure.
run "rejects_a_hyphen_in_the_name" {
  command = plan
  variables {
    name = "learn-devops-acr"
  }

  expect_failures = [var.name]
}

run "rejects_a_name_shorter_than_five_characters" {
  command = plan
  variables {
    name = "acr1"
  }

  expect_failures = [var.name]
}

run "rejects_a_name_longer_than_50_characters" {
  command = plan
  variables {
    name = "learndevopsacrnamethatiswaytoolongtobeacceptedbyazure"
  }

  expect_failures = [var.name]
}
