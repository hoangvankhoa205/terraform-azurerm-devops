mock_provider "azurerm" {
  mock_resource "azurerm_linux_virtual_machine_scale_set" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/learn-rg/providers/Microsoft.Compute/virtualMachineScaleSets/learn-vmss"
    }
  }
}

variables {
  name                = "learn-vmss"
  location            = "Southeast Asia"
  resource_group_name = "learn-rg"
  subnet_id           = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/learn-rg/providers/Microsoft.Network/virtualNetworks/learn-vnet/subnets/workload-private"
  ssh_public_key      = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGgVdTaGVQSlEJI0XpvmEO8h7L0wcOghv4l0pXAoDKYS test-only"
}

run "plans_private_scale_set" {
  command = plan

  assert {
    condition     = azurerm_linux_virtual_machine_scale_set.this.disable_password_authentication
    error_message = "Password authentication must remain disabled."
  }
}

# Manual upgrade mode means changing the image or custom_data updates the model
# but leaves running instances alone until someone rolls them. Automatic would
# reimage every instance the moment a plan applied — safe here only because the
# module ships no health probe, which Rolling mode would require.
run "upgrades_are_manual" {
  command = plan

  assert {
    condition     = azurerm_linux_virtual_machine_scale_set.this.upgrade_mode == "Manual"
    error_message = "The scale set must not reimage running instances on apply."
  }
}

run "instances_and_sku_defaults" {
  command = plan

  assert {
    condition = (
      azurerm_linux_virtual_machine_scale_set.this.instances == 2 &&
      azurerm_linux_virtual_machine_scale_set.this.sku == "Standard_B2s"
    )
    error_message = "The scale set must default to two Standard_B2s instances."
  }
}

run "instances_sku_and_zones_are_overridable" {
  command = plan
  variables {
    instances = 5
    sku       = "Standard_D2s_v3"
    zones     = ["1", "2", "3"]
  }

  assert {
    condition = (
      azurerm_linux_virtual_machine_scale_set.this.instances == 5 &&
      azurerm_linux_virtual_machine_scale_set.this.sku == "Standard_D2s_v3" &&
      length(azurerm_linux_virtual_machine_scale_set.this.zones) == 3
    )
    error_message = "Instance count, SKU, and zones must reach the scale set."
  }
}

# Empty zones is legal and is the default, because several regions have no
# availability zones at all and a hard-coded list would make the module unusable
# in them.
run "zones_default_to_empty" {
  command = plan

  assert {
    condition     = length(azurerm_linux_virtual_machine_scale_set.this.zones) == 0
    error_message = "zones must default to empty so the module works in regions without zones."
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# NETWORKING AND IDENTITY
# ---------------------------------------------------------------------------------------------------------------------

run "instances_are_private" {
  command = plan

  assert {
    condition = (
      one(azurerm_linux_virtual_machine_scale_set.this.network_interface).primary &&
      one(one(azurerm_linux_virtual_machine_scale_set.this.network_interface).ip_configuration).subnet_id == var.subnet_id
    )
    error_message = "The primary NIC must sit in the supplied subnet."
  }

  # No public_ip_address block is configured, so instances get no public
  # addresses and are reachable only from inside the VNet.
  assert {
    condition     = length(one(one(azurerm_linux_virtual_machine_scale_set.this.network_interface).ip_configuration).public_ip_address) == 0
    error_message = "Scale set instances must not be given public IP addresses."
  }
}

run "scale_set_gets_a_system_assigned_identity" {
  command = plan

  assert {
    condition     = one(azurerm_linux_virtual_machine_scale_set.this.identity).type == "SystemAssigned"
    error_message = "The scale set must get a system-assigned managed identity."
  }
}

run "ssh_key_is_installed_for_the_admin_user" {
  command = plan
  variables {
    admin_username = "learnadmin"
  }

  assert {
    condition = (
      azurerm_linux_virtual_machine_scale_set.this.admin_username == "learnadmin" &&
      one(azurerm_linux_virtual_machine_scale_set.this.admin_ssh_key).username == "learnadmin" &&
      one(azurerm_linux_virtual_machine_scale_set.this.admin_ssh_key).public_key == var.ssh_public_key
    )
    error_message = "The SSH key must be installed for the same user the instances are created with."
  }
}

run "image_and_disk_defaults_are_pinned" {
  command = plan

  assert {
    condition = (
      one(azurerm_linux_virtual_machine_scale_set.this.source_image_reference).publisher == "Canonical" &&
      one(azurerm_linux_virtual_machine_scale_set.this.source_image_reference).sku == "22_04-lts-gen2"
    )
    error_message = "Instances must build from Ubuntu 22.04 LTS gen2."
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# CLOUD-INIT, TAGS, OUTPUTS
# ---------------------------------------------------------------------------------------------------------------------

run "custom_data_is_absent_by_default" {
  command = plan

  assert {
    condition     = azurerm_linux_virtual_machine_scale_set.this.custom_data == null
    error_message = "With no custom_data the scale set must receive none at all."
  }
}

run "custom_data_is_base64_encoded_for_the_caller" {
  command = plan
  variables {
    custom_data = "#cloud-config\npackages:\n  - nginx\n"
  }

  assert {
    condition     = azurerm_linux_virtual_machine_scale_set.this.custom_data == base64encode("#cloud-config\npackages:\n  - nginx\n")
    error_message = "custom_data must be base64-encoded exactly once, from the plain text the caller supplied."
  }
}

run "tags_reach_the_scale_set" {
  command = plan
  variables {
    tags = { env = "learn" }
  }

  assert {
    condition     = azurerm_linux_virtual_machine_scale_set.this.tags["env"] == "learn"
    error_message = "Tags must reach the scale set."
  }
}

run "exposes_id_and_principal_id" {
  command = apply

  assert {
    condition = (
      output.scale_set_id == azurerm_linux_virtual_machine_scale_set.this.id &&
      output.principal_id == one(azurerm_linux_virtual_machine_scale_set.this.identity).principal_id
    )
    error_message = "The scale set id and its identity principal must be exposed."
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# VALIDATION
# ---------------------------------------------------------------------------------------------------------------------

run "rejects_zero_instances" {
  command = plan
  variables {
    instances = 0
  }

  expect_failures = [var.instances]
}

run "rejects_a_negative_instance_count" {
  command = plan
  variables {
    instances = -1
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

run "rejects_a_reserved_admin_username" {
  command = plan
  variables {
    admin_username = "administrator"
  }

  expect_failures = [var.admin_username]
}
