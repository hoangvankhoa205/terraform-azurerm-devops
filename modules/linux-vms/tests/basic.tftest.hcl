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

run "plans_each_instance" {
  command = plan

  assert {
    condition     = length(azurerm_linux_virtual_machine.this) == 2
    error_message = "A VM must be planned for each map entry."
  }

  # The NIC is created per instance too. Asserting only on the VMs would let a
  # missing NIC through until apply.
  assert {
    condition     = length(azurerm_network_interface.this) == 2
    error_message = "Each VM must get its own network interface."
  }
}

# The map key is the VM's Azure name and the stem of its NIC name, which is why
# renaming a key destroys and recreates that VM.
run "names_are_derived_from_the_map_key" {
  command = plan

  assert {
    condition = (
      azurerm_linux_virtual_machine.this["one"].name == "one" &&
      azurerm_network_interface.this["one"].name == "one-nic"
    )
    error_message = "The map key must become the VM name and the NIC name stem."
  }
}

# The VM-to-NIC pairing is asserted in wiring.tftest.hcl, which needs a
# Terraform-only feature; see the note at the top of that file.

run "instance_defaults_apply_when_not_overridden" {
  command = plan

  assert {
    condition = (
      azurerm_linux_virtual_machine.this["one"].size == "Standard_D2s_v3" &&
      azurerm_linux_virtual_machine.this["one"].admin_username == "azureuser"
    )
    error_message = "size and admin_username must fall back to their optional() defaults."
  }
}

run "per_instance_overrides_are_independent" {
  command = plan
  variables {
    instances = {
      one = {
        subnet_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/learn-rg/providers/Microsoft.Network/virtualNetworks/learn-vnet/subnets/workload-private"
        size      = "Standard_B2s"
      }
      two = {
        subnet_id      = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/learn-rg/providers/Microsoft.Network/virtualNetworks/learn-vnet/subnets/data-private"
        admin_username = "learnadmin"
      }
    }
  }

  assert {
    condition = (
      azurerm_linux_virtual_machine.this["one"].size == "Standard_B2s" &&
      azurerm_linux_virtual_machine.this["two"].size == "Standard_D2s_v3"
    )
    error_message = "Overriding one instance's size must not change the other's."
  }

  assert {
    condition = (
      azurerm_linux_virtual_machine.this["two"].admin_username == "learnadmin" &&
      azurerm_linux_virtual_machine.this["one"].admin_username == "azureuser"
    )
    error_message = "Overriding one instance's admin_username must not change the other's."
  }

  assert {
    condition     = one(azurerm_network_interface.this["two"].ip_configuration).subnet_id != one(azurerm_network_interface.this["one"].ip_configuration).subnet_id
    error_message = "Instances must be able to sit in different subnets."
  }
}

run "every_vm_is_private_and_key_only" {
  command = plan

  assert {
    condition = alltrue([
      for vm in values(azurerm_linux_virtual_machine.this) : vm.disable_password_authentication
    ])
    error_message = "Password authentication must be disabled on every VM."
  }

  # There is no public IP resource in this module at all, so the only ways in
  # are a bastion, a VPN, or the serial console that boot_diagnostics enables.
  assert {
    condition = alltrue([
      for nic in values(azurerm_network_interface.this) :
      one(nic.ip_configuration).public_ip_address_id == null
    ])
    error_message = "No NIC may carry a public IP."
  }
}

# boot_diagnostics with no storage_account_uri uses a managed account. Without
# it the serial console is unavailable, which on these no-public-IP VMs is the
# only break-glass route left.
run "boot_diagnostics_enable_the_serial_console" {
  command = plan

  assert {
    condition = alltrue([
      for vm in values(azurerm_linux_virtual_machine.this) :
      length(vm.boot_diagnostics) == 1 && one(vm.boot_diagnostics).storage_account_uri == null
    ])
    error_message = "Every VM must have managed boot diagnostics so the serial console works."
  }
}

run "shared_ssh_key_reaches_every_vm" {
  command = plan

  assert {
    condition = alltrue([
      for vm in values(azurerm_linux_virtual_machine.this) :
      one(vm.admin_ssh_key).public_key == var.ssh_public_key &&
      one(vm.admin_ssh_key).username == vm.admin_username
    ])
    error_message = "Every VM must install the shared key for its own admin user."
  }
}

run "custom_data_is_per_instance_and_encoded_once" {
  command = plan
  variables {
    instances = {
      one = {
        subnet_id   = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/learn-rg/providers/Microsoft.Network/virtualNetworks/learn-vnet/subnets/workload-private"
        custom_data = "#cloud-config\npackages:\n  - nginx\n"
      }
      two = {
        subnet_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/learn-rg/providers/Microsoft.Network/virtualNetworks/learn-vnet/subnets/workload-private"
      }
    }
  }

  assert {
    condition     = azurerm_linux_virtual_machine.this["one"].custom_data == base64encode("#cloud-config\npackages:\n  - nginx\n")
    error_message = "custom_data must be base64-encoded exactly once."
  }

  assert {
    condition     = azurerm_linux_virtual_machine.this["two"].custom_data == null
    error_message = "An instance with no custom_data must receive none."
  }
}

run "tags_reach_every_vm_and_nic" {
  command = plan
  variables {
    tags = { env = "learn" }
  }

  assert {
    condition = alltrue(concat(
      [for vm in values(azurerm_linux_virtual_machine.this) : vm.tags["env"] == "learn"],
      [for nic in values(azurerm_network_interface.this) : nic.tags["env"] == "learn"]
    ))
    error_message = "Tags must reach every VM and every NIC."
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# OUTPUTS
# ---------------------------------------------------------------------------------------------------------------------

run "outputs_are_maps_keyed_by_logical_name" {
  command = apply

  assert {
    condition = (
      length(setsubtract(keys(output.ids), keys(var.instances))) == 0 &&
      length(setsubtract(keys(output.private_ip_addresses), keys(var.instances))) == 0 &&
      length(setsubtract(keys(output.principal_ids), keys(var.instances))) == 0
    )
    error_message = "Every map output must be keyed by the caller's instance names."
  }

  assert {
    condition = (
      output.ids["one"] == azurerm_linux_virtual_machine.this["one"].id &&
      output.private_ip_addresses["one"] == azurerm_network_interface.this["one"].private_ip_address &&
      output.principal_ids["one"] == one(azurerm_linux_virtual_machine.this["one"].identity).principal_id
    )
    error_message = "Map outputs must carry the matching instance's values."
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# VALIDATION
# ---------------------------------------------------------------------------------------------------------------------

run "rejects_an_empty_instance_map" {
  command = plan
  variables {
    instances = {}
  }

  expect_failures = [var.instances]
}

run "rejects_a_reserved_admin_username_on_any_instance" {
  command = plan
  variables {
    instances = {
      one = {
        subnet_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/learn-rg/providers/Microsoft.Network/virtualNetworks/learn-vnet/subnets/workload-private"
      }
      two = {
        subnet_id      = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/learn-rg/providers/Microsoft.Network/virtualNetworks/learn-vnet/subnets/workload-private"
        admin_username = "root"
      }
    }
  }

  expect_failures = [var.instances]
}

run "rejects_a_private_key" {
  command = plan
  variables {
    ssh_public_key = "-----BEGIN OPENSSH PRIVATE KEY-----\nb3BlbnNzaC1rZXktdjEAAAAA\n-----END OPENSSH PRIVATE KEY-----"
  }

  expect_failures = [var.ssh_public_key]
}
