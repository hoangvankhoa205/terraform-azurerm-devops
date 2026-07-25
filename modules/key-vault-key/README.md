# Key Vault key

Creates an RBAC-enabled Key Vault with purge protection and one RSA key. Public
network access is disabled by default.

## Two independent barriers stand between a caller and the key

Creating `azurerm_key_vault_key` is a **data-plane** call. It has to clear both
of these, and clearing one does nothing for the other:

1. **Authorization.** With `rbac_authorization_enabled` the vault ignores access
   policies entirely. The deployment principal needs **Key Vault Crypto
   Officer** on the vault or its resource group — `Owner` and `Contributor` are
   control-plane roles and grant no key operations at all. The module does not
   assign this: a module that grants its own caller a data-plane role would
   force every consumer to hold User Access Administrator. Assign it in the
   root, and expect to wait — Entra role assignments are eventually consistent,
   so a first apply that creates the assignment and the key together usually
   403s without a deliberate pause between them.

2. **Network reachability.** The ACL defaults to `Deny` and the public endpoint
   is off. Use a private endpoint and a connected runner for the normal path. A
   short-lived learning deployment through the public endpoint must explicitly
   allow only the runner address:

   ```hcl
   public_network_access_enabled = true
   network_acls = {
     ip_rules = [var.runner_public_ip]
   }
   ```

   Remove the public exception after deployment.

## Purge protection is a one-way door

`purge_protection_enabled` defaults to `true`, and **Azure does not allow
turning it off once a vault has it**. The consequence is easy to meet by
accident: a destroyed vault cannot be purged early, so its globally unique name
stays reserved for the whole `soft_delete_retention_days` window. In a
destroy-and-recreate loop that burns a name per iteration.

`soft_delete_retention_days` therefore defaults to `7`, the Azure minimum,
rather than the provider's `90`. Raise it for anything you actually care about.

Leave `purge_protection_enabled` alone for any vault holding a customer-managed
key — purging a key that encrypts live data makes that data unrecoverable, and
several Azure services refuse a CMK from a vault without purge protection. Set
it `false` only for throwaway vaults you expect to recreate under the same name.

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
| <a name="input_purge_protection_enabled"></a> [purge\_protection\_enabled](#input\_purge\_protection\_enabled) | Block permanent deletion until the soft-delete window expires. IRREVERSIBLE — Azure does not allow turning this off once a vault has it, so a destroyed vault cannot be purged early and its globally unique name stays reserved for soft\_delete\_retention\_days. Leave true for any vault holding a customer-managed key: purging a key that encrypts live data makes that data unrecoverable, and several Azure services require purge protection before they will accept a CMK. Set false only for throwaway vaults you expect to destroy and recreate under the same name. | `bool` | `true` | no |
| <a name="input_resource_group_name"></a> [resource\_group\_name](#input\_resource\_group\_name) | Existing resource group name. | `string` | n/a | yes |
| <a name="input_soft_delete_retention_days"></a> [soft\_delete\_retention\_days](#input\_soft\_delete\_retention\_days) | Days a deleted vault stays recoverable before it can be purged. With purge\_protection\_enabled the vault CANNOT be purged before this elapses, and the name is unusable for the whole window — so a long value is expensive in a destroy/recreate loop. Azure permits 7-90. | `number` | `7` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Resource tags. | `map(string)` | `{}` | no |
| <a name="input_tenant_id"></a> [tenant\_id](#input\_tenant\_id) | Microsoft Entra tenant ID. | `string` | n/a | yes |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_key_id"></a> [key\_id](#output\_key\_id) | Versioned Key Vault key ID. |
| <a name="output_key_vault_id"></a> [key\_vault\_id](#output\_key\_vault\_id) | Key Vault ID. |
| <a name="output_key_versionless_id"></a> [key\_versionless\_id](#output\_key\_versionless\_id) | Versionless key ID for services that track rotation. |
<!-- END_TF_DOCS -->