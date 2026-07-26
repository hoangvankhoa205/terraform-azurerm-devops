# container-registry

An Azure Container Registry with the local admin account disabled, so every
consumer authenticates through Entra ID rather than a shared password.

## Usage

```hcl
module "registry" {
  source  = "hoangvankhoa205/devops/azurerm//modules/container-registry"
  version = "0.15.0"

  name                = "learndevopsacr" # alphanumeric only, no hyphens
  location            = "Southeast Asia"
  resource_group_name = "learn-rg"
}
```

Then grant a workload the right to pull, using the identity a VM or scale set
already has:

```hcl
resource "azurerm_role_assignment" "pull" {
  scope                = module.registry.registry_id
  role_definition_name = "AcrPull"
  principal_id         = module.vm.principal_id
}
```

## The name has different rules from every other Azure resource

Registry names are alphanumeric only. No hyphens, no underscores, 5-50
characters. `learn-devops-acr` is rejected where the same string is fine for a
resource group, a VNet, or a VM — and the failure arrives at plan time from this
module's validation rather than partway through an apply.

The name also has to be globally unique, because it becomes the
`<name>.azurecr.io` login server that image references are written against.

## Why there is no `admin_enabled` variable

The registry admin account is a single username and password stored on the
registry itself. Every consumer shares it, it cannot be scoped to one
repository, and it bypasses Entra entirely — so a leaked pipeline log hands over
the whole registry with no way to attribute the access.

A managed identity holding `AcrPull` is the alternative, which is why the
setting is hard-coded to `false` rather than offered as a knob.

## Basic, Standard, and Premium are not just size tiers

Basic and Standard differ only in included storage and throughput. Premium is
the one that changes what is possible: **Private Endpoints, geo-replication,
customer-managed keys, and content trust are Premium-only.**

That matters because `public_network_access_enabled` defaults to `false` here.
On a Basic registry that produces a registry nothing can reach — there is no
Private Endpoint available to reach it by. Either set the SKU to `Premium` and
add a Private Endpoint, or opt into public access and rely on Entra for
authorisation.

## What this module leaves out

- **The Private Endpoint and `privatelink.azurecr.io` DNS zone.** A private
  registry needs both, and they are usually shared across a landing zone rather
  than owned by one registry.
- **Role assignments.** Grant `AcrPull` or `AcrPush` at `registry_id` yourself,
  so the module never needs to know about your identities.
- **Images.** This builds the registry, not what goes in it.
- **Retention and cleanup policies**, which are also Premium-only.

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
| [azurerm_container_registry.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/container_registry) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_location"></a> [location](#input\_location) | Azure region. | `string` | n/a | yes |
| <a name="input_name"></a> [name](#input\_name) | Globally unique registry name. Alphanumeric only — no hyphens, unlike almost every other Azure resource name, which is a common first-apply failure. It becomes the <name>.azurecr.io login server, so it has to be unique across all of Azure. | `string` | n/a | yes |
| <a name="input_resource_group_name"></a> [resource\_group\_name](#input\_resource\_group\_name) | Existing resource group name. | `string` | n/a | yes |
| <a name="input_public_network_access_enabled"></a> [public\_network\_access\_enabled](#input\_public\_network\_access\_enabled) | Allow the public data endpoint. Disabled by default. Reaching a private registry needs a Private Endpoint and a privatelink.azurecr.io DNS zone, neither of which this module creates, and both of which need the Premium SKU. | `bool` | `false` | no |
| <a name="input_sku"></a> [sku](#input\_sku) | Registry tier. Basic and Standard differ only in included storage and throughput. Premium is the one that changes what is possible: it is required for Private Endpoints, geo-replication, customer-managed keys, and content trust. Leaving public\_network\_access\_enabled false on a Basic registry therefore produces a registry nothing can reach. | `string` | `"Basic"` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Resource tags. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_login_server"></a> [login\_server](#output\_login\_server) | Registry login hostname, <name>.azurecr.io. This is the prefix an image reference needs — <login\_server>/<repository>:<tag> — and what `az acr login --name` resolves to. |
| <a name="output_registry_id"></a> [registry\_id](#output\_registry\_id) | Container registry resource ID. Grant AcrPull or AcrPush at this scope to let a managed identity authenticate, since the admin account is disabled. |
<!-- END_TF_DOCS -->