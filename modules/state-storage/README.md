# state-storage

A hardened Blob container for Terraform or OpenTofu remote state, with
versioning, soft delete, and Entra-only authentication.

## Usage

This is a bootstrap module: it creates the storage that *other* configurations
use as a backend. Apply it with local state first, then point the rest of your
estate at it.

```hcl
module "state" {
  source  = "hoangvankhoa205/devops/azurerm//modules/state-storage"
  version = "0.15.0"

  name                = "learnstate0001" # lowercase alphanumeric, globally unique
  location            = "Southeast Asia"
  resource_group_name = "learn-state-rg"
}

output "backend" {
  value = module.state.backend_example
}
```

Then in the root configuration that consumes it:

```hcl
terraform {
  backend "azurerm" {
    resource_group_name  = "learn-state-rg"
    storage_account_name = "learnstate0001"
    container_name       = "tfstate"
    key                  = "workload.tfstate"

    # Required: the shared account key is disabled on this account.
    use_azuread_auth = true
  }
}
```

A module cannot configure the backend of the root that uses it, so
`backend_example` hands back the three values to paste. It carries no secret —
there is no account key to carry.

## Locking needs nothing extra

The `azurerm` backend takes a **blob lease** on the state file, which is native
to Blob Storage. There is no separate lock table to create, and no equivalent of
the DynamoDB table an S3 backend needs.

A crashed apply can leave a lease held. `terraform force-unlock <id>` releases
it — check nothing else is actually running first.

## Shared-key auth is disabled, and that is the point

`shared_access_key_enabled` is hard-coded `false`. Every caller therefore
authenticates through Entra ID, which is what makes an OIDC-only pipeline
possible and means there is no account key that could leak and expose every
workspace's state at once.

The consequence is that **`use_azuread_auth = true` is not optional** in the
backend block, and whatever principal runs Terraform needs
`Storage Blob Data Contributor` on the account:

```hcl
resource "azurerm_role_assignment" "state" {
  scope                = module.state.storage_account_id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = module.ci_identity.principal_id
}
```

Note that control-plane rights are not enough: `Contributor` on the subscription
does **not** grant data-plane blob access.

## The firewall denies by default

`public_network_access_enabled` is `false` and `network_rules.default_action` is
always `Deny`. Nothing reaches the account until you make an exception.

```hcl
  public_network_access_enabled = true

  network_rules = {
    ip_rules = ["203.0.113.10"] # your egress address
  }
```

GitHub-hosted runners are the awkward case: their addresses change constantly,
so an IP allow-list is not workable. The options are a self-hosted runner with a
stable address, a Private Endpoint, or accepting a public endpoint protected by
Entra authorisation alone. Exceptions are additive — adding one never changes
`default_action` away from `Deny`.

## Recovering a broken state file

Versioning is on and soft delete keeps deleted blobs for `retention_days`
(14 by default, 7-365 permitted). Between them, a truncated or corrupted state
file can be rolled back to its previous version through the portal or
`az storage blob`. This is the single most useful property of the module, and
the reason not to lower the retention.

Replication defaults to `ZRS`, three copies across availability zones. Losing
state is far more expensive than the small premium over `LRS`.

## What this module leaves out

- **The resource group.** Create it first; it is the one thing that cannot be
  bootstrapped by this module.
- **The backend block**, which only a root configuration can declare.
- **Role assignments.**
- **Private Endpoints and DNS.**

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.9, < 2.0 |
| <a name="requirement_azurerm"></a> [azurerm](#requirement\_azurerm) | >= 4.81.0, < 5.0.0 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_azurerm"></a> [azurerm](#provider\_azurerm) | >= 4.81.0, < 5.0.0 |

## Resources

| Name | Type |
| ---- | ---- |
| [azurerm_storage_account.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/storage_account) | resource |
| [azurerm_storage_container.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/storage_container) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_location"></a> [location](#input\_location) | Azure region. | `string` | n/a | yes |
| <a name="input_name"></a> [name](#input\_name) | Globally unique storage account name. Lowercase letters and digits only — no hyphens, which is a common first-apply failure. | `string` | n/a | yes |
| <a name="input_resource_group_name"></a> [resource\_group\_name](#input\_resource\_group\_name) | Existing bootstrap resource group name. | `string` | n/a | yes |
| <a name="input_container_name"></a> [container\_name](#input\_container\_name) | Container the state blobs live in. One container holds many workspaces, separated by the backend's `key`, so there is rarely a reason to change this. | `string` | `"tfstate"` | no |
| <a name="input_network_rules"></a> [network\_rules](#input\_network\_rules) | Deny-by-default state storage exceptions for trusted runner IPs or connected subnets. | <pre>object({<br/>    bypass                     = optional(set(string), ["AzureServices"])<br/>    ip_rules                   = optional(set(string), [])<br/>    virtual_network_subnet_ids = optional(set(string), [])<br/>  })</pre> | `{}` | no |
| <a name="input_public_network_access_enabled"></a> [public\_network\_access\_enabled](#input\_public\_network\_access\_enabled) | Expose the storage public endpoint. When true, deny-by-default network\_rules still apply. | `bool` | `false` | no |
| <a name="input_replication_type"></a> [replication\_type](#input\_replication\_type) | Replication mode. ZRS keeps three copies across availability zones in the region and is the right default for state — losing state is far more expensive than the small premium over LRS. GRS adds a second region, but its secondary is only readable after a failover. | `string` | `"ZRS"` | no |
| <a name="input_retention_days"></a> [retention\_days](#input\_retention\_days) | How long a deleted state blob stays recoverable. Combined with versioning, this is the undo button for a corrupted apply. Azure permits 7-365. | `number` | `14` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Resource tags. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_backend_example"></a> [backend\_example](#output\_backend\_example) | The non-secret values an azurerm backend block needs, ready to paste. Resource group is included for convenience. A backend cannot be configured by a module, so this is a starting point for the root configuration rather than something applied here. |
| <a name="output_container_name"></a> [container\_name](#output\_container\_name) | State container name. |
| <a name="output_storage_account_id"></a> [storage\_account\_id](#output\_storage\_account\_id) | State storage account resource ID. Grant Storage Blob Data Contributor at this scope to whatever principal runs Terraform, since shared-key auth is disabled. |
| <a name="output_storage_account_name"></a> [storage\_account\_name](#output\_storage\_account\_name) | State storage account name. |
<!-- END_TF_DOCS -->