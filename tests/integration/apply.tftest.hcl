# Real apply against a real subscription. No mock_provider anywhere in this
# file — that is the entire point.
#
# Every assertion here checks something a mocked plan cannot: that Azure
# accepted the configuration, and that values it computed came back the shape
# the modules claim.

run "applies_a_composed_environment" {
  command = apply

  # Azure assigned a private address, which means the subnet, the NIC, and the
  # delegation were all acceptable — none of that is observable under a mock.
  assert {
    condition     = can(cidrhost("${module.vm.private_ip_address}/32", 0))
    error_message = "The VM must come back with a real private IPv4 address."
  }

  assert {
    condition     = module.vm.private_ip_address != null && module.vm.public_ip_address == null
    error_message = "The VM must be private: an address on the subnet and none on the Internet."
  }

  # A real system-assigned identity is a GUID Entra minted, not a placeholder.
  assert {
    condition     = can(regex("^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$", module.vm.principal_id))
    error_message = "The VM's managed identity must have a real Entra principal ID."
  }

  # One NSG per subnet, actually associated. A mocked plan proves the wiring;
  # only an apply proves Azure allowed the association.
  assert {
    condition     = length(module.network.network_security_group_ids) == 1
    error_message = "Each subnet must get its own network security group."
  }

  # The vault URI is derived by Azure from the name, and is what proves the
  # globally unique name was actually accepted.
  assert {
    condition     = can(regex("^https://tfint.*\\.vault\\.azure\\.net/$", module.vault.vault_uri))
    error_message = "The vault must come back with its real data-plane URI."
  }

  # The most valuable assertion in this file. Writing this secret required the
  # Key Vault Secrets Officer role to have propagated and the vault's RBAC
  # authorization to genuinely be in force. Under a mock it proves nothing;
  # here it proves the whole RBAC story the key-vault README describes.
  assert {
    condition     = length(module.secret.secret_ids) == 1
    error_message = "The secret must have been written through the vault's data plane."
  }

  assert {
    condition     = can(regex("^https://tfint.*\\.vault\\.azure\\.net/secrets/integration-probe/[0-9a-f]+$", module.secret.secret_ids["integration-probe"]))
    error_message = "The secret ID must be a real versioned data-plane URI."
  }

  # Versioned and versionless IDs are distinct in reality, not just in the mock.
  assert {
    condition     = module.secret.secret_ids["integration-probe"] != module.secret.secret_versionless_ids["integration-probe"]
    error_message = "Versioned and versionless secret IDs must differ."
  }
}
