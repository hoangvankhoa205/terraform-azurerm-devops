# Key Vault key

Creates an RBAC-enabled Key Vault with purge protection and one RSA key. Public
network access is disabled by default. The deployment principal needs a Key
Vault cryptographic role before Azure can create the key; the module does not
grant itself broad access.

The vault network ACL always defaults to `Deny`. Use a private endpoint and a
connected runner for the normal path. A short-lived learning deployment through
the public endpoint must explicitly allow only the runner address:

```hcl
public_network_access_enabled = true
network_acls = {
  ip_rules = [var.runner_public_ip]
}
```

Remove the public exception after deployment; RBAC authorization and network
reachability are separate controls.

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

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [azurerm_key_vault.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/key_vault) | resource |
| [azurerm_key_vault_key.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/key_vault_key) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_key_name"></a> [key\_name](#input\_key\_name) | Key name. | `string` | `"learning-key"` | no |
| <a name="input_location"></a> [location](#input\_location) | Azure region. | `string` | n/a | yes |
| <a name="input_name"></a> [name](#input\_name) | Globally unique Key Vault name. | `string` | n/a | yes |
| <a name="input_network_acls"></a> [network\_acls](#input\_network\_acls) | Deny-by-default vault exceptions for trusted deployment IPs or connected subnets. | <pre>object({<br/>    bypass                     = optional(string, "AzureServices")<br/>    ip_rules                   = optional(set(string), [])<br/>    virtual_network_subnet_ids = optional(set(string), [])<br/>  })</pre> | `{}` | no |
| <a name="input_public_network_access_enabled"></a> [public\_network\_access\_enabled](#input\_public\_network\_access\_enabled) | Expose the Key Vault public endpoint. When true, deny-by-default network\_acls still apply. | `bool` | `false` | no |
| <a name="input_resource_group_name"></a> [resource\_group\_name](#input\_resource\_group\_name) | Existing resource group name. | `string` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | Resource tags. | `map(string)` | `{}` | no |
| <a name="input_tenant_id"></a> [tenant\_id](#input\_tenant\_id) | Microsoft Entra tenant ID. | `string` | n/a | yes |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_key_id"></a> [key\_id](#output\_key\_id) | Versioned Key Vault key ID. |
| <a name="output_key_vault_id"></a> [key\_vault\_id](#output\_key\_vault\_id) | Key Vault ID. |
| <a name="output_key_versionless_id"></a> [key\_versionless\_id](#output\_key\_versionless\_id) | Versionless key ID for services that track rotation. |
<!-- END_TF_DOCS -->