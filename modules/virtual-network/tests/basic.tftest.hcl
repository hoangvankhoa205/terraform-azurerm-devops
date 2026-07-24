mock_provider "azurerm" {
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

run "plans_private_subnets" {
  command = plan
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
        delegation = {
          service_name = "Microsoft.DBforPostgreSQL/flexibleServers"
          actions      = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
        }
      }
    }
  }
  assert {
    condition     = azurerm_subnet.this["workload_private"].default_outbound_access_enabled == false
    error_message = "Learning subnets must default to private outbound access."
  }
  assert {
    condition     = azurerm_subnet.this["data_private"].delegation[0].service_delegation[0].name == "Microsoft.DBforPostgreSQL/flexibleServers"
    error_message = "The data subnet must retain its PostgreSQL service delegation."
  }
}
