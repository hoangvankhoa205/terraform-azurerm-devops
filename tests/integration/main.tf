# A root configuration that composes several modules and applies them for real.
#
# Mocked plan tests prove that configuration is wired correctly. They cannot
# prove Azure accepts it — that a subnet delegation is valid, that a name passes
# server-side rules, that a vault's RBAC actually admits the caller. This is the
# "credentialed Azure integration" evidence .github/workflows/release.yml
# demands before it will cut a 1.0.0 tag.
#
# It creates billable resources. See README.md in this directory.

terraform {
  required_version = ">= 1.9, < 2.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 4.81.0, < 5.0.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.6.0, < 4.0.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = ">= 4.0.0, < 5.0.0"
    }
  }
}

provider "azurerm" {
  features {
    resource_group {
      # The whole run is disposable; let destroy clean up anything left behind
      # rather than stranding a resource group that blocks the next run.
      prevent_deletion_if_contains_resources = false
    }
    key_vault {
      # Without this a failed run leaves a soft-deleted vault whose globally
      # unique name is reserved, and every later run fails on the name.
      purge_soft_delete_on_destroy    = true
      recover_soft_deleted_key_vaults = false
    }
  }
}

data "azurerm_client_config" "current" {}

# Names have to be unique per run: storage accounts and vaults are global, and a
# soft-deleted vault holds its name for days.
resource "random_string" "suffix" {
  length  = 8
  lower   = true
  upper   = false
  numeric = true
  special = false
}

# Generated rather than read from disk so the suite needs no key on the runner.
# The private half is discarded — nothing here logs in.
resource "tls_private_key" "ssh" {
  algorithm = "ED25519"
}

resource "azurerm_resource_group" "this" {
  name     = "tf-int-${random_string.suffix.result}-rg"
  location = var.location
  tags     = local.tags
}

locals {
  tags = {
    purpose   = "terraform-azurerm-devops-integration"
    ephemeral = "true"
  }
}

module "network" {
  source = "../../modules/virtual-network"

  name                = "tf-int-${random_string.suffix.result}-vnet"
  location            = var.location
  resource_group_name = azurerm_resource_group.this.name
  address_space       = ["10.60.0.0/16"]
  tags                = local.tags

  subnets = {
    workload_private = {
      address_prefixes = ["10.60.1.0/24"]
    }
  }
}

module "vm" {
  source = "../../modules/linux-vm"

  name                = "tf-int-vm"
  location            = var.location
  resource_group_name = azurerm_resource_group.this.name
  subnet_id           = module.network.subnet_ids["workload_private"]
  ssh_public_key      = tls_private_key.ssh.public_key_openssh
  size                = var.vm_size
  tags                = local.tags
}

module "vault" {
  source = "../../modules/key-vault"

  name                = "tfint${random_string.suffix.result}kv"
  location            = var.location
  resource_group_name = azurerm_resource_group.this.name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  tags                = local.tags

  # The runner has to reach the data plane to write the secret below.
  public_network_access_enabled = true

  # Short window so a failed run does not reserve the name for a fortnight.
  purge_protection_enabled   = false
  soft_delete_retention_days = 7
}

# Proves the vault really is RBAC-authorized: without this role the secret write
# below fails with a 403 even though the caller owns the subscription.
resource "azurerm_role_assignment" "secrets" {
  scope                = module.vault.key_vault_id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = data.azurerm_client_config.current.object_id
}

module "secret" {
  source = "../../modules/key-vault-secret"

  key_vault_id = module.vault.key_vault_id
  tags         = local.tags

  secrets = {
    integration-probe = {
      content_type = "text/plain"
    }
  }

  secret_values = {
    integration-probe = "not-a-real-secret-${random_string.suffix.result}"
  }

  # RBAC is eventually consistent; without this the first write races the grant.
  depends_on = [azurerm_role_assignment.secrets]
}
