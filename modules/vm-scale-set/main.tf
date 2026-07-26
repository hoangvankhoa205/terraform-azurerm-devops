# A private Linux scale set with a fixed instance count. Autoscale rules, health
# probes, a load balancer, and automatic instance repair are the caller's —
# choose linux-vms instead when the machines are individuals rather than
# interchangeable copies.
resource "azurerm_linux_virtual_machine_scale_set" "this" {
  name                            = var.name
  location                        = var.location
  resource_group_name             = var.resource_group_name
  sku                             = var.sku
  instances                       = var.instances
  admin_username                  = var.admin_username
  disable_password_authentication = true

  # Manual means a change to the image or custom_data updates the scale set
  # model but leaves running instances alone until someone rolls them.
  # Automatic would reimage every instance the moment a plan applied, and
  # Rolling needs a health probe this module does not create — so Manual is the
  # only mode that is safe without a load balancer in front.
  upgrade_mode = "Manual"

  zones = var.zones

  # Encoded here so the caller passes readable cloud-init text.
  custom_data = var.custom_data == null ? null : base64encode(var.custom_data)
  tags        = var.tags

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

  # No public_ip_address block, so instances get private addresses only and are
  # reachable from inside the VNet.
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

