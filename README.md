# AzureRM DevOps Module Collection

Reusable AzureRM implementations of the infrastructure concepts demonstrated by
[`brikis98/terraform-book-devops`](https://github.com/brikis98/terraform-book-devops).
This is an independent community module collection: it is not an official
Azure Verified Module and is not affiliated with the original project.

> **Status: early work in progress.** Sixteen modules, listed under
> [Modules](#modules). The API may still change between minor versions — see
> [Versioning](#versioning) before pinning.

The root module deliberately creates no resources. Pick a module from
[`modules/`](./modules) and compose it in your own root configuration.

## Contents

- [Prerequisites](#prerequisites)
- [Getting started](#getting-started)
- [Composing modules](#composing-modules)
- [Safety boundary](#safety-boundary)
- [Modules](#modules)
- [Testing](#testing)
- [Compatibility](#compatibility)
- [Versioning](#versioning)
- [Contributing](#contributing)
- [Roadmap](#roadmap)
- [License](#license)

## Prerequisites

- Terraform `>= 1.9` or OpenTofu `>= 1.9`.
- An Azure subscription, and the Azure CLI logged in (`az login`) or a service
  principal configured through the usual `ARM_*` environment variables. For
  keyless CI see
  [`github-actions-federated-identity`](./modules/github-actions-federated-identity),
  which covers the `ARM_USE_OIDC` setup `azure/login` does not do for you.
- **A resource group.** No module creates one, so a caller keeps control of
  where resources land and what gets destroyed together. Create it first, in
  the shell or in your root configuration:

  ```sh
  az group create --name learn-rg --location "Southeast Asia"
  ```

  ```hcl
  resource "azurerm_resource_group" "learn" {
    name     = "learn-rg"
    location = "Southeast Asia"
  }
  ```

## Getting started

The repository name `terraform-azurerm-devops` produces the Terraform Registry
package address `hoangvankhoa205/devops/azurerm`. Individual modules live under
`//modules/<name>`.

```hcl
module "network" {
  source  = "hoangvankhoa205/devops/azurerm//modules/virtual-network"
  version = "0.15.0"

  name                = "learn-vnet"
  location            = "Southeast Asia"
  resource_group_name = "learn-rg"
  address_space       = ["10.42.0.0/16"]

  subnets = {
    workload_private = { address_prefixes = ["10.42.1.0/24"] }
  }
}

module "vm" {
  source  = "hoangvankhoa205/devops/azurerm//modules/linux-vm"
  version = "0.15.0"

  name                = "learn-vm"
  location            = "Southeast Asia"
  resource_group_name = "learn-rg"
  subnet_id           = module.network.subnet_ids["workload_private"]
  ssh_public_key      = file("~/.ssh/id_ed25519.pub")
}
```

Modules configure no provider and no backend. Declare both in your root
configuration:

```hcl
terraform {
  required_version = ">= 1.9, < 2.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 4.81.0, < 5.0.0"
    }
  }
}

provider "azurerm" {
  features {}
}
```

Two modules need a provider beyond `azurerm`, and you must declare it yourself
because modules cannot: [`endpoint-test`](./modules/endpoint-test) needs
`hashicorp/http`, and the [`key-vault-secret`](./modules/key-vault-secret)
example uses `hashicorp/random` to generate a password. Neither is pulled in for
you.

### Remote state

[`state-storage`](./modules/state-storage) is the usual first apply. It is a
bootstrap: apply it with local state, then move your state into it.

```hcl
terraform {
  backend "azurerm" {
    resource_group_name  = "learn-state-rg"
    storage_account_name = "learnstate0001"
    container_name       = "tfstate"
    key                  = "workload.tfstate"

    # Required. The module disables the shared account key, so without this
    # every state operation fails with a 403 that looks like a missing role.
    use_azuread_auth = true
  }
}
```

```sh
terraform init -migrate-state
```

## Composing modules

Most modules are deliberately small and expect to be wired together. The common
paths:

| Goal | Chain |
| --- | --- |
| Remote state before anything else | [`state-storage`](./modules/state-storage) → your root's `backend "azurerm"` block |
| A private VM | [`virtual-network`](./modules/virtual-network) → [`linux-vm`](./modules/linux-vm) |
| A private database | [`virtual-network`](./modules/virtual-network) (delegated subnet) → [`postgresql-flexible-server`](./modules/postgresql-flexible-server) |
| A public static site | [`storage-static-website`](./modules/storage-static-website) → [`front-door-static-website`](./modules/front-door-static-website) → [`endpoint-test`](./modules/endpoint-test) |
| Secrets for a workload | [`key-vault`](./modules/key-vault) → [`key-vault-secret`](./modules/key-vault-secret) / [`key-vault-certificate`](./modules/key-vault-certificate) |
| Keyless CI/CD from GitHub | [`github-actions-federated-identity`](./modules/github-actions-federated-identity) → [`github-actions-rbac`](./modules/github-actions-rbac) |

A worked example of the last chain, which is the one most people want first:

```hcl
module "state" {
  source  = "hoangvankhoa205/devops/azurerm//modules/state-storage"
  version = "0.15.0"

  name                = "learnstate0001"
  location            = "Southeast Asia"
  resource_group_name = "learn-state-rg"
}

# An identity GitHub Actions can assume with no stored secret.
module "ci_identity" {
  source  = "hoangvankhoa205/devops/azurerm//modules/github-actions-federated-identity"
  version = "0.15.0"

  name                = "learn-gh-dev"
  location            = "Southeast Asia"
  resource_group_name = "learn-identity-rg"
  subject             = "repo:your-org/your-repo:environment:dev"
}

# It starts with no permissions at all; grant them narrowly.
module "ci_rbac" {
  source  = "hoangvankhoa205/devops/azurerm//modules/github-actions-rbac"
  version = "0.15.0"

  principal_id = module.ci_identity.principal_id

  assignments = {
    state = {
      scope                = module.state.storage_account_id
      role_definition_name = "Storage Blob Data Contributor"
    }
  }
}
```

Two things then catch people out on the first run, both covered in
[`github-actions-federated-identity`](./modules/github-actions-federated-identity):
the workflow job must declare `environment: dev` for the token to carry the
subject above, and `azure/login` authenticates the Azure CLI but **not** the
`azurerm` provider, which needs `ARM_USE_OIDC` set separately.

Note also that `client_id`, `principal_id` and `tenant_id` are three different
values: `azure/login` wants the client id, `github-actions-rbac` wants the
principal id, and the tenant id identifies your Entra tenant rather than this
identity.

## Safety boundary

These modules are intentionally concise so callers can compose each Azure
resource. They avoid embedded credentials, public-by-default VM NICs, and
implicit resource-group creation. The `linux-vm` public IP is opt-in and does
not open ingress by itself. These are reference components, not a complete
production landing zone.

Each module's README has a section on what it deliberately leaves out. Read it
before assuming a module is production-ready.

## Modules

| Module | Description |
| ------ | ----------- |
| [`linux-vm`](./modules/linux-vm) | One Ubuntu VM with SSH-key-only auth and a system-assigned managed identity. Private NIC by default; `public_ip_enabled` is opt-in and does not open an NSG rule. |
| [`linux-vms`](./modules/linux-vms) | Multiple private Ubuntu VMs from a `for_each` map of instance definitions. SSH-key-only auth and a managed identity per VM; no public IP. |
| [`vm-scale-set`](./modules/vm-scale-set) | A private Linux VM Scale Set with SSH-key-only auth and a system-assigned managed identity. Manual upgrade mode and no public instance IPs; configurable instance count, SKU, and zones. |
| [`state-storage`](./modules/state-storage) | Hardened Blob container for Terraform/OpenTofu remote state: versioning, soft delete, TLS 1.2, shared-key auth disabled (Entra ID/OIDC only), and deny-by-default networking. Blob leases provide native state locking. |
| [`front-door-static-website`](./modules/front-door-static-website) | Fronts a Storage static-website origin with Front Door Standard/Premium and forces HTTPS. Serves on the default `*.azurefd.net` hostname; custom domain, WAF, and Private Link are left to the caller. |
| [`virtual-network`](./modules/virtual-network) | A VNet with subnets from a `for_each` map keyed by role, each with an auto-created NSG and association. Supports per-subnet service endpoints, delegation, and opt-in default outbound access. |
| [`postgresql-flexible-server`](./modules/postgresql-flexible-server) | A private, delegated-subnet PostgreSQL Flexible Server with point-in-time-restore backups. The caller supplies the admin password from a secret store; it is never output. HA standby is opt-in and is not a readable replica. |
| [`container-registry`](./modules/container-registry) | An Azure Container Registry with the local admin account disabled, so callers authenticate with Entra ID. Public network access is opt-in; the Private Endpoint and `privatelink.azurecr.io` DNS a private registry needs are left to the caller. |
| [`storage-static-website`](./modules/storage-static-website) | A Storage account with static website hosting, TLS 1.2, and shared-key auth disabled (Entra ID/OIDC only). The public endpoint is opt-in and the firewall denies by default; the module manages hosting configuration, not website files. |
| [`endpoint-test`](./modules/endpoint-test) | Post-deployment HTTP verification: a `check` block asserting a URL returns an expected status. Creates no Azure resources and is the only module needing a provider other than `azurerm`. A wrong status is a warning, not an apply failure. |
| [`key-vault`](./modules/key-vault) | An RBAC-authorized Key Vault and nothing else — keys, secrets and certificates are the caller's. Use it when the vault holds no key, or when you want the key managed explicitly in your root. It cannot be combined with `key-vault-key`, since both create a vault. |
| [`key-vault-key`](./modules/key-vault-key) | An RBAC-authorized Key Vault with purge protection and one RSA key, for customer-managed encryption. Public access is opt-in and the ACL denies by default. Purge protection is irreversible: a destroyed vault's name stays reserved for the soft-delete window. |
| [`key-vault-secret`](./modules/key-vault-secret) | Secrets in an existing vault, one per entry in a map. Takes a `key_vault_id` and creates no vault. Names and values are separate variables because `for_each` rejects sensitive values. |
| [`key-vault-certificate`](./modules/key-vault-certificate) | A certificate Key Vault issues, in an existing vault. Self-signed by default. Exposes the certificate's backing SECRET id — the thing an Application Gateway listener consumes, not the certificate id. Importing an existing PFX is out of scope. |
| [`github-actions-federated-identity`](./modules/github-actions-federated-identity) | A user-assigned managed identity trusting one exact GitHub OIDC subject, so Actions authenticates to Azure with no stored client secret. Grants no Azure role — pair it with `github-actions-rbac`. Wildcard and repo-only subjects are rejected. |
| [`github-actions-rbac`](./modules/github-actions-rbac) | Named Azure roles at explicit scopes for an existing managed identity, one assignment per entry in a map. Rejects `Owner` and an empty map. Creates no identity; takes a `principal_id`. RBAC propagation is eventually consistent. |

## Testing

Every module ships a suite of native `terraform test` cases that mock their
providers, so they reach no Azure API, need no credentials, and cost nothing.

```sh
cd modules/linux-vm
terraform init -backend=false
terraform test
```

Two modules keep a second suite under `tests-terraform/`, holding assertions
that need an instance-keyed `override_resource`. OpenTofu cannot parse that, so
those files live outside the default test directory and Terraform runs them
separately:

```sh
terraform test -test-directory=tests-terraform
```

CI runs `fmt`, `validate`, `tflint`, and the full suite for every module on both
Terraform and OpenTofu, and fails if the generated README tables have drifted
from `variables.tf`. Regenerate those with:

```sh
for m in modules/*/; do terraform-docs -c .terraform-docs.yml "$m"; done
```

## Compatibility

- Terraform `>= 1.9, < 2.0`
- OpenTofu `>= 1.9, < 2.0`
- AzureRM `>= 4.81.0, < 5.0.0`
- HTTP `>= 3.5.0, < 4.0.0` — `endpoint-test` only; every other module needs
  AzureRM alone

Modules configure no providers or backends. Configure those only in a root
module — including `hashicorp/http` if you use `endpoint-test`, and
`hashicorp/random` if you follow the `key-vault-secret` example.

## Versioning

Semantic versioning, but still on `0.x`: **a minor bump may break you.** Pin an
exact version rather than a range until this reaches `1.0.0`.

`1.0.0` is deliberately gated. The release workflow refuses to cut a stable
major until there is credentialed Azure integration evidence, because a suite of
mocked plans proves that configuration is wired correctly, not that Azure
accepts it.

## Contributing

Issues and pull requests are welcome. Before opening one:

1. `terraform fmt -recursive .`
2. `terraform test` in every module you touched, plus
   `terraform test -test-directory=tests-terraform` where that directory exists.
3. Regenerate the docs (see [Testing](#testing)) and commit the result — CI
   fails on drift.
4. Add a test for the behaviour you changed. A new variable needs a case
   proving it reaches the resource; a new validation needs an `expect_failures`
   run proving it fires.

Test conventions worth matching: `run` names read as sentences
(`rejects_underscore_in_name`), and a comment above a non-obvious run explains
why the behaviour matters rather than what the code does.

## Roadmap

Planned modules (not yet implemented). This list is aspirational and will
change:

- `aks-cluster`

## License

[MIT](./LICENSE).
