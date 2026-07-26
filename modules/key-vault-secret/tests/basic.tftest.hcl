mock_provider "azurerm" {
  mock_resource "azurerm_key_vault_secret" {
    defaults = {
      id             = "https://learn-key-vault-001.vault.azure.net/secrets/example/abc123"
      versionless_id = "https://learn-key-vault-001.vault.azure.net/secrets/example"
    }
  }
}

run "creates_one_secret_per_entry" {
  command = plan
  variables {
    key_vault_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/learn-rg/providers/Microsoft.KeyVault/vaults/learn-key-vault-001"
    secrets = {
      db-username = {}
      db-password = { content_type = "password" }
    }
    secret_values = {
      db-username = "pgadmin"
      db-password = "not-a-real-password"
    }

  }
  assert {
    condition     = length(azurerm_key_vault_secret.this) == 2
    error_message = "One secret must be created per entry in var.secrets."

  }
  assert {
    condition     = azurerm_key_vault_secret.this["db-password"].content_type == "password"
    error_message = "Per-secret metadata must reach the resource."

  }
  assert {
    condition     = azurerm_key_vault_secret.this["db-username"].name == "db-username"
    error_message = "The map key must become the secret name."

  }
}

run "every_secret_lands_in_the_supplied_vault" {
  command = plan
  variables {
    key_vault_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/learn-rg/providers/Microsoft.KeyVault/vaults/learn-key-vault-001"
    secrets = {
      db-username = {}
      db-password = {}
    }
    secret_values = {
      db-username = "pgadmin"
      db-password = "not-a-real-password"
    }
  }

  # The module creates no vault of its own, so the only thing anchoring these
  # secrets is the id the caller passed.
  assert {
    condition = alltrue([
      for secret in values(azurerm_key_vault_secret.this) : secret.key_vault_id == var.key_vault_id
    ])
    error_message = "Every secret must be created in the vault the caller named."
  }
}

# The optional date attributes are how a secret is made to expire or to become
# valid later. Left unset they must be absent rather than zero-valued.
run "optional_dates_are_absent_unless_set" {
  command = plan
  variables {
    key_vault_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/learn-rg/providers/Microsoft.KeyVault/vaults/learn-key-vault-001"
    secrets = {
      rotating = {
        expiration_date = "2027-01-01T00:00:00Z"
        not_before_date = "2026-01-01T00:00:00Z"
      }
      plain = {}
    }
    secret_values = {
      rotating = "not-a-real-password"
      plain    = "not-a-real-password"
    }
  }

  assert {
    condition = (
      azurerm_key_vault_secret.this["rotating"].expiration_date == "2027-01-01T00:00:00Z" &&
      azurerm_key_vault_secret.this["rotating"].not_before_date == "2026-01-01T00:00:00Z"
    )
    error_message = "Per-secret expiry and not-before dates must reach the resource."
  }

  assert {
    condition = (
      azurerm_key_vault_secret.this["plain"].expiration_date == null &&
      azurerm_key_vault_secret.this["plain"].not_before_date == null &&
      azurerm_key_vault_secret.this["plain"].content_type == null
    )
    error_message = "A secret with no optional metadata must carry none."
  }
}

run "merges_module_tags_under_secret_tags" {
  command = plan
  variables {
    key_vault_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/learn-rg/providers/Microsoft.KeyVault/vaults/learn-key-vault-001"
    tags         = { project = "infra-playground", owner = "platform" }
    secrets = {
      db-password = { tags = { owner = "database" } }
    }
    secret_values = {
      db-password = "not-a-real-password"
    }

  }
  assert {
    condition = (
      azurerm_key_vault_secret.this["db-password"].tags["project"] == "infra-playground" &&
      azurerm_key_vault_secret.this["db-password"].tags["owner"] == "database"
    )
    error_message = "Module tags must apply to every secret, with each secret's own tags winning on conflict."

  }
}

# ---------------------------------------------------------------------------------------------------------------------
# OUTPUTS
# ---------------------------------------------------------------------------------------------------------------------

# Three outputs, no values among them. The versioned id pins whatever existed at
# apply time; the versionless id follows rotation. A consumer that pins a
# version keeps reading the old secret after someone rotates it.
run "exposes_ids_but_never_values" {
  command = apply
  variables {
    key_vault_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/learn-rg/providers/Microsoft.KeyVault/vaults/learn-key-vault-001"
    secrets = {
      db-password = {}
    }
    secret_values = {
      db-password = "not-a-real-password"
    }
  }

  assert {
    condition = (
      output.secret_ids["db-password"] == azurerm_key_vault_secret.this["db-password"].id &&
      output.secret_versionless_ids["db-password"] == azurerm_key_vault_secret.this["db-password"].versionless_id
    )
    error_message = "Both the versioned and versionless ids must be exposed, keyed by secret name."
  }

  assert {
    condition     = output.secret_ids["db-password"] != output.secret_versionless_ids["db-password"]
    error_message = "The versioned and versionless ids must be distinct."
  }

  assert {
    condition     = contains(output.secret_names, "db-password")
    error_message = "secret_names must list the names created."
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# VALIDATION
# ---------------------------------------------------------------------------------------------------------------------

# Azure allows only alphanumerics and hyphens in a secret name — no
# underscores, no dots. db_password is rejected by Azure itself, so the
# validation exists to fail at plan time rather than partway through an apply.
# Note the keys DO match across the two maps here; the name alone is the
# problem.
run "rejects_underscore_in_secret_name" {
  command = plan
  variables {
    key_vault_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/learn-rg/providers/Microsoft.KeyVault/vaults/learn-key-vault-001"
    secrets = {
      "db_password" = {}
    }
    secret_values = {
      "db_password" = "not-a-real-password"
    }
  }

  expect_failures = [var.secrets]
}

# A secret declared with no value. Without the cross-variable validation this
# surfaced as "Invalid index" inside the resource, naming neither the variable
# at fault nor the missing key.
run "rejects_secret_with_no_value" {
  command = plan
  variables {
    key_vault_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/learn-rg/providers/Microsoft.KeyVault/vaults/learn-key-vault-001"
    secrets = {
      db-username = {}
      db-password = {}
    }
    secret_values = {
      db-username = "pgadmin"
    }
  }

  expect_failures = [var.secrets]
}

# The mirror: a value nobody asked for. Almost always a typo in one of the two
# maps, and silently ignoring it would create the wrong secret and skip the
# intended one.
#
# expect_failures names var.secrets, not var.secret_values, because both
# key-matching validations live on var.secrets — Terraform rejects two
# variables whose validations reference each other.
run "rejects_value_with_no_secret" {
  command = plan
  variables {
    key_vault_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/learn-rg/providers/Microsoft.KeyVault/vaults/learn-key-vault-001"
    secrets = {
      db-password = {}
    }
    secret_values = {
      db-password = "not-a-real-password"
      db-passwrod = "typo-nobody-declared"
    }
  }

  expect_failures = [var.secrets]
}
