mock_provider "azurerm" {
  mock_resource "azurerm_network_interface" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/learn-rg/providers/Microsoft.Network/networkInterfaces/learn-nic"
    }
  }
}

run "plans_each_instance" {
  command = plan
  variables {
    location            = "Southeast Asia"
    resource_group_name = "learn-rg"
    ssh_public_key      = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGgVdTaGVQSlEJI0XpvmEO8h7L0wcOghv4l0pXAoDKYS test-only"
    instances = {
      one = {
        subnet_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/learn-rg/providers/Microsoft.Network/virtualNetworks/learn-vnet/subnets/workload-private"

      }
      two = {
        subnet_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/learn-rg/providers/Microsoft.Network/virtualNetworks/learn-vnet/subnets/workload-private"

      }

    }

  }
  assert {
    condition     = length(azurerm_linux_virtual_machine.this) == 2
    error_message = "A VM must be planned for each map entry."

  }
}
