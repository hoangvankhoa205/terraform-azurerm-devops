# Container Registry

Creates an Azure Container Registry with its local admin account disabled.
Public network access is opt-in. A private registry also requires a Private
Endpoint and `privatelink.azurecr.io` DNS, which are intentionally left to the
production network composition.


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