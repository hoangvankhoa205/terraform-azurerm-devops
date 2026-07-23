mock_provider "azurerm" {
  mock_resource "azurerm_public_ip" {
    defaults = {
      id         = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/learn-rg/providers/Microsoft.Network/publicIPAddresses/learn-pip"
      ip_address = "203.0.113.10"
    }
  }
  mock_resource "azurerm_network_interface" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/learn-rg/providers/Microsoft.Network/networkInterfaces/learn-nic"
    }
  }
}

run "plans_without_public_ip" {
  command = plan
  variables {
    name                = "learn-vm"
    location            = "Southeast Asia"
    resource_group_name = "learn-rg"
    subnet_id           = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/learn-rg/providers/Microsoft.Network/virtualNetworks/learn-vnet/subnets/workload-private"
    ssh_public_key      = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGgVdTaGVQSlEJI0XpvmEO8h7L0wcOghv4l0pXAoDKYS test-only"

  }
  assert {
    condition     = azurerm_linux_virtual_machine.this.disable_password_authentication
    error_message = "Password authentication must remain disabled."

  }
  assert {
    condition = (
      length(azurerm_public_ip.this) == 0 &&
      one(azurerm_network_interface.this.ip_configuration).public_ip_address_id == null
    )
    error_message = "A public IP must not be created or attached by default."
  }
}

run "plans_with_opt_in_public_ip" {
  command = apply
  variables {
    name                = "learn-vm"
    location            = "Southeast Asia"
    resource_group_name = "learn-rg"
    subnet_id           = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/learn-rg/providers/Microsoft.Network/virtualNetworks/learn-vnet/subnets/ssh-lab"
    ssh_public_key      = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGgVdTaGVQSlEJI0XpvmEO8h7L0wcOghv4l0pXAoDKYS test-only"
    public_ip_enabled   = true
  }
  assert {
    condition = (
      length(azurerm_public_ip.this) == 1 &&
      azurerm_public_ip.this[0].allocation_method == "Static" &&
      azurerm_public_ip.this[0].sku == "Standard" &&
      azurerm_public_ip.this[0].ip_version == "IPv4"
    )
    error_message = "The opt-in public address must be Standard, static IPv4."
  }
  assert {
    condition     = one(azurerm_network_interface.this.ip_configuration).public_ip_address_id == azurerm_public_ip.this[0].id
    error_message = "The opted-in public IP must be attached to the VM NIC."
  }
  assert {
    condition     = azurerm_linux_virtual_machine.this.disable_password_authentication
    error_message = "Public-IP opt-in must not enable password authentication."
  }
}
