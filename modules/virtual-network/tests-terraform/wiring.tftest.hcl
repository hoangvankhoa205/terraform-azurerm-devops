# Terraform only. OpenTofu rejects an instance-keyed override_resource target
# ("Resource instance address with keys is not allowed"), and without per-instance
# overrides every subnet shares one mocked id — which would make the pairing
# assertion below pass even on a transposed for_each. The rest of the suite lives
# in basic.tftest.hcl and runs on both tools.

mock_provider "azurerm" {
  mock_resource "azurerm_virtual_network" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/learn-rg/providers/Microsoft.Network/virtualNetworks/learn-vnet"
    }
  }
  mock_resource "azurerm_subnet" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/learn-rg/providers/Microsoft.Network/virtualNetworks/learn-vnet/subnets/workload-private"
    }
  }
  mock_resource "azurerm_network_security_group" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/learn-rg/providers/Microsoft.Network/networkSecurityGroups/learn-nsg"
    }
  }
}

variables {
  name                = "learn-vnet"
  location            = "Southeast Asia"
  resource_group_name = "learn-rg"
  address_space       = ["10.42.0.0/16"]
  subnets = {
    workload_private = {
      address_prefixes = ["10.42.1.0/24"]
    }
    data_private = {
      address_prefixes = ["10.42.2.0/24"]
    }
  }
}

# Subnet and NSG ids are computed, so the wiring is only observable after a
# mocked apply.
run "associates_each_subnet_with_its_own_nsg" {
  command = apply

  # Distinct ids per instance. Without these every subnet shares one mocked id,
  # and an association wired to the wrong subnet would still compare equal — the
  # pairing assertion below would pass on broken code.
  override_resource {
    target = azurerm_subnet.this["workload_private"]
    values = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/learn-rg/providers/Microsoft.Network/virtualNetworks/learn-vnet/subnets/workload-private"
    }
  }
  override_resource {
    target = azurerm_subnet.this["data_private"]
    values = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/learn-rg/providers/Microsoft.Network/virtualNetworks/learn-vnet/subnets/data-private"
    }
  }
  override_resource {
    target = azurerm_network_security_group.this["workload_private"]
    values = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/learn-rg/providers/Microsoft.Network/networkSecurityGroups/learn-vnet-workload_private-nsg"
    }
  }
  override_resource {
    target = azurerm_network_security_group.this["data_private"]
    values = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/learn-rg/providers/Microsoft.Network/networkSecurityGroups/learn-vnet-data_private-nsg"
    }
  }

  assert {
    condition     = length(azurerm_subnet_network_security_group_association.this) == length(var.subnets)
    error_message = "Every subnet must be associated with a network security group."
  }

  # The pairing, not just the count: association[k] must join subnet[k] to
  # nsg[k]. A transposed for_each would still produce the right count.
  assert {
    condition = alltrue([
      for k in keys(var.subnets) :
      azurerm_subnet_network_security_group_association.this[k].subnet_id == azurerm_subnet.this[k].id &&
      azurerm_subnet_network_security_group_association.this[k].network_security_group_id == azurerm_network_security_group.this[k].id
    ])
    error_message = "Each association must join the subnet and NSG that share its key."
  }
}
