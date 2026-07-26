# State storage

Bootstraps a private Blob container with versioning, soft delete, TLS 1.2, and
shared-key authentication disabled. Blob leases provide native state locking;
Azure does not need a DynamoDB equivalent. Authenticate the backend with Entra
ID/OIDC. A private endpoint requires a network-connected runner, so public
GitHub-hosted runners normally need a carefully restricted public endpoint.

The firewall always defaults to `Deny`. A connected runner can use an allowed
subnet; a temporary fixed-egress runner can opt in explicitly:

```hcl
public_network_access_enabled = true
network_rules = {
  ip_rules = [var.runner_public_ip]
}
```

Do not use an unrestricted public rule. Public GitHub-hosted runner addresses
change, so prefer a private or static-egress self-hosted runner for state.

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