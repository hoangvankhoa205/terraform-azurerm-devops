# The vault only. Keys, secrets, and certificates are the caller's, the same way
# storage-static-website bbuilds the hosting and leaves the pages to the root.
# One vault can then hold whatever mix of objects a workload needs, instead of
# each object type dragging its own vault along.

resource "azurerm_key_vault" "this" {
    name = var.name
    location = var.location
    resource_group_name = var.resource_group_name
    tenant_id = var.tenant_id
    sku_name = "standard"
    rbac_authorization_enabled = true
    purge_protection_enabled = var.purge_protection_enabled
    soft_delete_retention_days = var.soft_delete_retention_days
    public_network_access_enabled = var.public_network_access_enabled
    tags = var.tags

    network_acls {
      bypass = var.network_acls.bypass
      default_action = "Deny"
      ip_rules = var.network_acls.ip_rules
      virtual_network_subnet_ids = var.network_acls.virtual_network_subnet_ids
    }
}

