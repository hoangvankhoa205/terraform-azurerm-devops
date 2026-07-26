# A hardened Blob container for Terraform or OpenTofu remote state, and the
# account that holds it. The backend block itself is the caller's — a module
# cannot configure the backend of the root that uses it.
#
# State locking needs nothing extra. The azurerm backend takes a blob lease,
# which is native to Blob Storage, so there is no separate lock table to create
# the way DynamoDB is needed on AWS.
resource "azurerm_storage_account" "this" {
  name                     = var.name
  location                 = var.location
  resource_group_name      = var.resource_group_name
  account_tier             = "Standard"
  account_replication_type = var.replication_type
  min_tls_version          = "TLS1_2"

  # Disabling the shared key is what forces every caller onto Entra ID, and is
  # what makes an OIDC-only pipeline possible. It also means there is no account
  # key to leak — a leaked key would otherwise read every workspace's state.
  shared_access_key_enabled = false

  public_network_access_enabled   = var.public_network_access_enabled
  allow_nested_items_to_be_public = false
  tags                            = var.tags

  network_rules {
    default_action             = "Deny"
    bypass                     = var.network_rules.bypass
    ip_rules                   = var.network_rules.ip_rules
    virtual_network_subnet_ids = var.network_rules.virtual_network_subnet_ids
  }

  # Versioning plus soft delete is the recovery story for state. A corrupt or
  # truncated apply can be rolled back to the previous blob version, and a
  # deleted state file stays recoverable for retention_days.
  blob_properties {
    versioning_enabled = true
    delete_retention_policy {
      days = var.retention_days
    }
  }
}

# private is the only acceptable access type: this container holds every
# workspace's state, and blob or container access would make those files
# readable anonymously over the public endpoint.
resource "azurerm_storage_container" "this" {
  name                  = var.container_name
  storage_account_id    = azurerm_storage_account.this.id
  container_access_type = "private"
}
