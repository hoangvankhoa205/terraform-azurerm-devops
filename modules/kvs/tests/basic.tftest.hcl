mock_provider "azurerm" {
    mock_resource "azurerm_key_vault_secret" {
        defaults = {
          id = "https://laern-key-vault-001.vault.azure.net/secrets/example/abc123"
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
    condition = length(azurerm_key_vault_secret.this) == 2
    error_message = "One secret must be created per entry in var.secrets."
  }
  assert {
    condition = azurerm_key_vault_secret.this["db-password"].content_type == "password"
    error_message = "Per-secret metadata must reach the resource."
  }
  assert {
    condition = azurerm_key_vault_secret.this["db-username"].name == "db-username"
    error_message = "The map key must become the secret name."
  }
}

run "merges_module_tags_under_secret_tags" {
    command = plan
    variables {
      key_vault_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/learn-rg/providers/Microsoft.KeyVault/vaults/learn-key-vault-001"
      tags = {
        project = "infra-playground"
        owner = "platform"
      }

      secrets = {
        db-password = {
            tags = { owner = "database" }
        }
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

run "rejects_invalid_secret_name" {
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
    expect_failures = [ var.secrets ]
}