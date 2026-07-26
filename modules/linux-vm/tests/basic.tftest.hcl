mock_provider "azurerm" {
  mock_resource "azurerm_public_ip" {
    defaults = {
      id         = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/learn-rg/providers/Microsoft.Network/publicIPAddresses/learn-pip"
      ip_address = "203.0.113.10"
    }
  }
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
  name                = "learn-vm"
  location            = "Southeast Asia"
  resource_group_name = "learn-rg"
  subnet_id           = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/learn-rg/providers/Microsoft.Network/virtualNetworks/learn-vnet/subnets/workload-private"
  ssh_public_key      = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGgVdTaGVQSlEJI0XpvmEO8h7L0wcOghv4l0pXAoDKYS test-only"
}

# ---------------------------------------------------------------------------------------------------------------------
# NETWORK POSTURE
# ---------------------------------------------------------------------------------------------------------------------

run "plans_without_public_ip" {
  command = plan

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
    subnet_id         = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/learn-rg/providers/Microsoft.Network/virtualNetworks/learn-vnet/subnets/ssh-lab"
    public_ip_enabled = true
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

run "nic_is_wired_to_the_supplied_subnet" {
  command = plan

  assert {
    condition = (
      one(azurerm_network_interface.this.ip_configuration).subnet_id == var.subnet_id &&
      one(azurerm_network_interface.this.ip_configuration).private_ip_address_allocation == "Dynamic"
    )
    error_message = "The NIC must take a dynamic private address in the supplied subnet."
  }
}

run "resource_names_are_derived_from_the_vm_name" {
  command = plan
  variables {
    public_ip_enabled = true
  }

  assert {
    condition = (
      azurerm_network_interface.this.name == "learn-vm-nic" &&
      azurerm_public_ip.this[0].name == "learn-vm-pip"
    )
    error_message = "The NIC and public IP must be named after the VM."
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# IDENTITY AND CREDENTIALS
# ---------------------------------------------------------------------------------------------------------------------

# The SSH key goes to the same username the VM is created with. If the two ever
# diverge, the VM builds fine and then nobody can log in.
run "ssh_key_is_installed_for_the_admin_user" {
  command = plan
  variables {
    admin_username = "learnadmin"
  }

  assert {
    condition = (
      azurerm_linux_virtual_machine.this.admin_username == "learnadmin" &&
      one(azurerm_linux_virtual_machine.this.admin_ssh_key).username == "learnadmin" &&
      one(azurerm_linux_virtual_machine.this.admin_ssh_key).public_key == var.ssh_public_key
    )
    error_message = "The SSH key must be installed for the same user the VM is created with."
  }
}

run "vm_gets_a_system_assigned_identity" {
  command = plan

  assert {
    condition     = one(azurerm_linux_virtual_machine.this.identity).type == "SystemAssigned"
    error_message = "The VM must get a system-assigned managed identity so it can reach Azure without a secret."
  }
}

run "image_and_disk_defaults_are_pinned" {
  command = plan

  assert {
    condition = (
      one(azurerm_linux_virtual_machine.this.source_image_reference).publisher == "Canonical" &&
      one(azurerm_linux_virtual_machine.this.source_image_reference).offer == "0001-com-ubuntu-server-jammy" &&
      one(azurerm_linux_virtual_machine.this.source_image_reference).sku == "22_04-lts-gen2"
    )
    error_message = "The VM must build from Ubuntu 22.04 LTS gen2."
  }

  assert {
    condition = (
      one(azurerm_linux_virtual_machine.this.os_disk).caching == "ReadWrite" &&
      one(azurerm_linux_virtual_machine.this.os_disk).storage_account_type == "Standard_LRS"
    )
    error_message = "The OS disk defaults must not drift."
  }
}

run "size_and_tags_reach_the_vm" {
  command = plan
  variables {
    size = "Standard_B2s"
    tags = { env = "learn" }
  }

  assert {
    condition     = azurerm_linux_virtual_machine.this.size == "Standard_B2s"
    error_message = "size must reach the VM."
  }

  # Tags go on all three resources, not just the VM, so a cost report attributes
  # the NIC and public IP to the same owner.
  assert {
    condition = (
      azurerm_linux_virtual_machine.this.tags["env"] == "learn" &&
      azurerm_network_interface.this.tags["env"] == "learn"
    )
    error_message = "Tags must reach the VM and its NIC."
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# CLOUD-INIT
# ---------------------------------------------------------------------------------------------------------------------

run "custom_data_is_absent_by_default" {
  command = plan

  assert {
    condition     = azurerm_linux_virtual_machine.this.custom_data == null
    error_message = "With no custom_data the VM must receive none at all, not an empty string."
  }
}

# main.tf base64-encodes on the caller's behalf, so the caller passes plain
# cloud-init text. Encoding it twice is the mistake this guards against.
run "custom_data_is_base64_encoded_for_the_caller" {
  command = plan
  variables {
    custom_data = "#cloud-config\npackages:\n  - nginx\n"
  }

  assert {
    condition     = azurerm_linux_virtual_machine.this.custom_data == base64encode("#cloud-config\npackages:\n  - nginx\n")
    error_message = "custom_data must be base64-encoded exactly once, from the plain text the caller supplied."
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# OUTPUTS
# ---------------------------------------------------------------------------------------------------------------------

# The two public-IP outputs are count-dependent. one() collapses the empty list
# to null, so a caller can reference them unconditionally.
run "public_ip_outputs_are_null_when_not_opted_in" {
  command = apply

  assert {
    condition = (
      output.public_ip_id == null &&
      output.public_ip_address == null
    )
    error_message = "Both public IP outputs must be null when public_ip_enabled is false."
  }

  assert {
    condition = (
      output.id == azurerm_linux_virtual_machine.this.id &&
      output.network_interface_id == azurerm_network_interface.this.id &&
      output.private_ip_address == azurerm_network_interface.this.private_ip_address
    )
    error_message = "The VM id, NIC id, and private address must be exposed."
  }

  # principal_id is what a caller grants roles to — it is the whole reason the
  # VM has an identity. Reaching into identity[0] would fail outright if the
  # identity block were ever removed.
  assert {
    condition     = output.principal_id == one(azurerm_linux_virtual_machine.this.identity).principal_id
    error_message = "principal_id must expose the system-assigned identity's principal."
  }
}

run "public_ip_outputs_are_populated_when_opted_in" {
  command = apply
  variables {
    public_ip_enabled = true
  }

  assert {
    condition = (
      output.public_ip_id == azurerm_public_ip.this[0].id &&
      output.public_ip_address == azurerm_public_ip.this[0].ip_address
    )
    error_message = "Both public IP outputs must carry the created address when opted in."
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# VALIDATION
# ---------------------------------------------------------------------------------------------------------------------

# The description promises private keys are never accepted. This is what makes
# that true rather than merely stated.
run "rejects_a_private_key" {
  command = plan
  variables {
    ssh_public_key = "-----BEGIN OPENSSH PRIVATE KEY-----\nb3BlbnNzaC1rZXktdjEAAAAA\n-----END OPENSSH PRIVATE KEY-----"
  }

  expect_failures = [var.ssh_public_key]
}

run "rejects_a_key_with_no_algorithm_prefix" {
  command = plan
  variables {
    ssh_public_key = "AAAAC3NzaC1lZDI1NTE5AAAAIGgVdTaGVQSlEJI0XpvmEO8h7L0wcOghv4l0pXAoDKYS"
  }

  expect_failures = [var.ssh_public_key]
}

run "rejects_a_reserved_admin_username" {
  command = plan
  variables {
    admin_username = "admin"
  }

  expect_failures = [var.admin_username]
}

run "rejects_root_as_admin_username" {
  command = plan
  variables {
    admin_username = "root"
  }

  expect_failures = [var.admin_username]
}

run "rejects_an_admin_username_with_uppercase" {
  command = plan
  variables {
    admin_username = "LearnAdmin"
  }

  expect_failures = [var.admin_username]
}
