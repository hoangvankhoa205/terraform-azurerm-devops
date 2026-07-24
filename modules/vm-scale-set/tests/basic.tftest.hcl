mock_provider "azurerm" {}

run "plans_private_scale_set" {
  command = plan
  variables {
    name                = "learn-vmss"
    location            = "Southeast Asia"
    resource_group_name = "learn-rg"
    subnet_id           = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/learn-rg/providers/Microsoft.Network/virtualNetworks/learn-vnet/subnets/workload-private"
    ssh_public_key      = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGgVdTaGVQSlEJI0XpvmEO8h7L0wcOghv4l0pXAoDKYS test-only"

  }
  assert {
    condition     = azurerm_linux_virtual_machine_scale_set.this.disable_password_authentication
    error_message = "Password authentication must remain disabled."

  }
}
