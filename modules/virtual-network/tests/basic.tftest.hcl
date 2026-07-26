# The association resource parses the ids it is given, so mocked ids have to be
# well-formed ARM paths rather than the arbitrary strings Terraform generates by
# default. They are shared by every instance here, which is why the pairing
# assertion lives in wiring.tftest.hcl where each instance gets a distinct id.
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
      address_prefixes  = ["10.42.2.0/24"]
      service_endpoints = ["Microsoft.Storage"]
      delegation = {
        service_name = "Microsoft.DBforPostgreSQL/flexibleServers"
        actions      = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
      }
    }
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# SUBNETS
# ---------------------------------------------------------------------------------------------------------------------

run "plans_private_subnets" {
  command = plan

  assert {
    condition     = azurerm_subnet.this["workload_private"].default_outbound_access_enabled == false
    error_message = "Learning subnets must default to private outbound access."
  }

  assert {
    condition     = azurerm_subnet.this["data_private"].delegation[0].service_delegation[0].name == "Microsoft.DBforPostgreSQL/flexibleServers"
    error_message = "The data subnet must retain its PostgreSQL service delegation."
  }
}

# The map key is a role name, and Terraform map keys read naturally with
# underscores — but Azure subnet names conventionally use hyphens. main.tf
# bridges that with replace(), so the key you write is not the name Azure sees.
run "subnet_name_converts_underscores_to_hyphens" {
  command = plan

  assert {
    condition     = azurerm_subnet.this["workload_private"].name == "workload-private"
    error_message = "Underscores in the subnet key must become hyphens in the Azure subnet name."
  }
}

run "delegation_block_is_omitted_when_no_delegation_given" {
  command = plan

  assert {
    condition     = length(azurerm_subnet.this["workload_private"].delegation) == 0
    error_message = "A subnet with no delegation must emit no delegation block at all."
  }
}

run "delegation_name_defaults_when_not_supplied" {
  command = plan

  assert {
    condition     = azurerm_subnet.this["data_private"].delegation[0].name == "service-delegation"
    error_message = "An unnamed delegation must fall back to service-delegation."
  }
}

run "service_endpoints_reach_the_subnet" {
  command = plan

  assert {
    condition     = contains(azurerm_subnet.this["data_private"].service_endpoints, "Microsoft.Storage")
    error_message = "service_endpoints must reach the subnet."
  }

  assert {
    condition     = length(azurerm_subnet.this["workload_private"].service_endpoints) == 0
    error_message = "A subnet with no service_endpoints must get an empty list, not a null."
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# NETWORK SECURITY GROUPS
# ---------------------------------------------------------------------------------------------------------------------

# An empty NSG attached to every subnet is the point of this module: Azure's
# default rules already permit intra-VNet traffic and deny inbound Internet, so
# an empty group is a safe default that gives the caller somewhere to add rules
# without first having to create and associate anything.
run "creates_one_nsg_per_subnet" {
  command = plan

  assert {
    condition     = length(azurerm_network_security_group.this) == length(var.subnets)
    error_message = "Every subnet must get its own network security group."
  }
}

# Note the asymmetry with the subnet name above: the NSG name interpolates the
# raw map key, so an underscore in the key survives here but not in the subnet
# name. Pinned deliberately — changing it would rename, and therefore destroy
# and recreate, every NSG in an existing deployment.
run "nsg_name_is_prefixed_by_the_vnet_and_keeps_the_raw_key" {
  command = plan

  assert {
    condition     = azurerm_network_security_group.this["workload_private"].name == "learn-vnet-workload_private-nsg"
    error_message = "NSG names must be $${var.name}-$${key}-nsg using the unmodified map key."
  }
}

# The subnet-to-NSG association pairing is asserted in wiring.tftest.hcl, which
# needs a Terraform-only feature; see the note at the top of that file.

# ---------------------------------------------------------------------------------------------------------------------
# TAGS AND OUTPUTS
# ---------------------------------------------------------------------------------------------------------------------

run "tags_reach_the_vnet_and_every_nsg" {
  command = plan
  variables {
    tags = { env = "learn" }
  }

  assert {
    condition     = azurerm_virtual_network.this.tags["env"] == "learn"
    error_message = "Tags must reach the virtual network."
  }

  assert {
    condition = alltrue([
      for nsg in values(azurerm_network_security_group.this) : nsg.tags["env"] == "learn"
    ])
    error_message = "Tags must reach every network security group."
  }
}

run "exposes_maps_keyed_by_subnet_role" {
  command = apply

  assert {
    condition = (
      output.vnet_name == "learn-vnet" &&
      output.vnet_id == azurerm_virtual_network.this.id
    )
    error_message = "The virtual network must be exposed by id and name."
  }

  # All three maps are keyed by the caller's role name rather than by the Azure
  # resource name, so a caller can look up a subnet with the same key they used
  # to declare it — even though the subnet's Azure name has been rewritten.
  assert {
    condition = (
      length(setsubtract(keys(output.subnet_ids), keys(var.subnets))) == 0 &&
      length(setsubtract(keys(output.network_security_group_ids), keys(var.subnets))) == 0 &&
      length(setsubtract(keys(output.network_security_group_names), keys(var.subnets))) == 0
    )
    error_message = "Every map output must be keyed by the supplied subnet role names."
  }

  assert {
    condition = (
      output.subnet_ids["data_private"] == azurerm_subnet.this["data_private"].id &&
      output.network_security_group_ids["data_private"] == azurerm_network_security_group.this["data_private"].id &&
      output.network_security_group_names["data_private"] == "learn-vnet-data_private-nsg"
    )
    error_message = "Map outputs must carry the matching resource's values."
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# VALIDATION
# ---------------------------------------------------------------------------------------------------------------------

run "rejects_empty_address_space" {
  command = plan
  variables {
    address_space = []
  }

  expect_failures = [var.address_space]
}

run "rejects_empty_subnet_map" {
  command = plan
  variables {
    subnets = {}
  }

  expect_failures = [var.subnets]
}

run "rejects_a_subnet_with_no_address_prefix" {
  command = plan
  variables {
    subnets = {
      workload_private = {
        address_prefixes = []
      }
    }
  }

  expect_failures = [var.subnets]
}
