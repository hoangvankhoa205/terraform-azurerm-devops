# A VNet with subnets from a map keyed by role, each with its own empty network
# security group already attached. The rules inside those groups are the
# caller's — the module builds the wiring, not the policy.
#
# The empty-NSG default is deliberate. Azure's built-in rules already allow
# traffic within the VNet and deny inbound from the Internet, so an empty group
# changes nothing on day one but gives the caller somewhere to add a rule
# without first having to create a group and associate it.

resource "azurerm_virtual_network" "this" {
  name                = var.name
  location            = var.location
  resource_group_name = var.resource_group_name
  address_space       = var.address_space
  tags                = var.tags
}

# Note the naming asymmetry with the subnet below: this interpolates the raw map
# key, so a key of workload_private yields <vnet>-workload_private-nsg while the
# subnet itself becomes workload-private. Both are valid Azure names. It is
# pinned rather than harmonised because renaming an NSG destroys and recreates
# it, along with every rule a caller has added.
resource "azurerm_network_security_group" "this" {
  for_each = var.subnets

  name                = "${var.name}-${each.key}-nsg"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_subnet" "this" {
  for_each = var.subnets

  # Map keys read naturally with underscores in HCL, but Azure subnet names
  # conventionally use hyphens, so the key is translated rather than the caller
  # being made to write hyphens in a map key.
  name                 = replace(each.key, "_", "-")
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = each.value.address_prefixes
  service_endpoints    = each.value.service_endpoints

  # Defaults to false. Azure's default outbound access is a shared, unpredictable
  # set of IP addresses that Microsoft is retiring; a workload that needs egress
  # should get a NAT Gateway with an address you control.
  default_outbound_access_enabled = each.value.default_outbound_access_enabled

  # A subnet may be delegated to at most one service, and an empty delegation
  # block is not the same as none — so the block is emitted only when asked for.
  dynamic "delegation" {
    for_each = each.value.delegation == null ? [] : [each.value.delegation]
    content {
      name = delegation.value.name
      service_delegation {
        name    = delegation.value.service_name
        actions = delegation.value.actions
      }
    }
  }
}

# Separate resources rather than an inline reference, because a subnet and its
# security group have to exist before they can be joined. Keying the association
# by the same map key is what guarantees each subnet gets its own group.
resource "azurerm_subnet_network_security_group_association" "this" {
  for_each = var.subnets

  subnet_id                 = azurerm_subnet.this[each.key].id
  network_security_group_id = azurerm_network_security_group.this[each.key].id
}
