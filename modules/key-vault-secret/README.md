# Key Vault secret

Creates secrets in an **existing** vault, one per entry in a map. It does not
create a vault — pass the `key_vault_id` output of
[`key-vault`](../key-vault), so a single vault can hold secrets, keys and
certificates together.

## Usage

This example needs `hashicorp/random` in your root's `required_providers`
alongside `azurerm` — modules cannot declare providers for you.

```hcl
data "azurerm_client_config" "current" {}

resource "random_password" "db" {
  length  = 32
  special = true
}

module "vault" {
  source  = "hoangvankhoa205/devops/azurerm//modules/key-vault"
  version = "0.15.0"

  name                = "learn-kv-0001"
  location            = "Southeast Asia"
  resource_group_name = "learn-rg"
  tenant_id           = data.azurerm_client_config.current.tenant_id
}

module "secrets" {
  source  = "hoangvankhoa205/devops/azurerm//modules/key-vault-secret"
  version = "0.15.0"

  key_vault_id = module.vault.key_vault_id

  secrets = {
    db-username = {}
    db-password = { content_type = "password" }
  }
  secret_values = {
    db-username = "pgadmin"
    db-password = random_password.db.result
  }
}
```

## Why names and values are separate variables

This is a hard Terraform constraint, not a style choice.

`for_each` cannot accept a sensitive value, or anything derived from one. Pass
`random_password.db.result` into a combined map and that entire map becomes
sensitive, so `for_each = var.secrets` fails with *"Sensitive values, or values
derived from sensitive values, cannot be used as for_each arguments."* Since
handing over a generated password is the main reason to use this module, one
combined map would break in precisely the case it exists for.

So `secrets` carries names and metadata and drives `for_each`, staying
non-sensitive; `secret_values` carries the values and is marked sensitive. The
keys must match. A name in `secrets` with no matching entry in `secret_values`
fails with an index error naming the key.

## The values are in your state file

`sensitive = true` keeps values out of plan output and `terraform console`. It
does **not** keep them out of state, where they are stored in cleartext.

This catches people, because "put it in Key Vault" sounds like the secret stops
being in Terraform. It does not. The same is true reading the other direction:
`data "azurerm_key_vault_secret"` also lands the value in state.

Two honest responses:

- **Accept it and protect the state.** A remote backend with shared-key auth
  disabled and deny-by-default networking — what
  [`state-storage`](../state-storage) builds — is a reasonable answer, as long
  as it is a decision rather than an assumption.
- **Keep the value out of Terraform entirely.** For AKS, enable the Key Vault
  Secrets Provider CSI driver and let pods read secrets at runtime through
  workload identity. Terraform then manages the vault, the roles and the
  federation, and never sees a value.

There is deliberately no output for secret values, for the same reason.

## Writing secrets needs a role, and it is not the key one

The vault is RBAC-authorized, so writing a secret needs **Key Vault Secrets
Officer** on the vault or its resource group. `Key Vault Crypto Officer` grants
`Microsoft.KeyVault/vaults/keys/*` and nothing for secrets — a principal that
can create keys still gets a 403 here. Reading values back needs **Key Vault
Secrets User** at minimum.

Assign in the root and allow for propagation delay before the write.

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
| [azurerm_key_vault_secret.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/key_vault_secret) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_key_vault_id"></a> [key\_vault\_id](#input\_key\_vault\_id) | ID of an existing Key Vault, typically the key\_vault\_id output of the key-vault module. This module does not create a vault, so one vault can hold secrets, keys and certificates together. | `string` | n/a | yes |
| <a name="input_secret_values"></a> [secret\_values](#input\_secret\_values) | Secret values, keyed to match secrets. Marked sensitive so plan output and console never print them — but note the values still land in Terraform state in cleartext. Key Vault does not change that; protect the state file (remote backend, Entra-only access) or keep the value out of Terraform entirely. | `map(string)` | n/a | yes |
| <a name="input_secrets"></a> [secrets](#input\_secrets) | Secrets to create, keyed by secret name. Values live in secret\_values under the same keys — see that variable for why they are separate. | <pre>map(object({<br/>    content_type    = optional(string)<br/>    expiration_date = optional(string)<br/>    not_before_date = optional(string)<br/>    tags            = optional(map(string), {})<br/>  }))</pre> | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags applied to every secret, merged under each secret's own tags. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_secret_ids"></a> [secret\_ids](#output\_secret\_ids) | Versioned secret IDs, keyed by secret name. Pins the version that existed at apply time. |
| <a name="output_secret_names"></a> [secret\_names](#output\_secret\_names) | Names of the secrets created, for az CLI calls that take --name. |
| <a name="output_secret_versionless_ids"></a> [secret\_versionless\_ids](#output\_secret\_versionless\_ids) | Versionless secret IDs, keyed by secret name. Use these where a consumer should follow rotation rather than pin a version. |
<!-- END_TF_DOCS -->
