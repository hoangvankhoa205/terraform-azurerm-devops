# Terraform only. OpenTofu rejects an instance-keyed override_resource target
# ("Resource instance address with keys is not allowed"), and without per-instance
# overrides every NIC shares one mocked id — which would make the pairing
# assertion below pass even on a transposed for_each. The rest of the suite lives
# in basic.tftest.hcl and runs on both tools.

mock_provider "azurerm" {
  mock_resource "azurerm_network_interface" {
    defaults = {
      id                 = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/learn-rg/providers/Microsoft.Network/networkInterfaces/learn-nic"
      private_ip_address = "10.42.1.4"
    }
  }
  mock_resource "azurerm_linux_virtual_machine" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/learn-rg/providers/Microsoft.Compute/virtualMachines/learn-vm"
    }
  }
}

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

# Count alone would pass on a transposed for_each; this pins each VM to the NIC
# that shares its key.
run "each_vm_uses_its_own_nic" {
  command = apply

  override_resource {
    target = azurerm_network_interface.this["one"]
    values = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/learn-rg/providers/Microsoft.Network/networkInterfaces/one-nic"
    }
  }
  override_resource {
    target = azurerm_network_interface.this["two"]
    values = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/learn-rg/providers/Microsoft.Network/networkInterfaces/two-nic"
    }
  }

  assert {
    condition = alltrue([
      for k in keys(var.instances) :
      azurerm_linux_virtual_machine.this[k].network_interface_ids[0] == azurerm_network_interface.this[k].id
    ])
    error_message = "Each VM must attach the NIC that shares its key."
  }
}
