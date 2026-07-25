mock_provider "azurerm" {
  mock_resource "azurerm_storage_account" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/learn-rg/providers/Microsoft.Storage/storageAccounts/learnstaticweb001"
    }
  }
  # Azure gives this resource the account's own ID rather than a distinct one.
  # Mirror that here so web_container_id is asserted against a realistic value.
  mock_resource "azurerm_storage_account_static_website" {
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

# Covers the SHAPE of web_container_id only. The reason the output exists is
# the dependency edge it carries — that it is anchored on the static website
# resource so callers cannot race $web into existence — and no plan-level
# assertion can observe a graph edge. Verify that part with `terraform graph`
# in a root module that consumes this output.
# Runs against the mocked provider, so it creates nothing in Azure. `apply`
# rather than `plan` because a resource ID is computed and stays unknown
# through the plan phase.
run "exposes_web_container_id" {
  command = apply
  variables {
    name                = "learnstaticweb001"
    location            = "Southeast Asia"
    resource_group_name = "learn-rg"
  }
  assert {
    condition     = output.web_container_id == "${output.storage_account_id}/blobServices/default/containers/$web"
    error_message = "web_container_id must be the storage account ID plus the $web container suffix."
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
