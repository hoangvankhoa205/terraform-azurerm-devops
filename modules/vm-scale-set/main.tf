resource "azurerm_linux_virtual_machine_scale_set" "this" {
  name                            = var.name
  location                        = var.location
  resource_group_name             = var.resource_group_name
  sku                             = var.sku
  instances                       = var.instances
  admin_username                  = var.admin_username
  disable_password_authentication = true
  upgrade_mode                    = "Manual"
  zones                           = var.zones
  custom_data                     = var.custom_data == null ? null : base64encode(var.custom_data)
  tags                            = var.tags

  admin_ssh_key {
    username   = var.admin_username
    public_key = var.ssh_public_key

  }
  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"

  }
  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"

  }

  network_interface {
    name    = "private"
    primary = true
    ip_configuration {
      name      = "private"
      primary   = true
      subnet_id = var.subnet_id

    }

  }

  identity {
    type = "SystemAssigned"

  }
}

