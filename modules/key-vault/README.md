# Key Vault

An RBAC-authorized Key Vault and nothing else. Public network access is
disabled by default and the network ACL defaults to `Deny`.

Keys, secrets and certificates belong to the caller, the same way
[`storage-static-website`](../storage-static-website) builds the hosting and
leaves the pages to the root. One vault can then hold whatever mix of objects a
workload needs, instead of each object type dragging its own vault along.

Pair it with [`key-vault-secret`](../key-vault-secret), or manage
`azurerm_key_vault_key` / `_secret` / `_certificate` directly in your root.

## Which of the three vault modules to use

The difference is not RBAC, and it is not an Azure restriction — a single
Azure vault has always held keys, secrets and certificates side by side. The
modules differ only in which Terraform resources they create:

| Module | Creates | Needs an existing vault? |
| ------ | ------- | ------------------------ |
| `key-vault` | `azurerm_key_vault` | no |
| [`key-vault-key`](../key-vault-key) | `azurerm_key_vault` **and** `azurerm_key_vault_key` | no |
| [`key-vault-secret`](../key-vault-secret) | `azurerm_key_vault_secret` per entry | **yes** — takes `key_vault_id` |

So the only combination that fails is two modules that each create a vault:

```
key-vault                          empty vault; add objects in your root
key-vault + key-vault-secret       one vault with secrets              OK
key-vault-key + key-vault-secret   one vault with a key AND secrets    OK
key-vault + key-vault-key          two separate vaults                 NO
```

Reach for `key-vault-key` when a customer-managed key is the point and you want
it in one call; it exposes `key_vault_id` too, so secrets can still be added
alongside. Reach for **this** module when the vault holds no key, or when you
want the key managed explicitly in your own root.

## Two independent barriers stand between a caller and the data plane

`rbac_authorization_enabled` is hardcoded `true`, so the vault ignores access
policies entirely and every data-plane call is authorized by Entra roles. That
is a defining property of this module rather than a setting: access-policy mode
would need an `access_policy` interface this module deliberately does not have.

Creating or reading vault *contents* therefore has to clear two separate
checks, and clearing one does nothing for the other. Both surface as a 403,
which is what makes them confusing:

1. **Authorization.** Control-plane `Owner` and `Contributor` grant **zero**
   data-plane operations. The principal needs a role matching the object type —
   `Key Vault Crypto Officer` for keys, `Key Vault Secrets Officer` to write
   secrets, `Key Vault Secrets User` to read them. Crypto Officer does not
   cover secrets, and vice versa.

   The module does not assign these: a module that grants its own caller a
   data-plane role would force every consumer to hold User Access
   Administrator. Assign in the root, and expect to wait — Entra assignments
   are eventually consistent, so an apply that creates the assignment and uses
   it in the same run usually 403s without a deliberate pause.

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

## Purge protection is a one-way door

`purge_protection_enabled` defaults to `true`, and **Azure does not allow
turning it off once a vault has it**. A destroyed vault cannot be purged early,
so its globally unique name stays reserved for the whole
`soft_delete_retention_days` window. In a destroy-and-recreate loop that burns
a name per iteration.

`soft_delete_retention_days` therefore defaults to `7`, the Azure minimum,
rather than the provider's `90`.

Leave purge protection on for any vault holding a customer-managed key —
purging a key that encrypts live data makes that data unrecoverable, and
several Azure services refuse a CMK from a vault without it. A vault holding
only secrets has no such requirement, so `false` is defensible there when the
name needs to be reusable.

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
| [azurerm_key_vault.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/key_vault) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_location"></a> [location](#input\_location) | Azure region. | `string` | n/a | yes |
| <a name="input_name"></a> [name](#input\_name) | Globally unique Key Vault name. | `string` | n/a | yes |
| <a name="input_resource_group_name"></a> [resource\_group\_name](#input\_resource\_group\_name) | Existing resource group name. | `string` | n/a | yes |
| <a name="input_tenant_id"></a> [tenant\_id](#input\_tenant\_id) | Microsoft Entra tenant ID. | `string` | n/a | yes |
| <a name="input_network_acls"></a> [network\_acls](#input\_network\_acls) | Deny-by-default vault exceptions for trusted deployment IPs or connected subnets. | <pre>object({<br/>    bypass                     = optional(string, "AzureServices")<br/>    ip_rules                   = optional(set(string), [])<br/>    virtual_network_subnet_ids = optional(set(string), [])<br/>  })</pre> | `{}` | no |
| <a name="input_public_network_access_enabled"></a> [public\_network\_access\_enabled](#input\_public\_network\_access\_enabled) | Expose the Key Vault public endpoint. When true, deny-by-default network\_acls still apply. | `bool` | `false` | no |
| <a name="input_purge_protection_enabled"></a> [purge\_protection\_enabled](#input\_purge\_protection\_enabled) | Block permanent deletion until the soft-delete window expires. IRREVERSIBLE — Azure does not allow turning this off once a vault has it, so a destroyed vault cannot be purged early and its globally unique name stays reserved for soft\_delete\_retention\_days. Required by services that accept a customer-managed key. Set false only for throwaway vaults you expect to destroy and recreate under the same name. | `bool` | `true` | no |
| <a name="input_soft_delete_retention_days"></a> [soft\_delete\_retention\_days](#input\_soft\_delete\_retention\_days) | Days a deleted vault stays recoverable before it can be purged. With purge\_protection\_enabled the vault CANNOT be purged before this elapses, and the name is unusable for the whole window — so a long value is expensive in a destroy/recreate loop. Azure permits 7-90. | `number` | `7` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Resource tags. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_key_vault_id"></a> [key\_vault\_id](#output\_key\_vault\_id) | Key Vault ID. Pass this to key-vault-secret, or to any azurerm\_key\_vault\_key / \_secret / \_certificate the caller manages directly. |
| <a name="output_name"></a> [name](#output\_name) | Vault name, for az CLI calls that take --vault-name rather than an ID. |
| <a name="output_vault_uri"></a> [vault\_uri](#output\_vault\_uri) | Data-plane URI, https://<name>.vault.azure.net/. What an application or the Secrets Store CSI driver talks to. |
<!-- END_TF_DOCS -->
