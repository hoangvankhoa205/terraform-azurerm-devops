mock_provider "azurerm" {
  mock_resource "azurerm_storage_account" {
    defaults = {
      id                   = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/learn-rg/providers/Microsoft.Storage/storageAccounts/learnstaticweb001"
      primary_web_host     = "learnstaticweb001.z23.web.core.windows.net"
      primary_web_endpoint = "https://learnstaticweb001.z23.web.core.windows.net/"
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

variables {
  name                = "learnstaticweb001"
  location            = "Southeast Asia"
  resource_group_name = "learn-rg"
}

run "plans_https_website" {
  command = plan

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

# StorageV2 is what makes static website hosting available at all; the older
# kinds simply have no $web container. TLS 1.2 and private nested items are the
# same hardening the state-storage module applies.
run "account_shape_supports_static_hosting" {
  command = plan

  assert {
    condition = (
      azurerm_storage_account.this.account_kind == "StorageV2" &&
      azurerm_storage_account.this.account_tier == "Standard" &&
      azurerm_storage_account.this.min_tls_version == "TLS1_2" &&
      !azurerm_storage_account.this.allow_nested_items_to_be_public
    )
    error_message = "The account must be a hardened StorageV2 account so static hosting works."
  }
}

run "document_defaults_reach_the_website" {
  command = plan

  assert {
    condition = (
      azurerm_storage_account_static_website.this.index_document == "index.html" &&
      azurerm_storage_account_static_website.this.error_404_document == "404.html"
    )
    error_message = "The index and 404 documents must default to index.html and 404.html."
  }
}

# A single-page app usually wants the 404 document pointed back at index.html so
# client-side routing works, which is the main reason to override these.
run "documents_are_overridable" {
  command = plan
  variables {
    index_document     = "home.html"
    error_404_document = "index.html"
  }

  assert {
    condition = (
      azurerm_storage_account_static_website.this.index_document == "home.html" &&
      azurerm_storage_account_static_website.this.error_404_document == "index.html"
    )
    error_message = "Caller-supplied document names must reach the website resource."
  }
}

run "network_rule_exceptions_reach_the_account" {
  command = plan
  variables {
    network_rules = {
      bypass   = ["Logging"]
      ip_rules = ["203.0.113.10"]
    }
  }

  assert {
    condition = (
      contains(azurerm_storage_account.this.network_rules[0].ip_rules, "203.0.113.10") &&
      azurerm_storage_account.this.network_rules[0].default_action == "Deny"
    )
    error_message = "Allowlisted IPs must reach network_rules without changing default_action."
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

  # Opening the endpoint must not also re-enable shared-key auth.
  assert {
    condition     = !azurerm_storage_account.this.shared_access_key_enabled
    error_message = "Shared-key auth must stay disabled regardless of network access."
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
# OUTPUTS
# ---------------------------------------------------------------------------------------------------------------------

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

  assert {
    condition     = output.web_container_id == "${output.storage_account_id}/blobServices/default/containers/$web"
    error_message = "web_container_id must be the storage account ID plus the $web container suffix."
  }
}

# The two hostname outputs are not interchangeable, and picking the wrong one is
# a real failure: front-door-static-website validates that origin_host_name has
# no URL scheme, so primary_web_endpoint is rejected there and primary_web_host
# is the one to pass.
run "exposes_a_bare_host_and_a_full_endpoint" {
  command = apply

  assert {
    condition = (
      output.primary_web_host == azurerm_storage_account.this.primary_web_host &&
      output.primary_web_endpoint == azurerm_storage_account.this.primary_web_endpoint
    )
    error_message = "Both the hostname and the endpoint URL must be exposed."
  }

  assert {
    condition = (
      !can(regex("^https?://", output.primary_web_host)) &&
      can(regex("^https://", output.primary_web_endpoint))
    )
    error_message = "primary_web_host must be a bare hostname and primary_web_endpoint a full HTTPS URL."
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# VALIDATION
# ---------------------------------------------------------------------------------------------------------------------

run "rejects_mixed_none_bypass" {
  command = plan
  variables {
    network_rules = {
      bypass = ["None", "Logging"]
    }
  }

  expect_failures = [var.network_rules]
}

# The other half of the same compound validation: an outright unknown value
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
    name = "LearnStaticWeb001"
  }

  expect_failures = [var.name]
}

run "rejects_a_hyphen_in_the_name" {
  command = plan
  variables {
    name = "learn-static-web"
  }

  expect_failures = [var.name]
}

run "rejects_a_name_longer_than_24_characters" {
  command = plan
  variables {
    name = "learnstaticwebsitenamewaytoolong"
  }

  expect_failures = [var.name]
}
