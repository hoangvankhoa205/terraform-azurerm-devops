mock_provider "azurerm" {
  mock_resource "azurerm_postgresql_flexible_server" {
    defaults = {
      id   = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/learn-rg/providers/Microsoft.DBforPostgreSQL/flexibleServers/learn-postgres-001"
      fqdn = "learn-postgres-001.private.postgres.database.azure.com"
    }
  }
}

variables {
  name                   = "learn-postgres-001"
  location               = "Southeast Asia"
  resource_group_name    = "learn-rg"
  delegated_subnet_id    = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/learn-rg/providers/Microsoft.Network/virtualNetworks/learn-vnet/subnets/data-private"
  private_dns_zone_id    = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/learn-rg/providers/Microsoft.Network/privateDnsZones/learn.postgres.database.azure.com"
  administrator_password = "TestOnly-ChangeMe-123!"
}

# ---------------------------------------------------------------------------------------------------------------------
# NETWORK POSTURE
# ---------------------------------------------------------------------------------------------------------------------

# public_network_access_enabled is hard-coded false rather than exposed. A
# Flexible Server in VNet-integrated mode cannot serve a public endpoint at all,
# so offering the knob would only let a caller write a configuration Azure
# rejects at apply.
run "plans_private_database" {
  command = plan

  assert {
    condition     = !azurerm_postgresql_flexible_server.this.public_network_access_enabled
    error_message = "The database must not expose a public endpoint."
  }

  assert {
    condition = (
      azurerm_postgresql_flexible_server.this.delegated_subnet_id == var.delegated_subnet_id &&
      azurerm_postgresql_flexible_server.this.private_dns_zone_id == var.private_dns_zone_id
    )
    error_message = "The delegated subnet and private DNS zone must reach the server."
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# AUTHENTICATION
# ---------------------------------------------------------------------------------------------------------------------

# Password authentication only. Entra authentication is a deliberate omission
# rather than an oversight: enabling it needs an administrator principal this
# module does not take, so it is left to a caller who wants it.
run "uses_password_authentication_only" {
  command = plan

  assert {
    condition = (
      azurerm_postgresql_flexible_server.this.authentication[0].password_auth_enabled &&
      !azurerm_postgresql_flexible_server.this.authentication[0].active_directory_auth_enabled
    )
    error_message = "The server must use password auth and leave Entra auth off."
  }

  assert {
    condition     = azurerm_postgresql_flexible_server.this.administrator_login == "pgadminuser"
    error_message = "administrator_login must default to pgadminuser."
  }
}

run "administrator_login_is_overridable" {
  command = plan
  variables {
    administrator_login = "dbadmin"
  }

  assert {
    condition     = azurerm_postgresql_flexible_server.this.administrator_login == "dbadmin"
    error_message = "administrator_login must reach the server."
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# HIGH AVAILABILITY — a dynamic block, so both branches need proving
# ---------------------------------------------------------------------------------------------------------------------

run "omits_high_availability_by_default" {
  command = plan

  assert {
    condition     = length(azurerm_postgresql_flexible_server.this.high_availability) == 0
    error_message = "With no high_availability the block must not be emitted at all."
  }
}

run "emits_same_zone_high_availability" {
  command = plan
  variables {
    high_availability = { mode = "SameZone" }
  }

  assert {
    condition = (
      length(azurerm_postgresql_flexible_server.this.high_availability) == 1 &&
      azurerm_postgresql_flexible_server.this.high_availability[0].mode == "SameZone"
    )
    error_message = "SameZone HA must reach the server."
  }
}

run "emits_zone_redundant_high_availability_with_a_standby_zone" {
  command = plan
  variables {
    zone              = "1"
    high_availability = { mode = "ZoneRedundant", standby_availability_zone = "2" }
  }

  assert {
    condition = (
      azurerm_postgresql_flexible_server.this.high_availability[0].mode == "ZoneRedundant" &&
      azurerm_postgresql_flexible_server.this.high_availability[0].standby_availability_zone == "2" &&
      azurerm_postgresql_flexible_server.this.zone == "1"
    )
    error_message = "ZoneRedundant HA must carry a standby zone distinct from the primary."
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# BACKUP AND COMPUTE
# ---------------------------------------------------------------------------------------------------------------------

# Geo-redundant backup is hard-coded off. It cannot be changed after creation,
# so exposing it as a variable would invite an edit that silently forces the
# server to be replaced.
run "backups_default_to_local_pitr" {
  command = plan

  assert {
    condition = (
      azurerm_postgresql_flexible_server.this.backup_retention_days == 7 &&
      !azurerm_postgresql_flexible_server.this.geo_redundant_backup_enabled
    )
    error_message = "Backups must default to seven days of local point-in-time restore."
  }
}

run "compute_and_storage_defaults_reach_the_server" {
  command = plan

  assert {
    condition = (
      azurerm_postgresql_flexible_server.this.sku_name == "B_Standard_B1ms" &&
      azurerm_postgresql_flexible_server.this.storage_mb == 32768 &&
      azurerm_postgresql_flexible_server.this.version == "16"
    )
    error_message = "SKU, storage, and major version defaults must reach the server."
  }
}

run "compute_and_storage_are_overridable" {
  command = plan
  variables {
    sku_name         = "GP_Standard_D2s_v3"
    storage_mb       = 65536
    postgres_version = "17"
  }

  assert {
    condition = (
      azurerm_postgresql_flexible_server.this.sku_name == "GP_Standard_D2s_v3" &&
      azurerm_postgresql_flexible_server.this.storage_mb == 65536 &&
      azurerm_postgresql_flexible_server.this.version == "17"
    )
    error_message = "Caller-supplied SKU, storage, and version must reach the server."
  }
}

run "tags_reach_the_server" {
  command = plan
  variables {
    tags = { env = "learn" }
  }

  assert {
    condition     = azurerm_postgresql_flexible_server.this.tags["env"] == "learn"
    error_message = "Tags must reach the server."
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# OUTPUTS
# ---------------------------------------------------------------------------------------------------------------------

# The module takes a password and must never hand it back. Only two outputs
# exist, so both can be checked directly against the supplied secret.
run "exposes_id_and_fqdn_but_never_the_password" {
  command = apply

  assert {
    condition = (
      output.server_id == azurerm_postgresql_flexible_server.this.id &&
      output.fqdn == azurerm_postgresql_flexible_server.this.fqdn
    )
    error_message = "The server id and FQDN must be exposed."
  }

  assert {
    condition = (
      output.server_id != var.administrator_password &&
      output.fqdn != var.administrator_password
    )
    error_message = "No output may carry the administrator password."
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# VALIDATION
# ---------------------------------------------------------------------------------------------------------------------

run "rejects_backup_retention_below_the_minimum" {
  command = plan
  variables {
    backup_retention_days = 6
  }

  expect_failures = [var.backup_retention_days]
}

run "rejects_backup_retention_beyond_the_maximum" {
  command = plan
  variables {
    backup_retention_days = 36
  }

  expect_failures = [var.backup_retention_days]
}

run "rejects_an_unknown_high_availability_mode" {
  command = plan
  variables {
    high_availability = { mode = "Always" }
  }

  expect_failures = [var.high_availability]
}
