# Several private Ubuntu VMs from one map, where linux-vm builds exactly one.
# Use this when a set of machines shares a shape and differs only in name,
# subnet, or size; use linux-vm when there is genuinely one.
#
# There is no public IP resource here at all, unlike linux-vm — reaching these
# machines means a bastion, a VPN, a peered network, or the serial console that
# boot_diagnostics enables below.

resource "azurerm_network_interface" "this" {
  for_each = var.instances

  name                = "${each.key}-nic"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags

  ip_configuration {
    name                          = "private"
    subnet_id                     = each.value.subnet_id
    private_ip_address_allocation = "Dynamic"

  }
}

resource "azurerm_linux_virtual_machine" "this" {
  for_each = var.instances

  name                            = each.key
  location                        = var.location
  resource_group_name             = var.resource_group_name
  size                            = each.value.size
  admin_username                  = each.value.admin_username
  disable_password_authentication = true
  # Indexed by the same key, so each VM gets its own NIC rather than sharing one.
  network_interface_ids = [azurerm_network_interface.this[each.key].id]

  # Encoded here so the caller passes readable cloud-init text. Encoding it
  # again before passing it in produces a VM that boots and silently ignores the
  # config.
  custom_data = each.value.custom_data == null ? null : base64encode(each.value.custom_data)
  tags        = var.tags

  admin_ssh_key {
    username   = each.value.admin_username
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
  identity {
    type = "SystemAssigned"

  }

  # Managed storage account (no storage_account_uri) — required for the Azure
  # Serial Console and boot screenshots on these private, no-public-IP VMs.
  boot_diagnostics {}
}

