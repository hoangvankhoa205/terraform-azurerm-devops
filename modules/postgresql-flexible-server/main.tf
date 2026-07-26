# A PostgreSQL Flexible Server on a delegated subnet, reachable only from inside
# the VNet. Databases, roles, extensions, and firewall rules are the caller's.
#
# The subnet and its private DNS zone are inputs rather than resources here
# because both are shared: the subnet must be delegated to
# Microsoft.DBforPostgreSQL/flexibleServers and can host nothing else, and the
# zone is normally reused across servers. virtual-network's `delegation` block
# builds the subnet.
resource "azurerm_postgresql_flexible_server" "this" {
  name                = var.name
  location            = var.location
  resource_group_name = var.resource_group_name
  version             = var.postgres_version
  delegated_subnet_id = var.delegated_subnet_id
  private_dns_zone_id = var.private_dns_zone_id

  # Hard-coded rather than exposed. A VNet-integrated Flexible Server cannot
  # serve a public endpoint at all, so the knob would only let a caller write a
  # configuration Azure rejects.
  public_network_access_enabled = false

  administrator_login    = var.administrator_login
  administrator_password = var.administrator_password
  sku_name               = var.sku_name
  storage_mb             = var.storage_mb
  backup_retention_days  = var.backup_retention_days

  # Cannot be changed after creation, so it is fixed rather than exposed: a
  # later edit would silently force the server to be replaced, taking the data
  # with it.
  geo_redundant_backup_enabled = false

  zone = var.zone
  tags = var.tags

  # Password authentication only. Entra authentication needs an administrator
  # principal this module does not take, so enabling it is left to a caller who
  # wants it.
  authentication {
    active_directory_auth_enabled = false
    password_auth_enabled         = true
  }

  # Emitted only when asked for: an absent block means no HA, where an empty one
  # is invalid. Enabling HA doubles the compute bill.
  dynamic "high_availability" {
    for_each = var.high_availability == null ? [] : [var.high_availability]
    content {
      mode                      = high_availability.value.mode
      standby_availability_zone = high_availability.value.standby_availability_zone
    }
  }
}
