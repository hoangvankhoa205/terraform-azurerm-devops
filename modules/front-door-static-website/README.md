# Front Door static website

Places a Storage static website origin behind Front Door Standard/Premium and
redirects clients to HTTPS. Front Door Classic is intentionally unsupported.
Production should add WAF policy, custom domain/certificate, access logs, and
Premium Private Link where the origin must not be public.


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
| [azurerm_cdn_frontdoor_endpoint.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/cdn_frontdoor_endpoint) | resource |
| [azurerm_cdn_frontdoor_origin.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/cdn_frontdoor_origin) | resource |
| [azurerm_cdn_frontdoor_origin_group.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/cdn_frontdoor_origin_group) | resource |
| [azurerm_cdn_frontdoor_profile.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/cdn_frontdoor_profile) | resource |
| [azurerm_cdn_frontdoor_route.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/cdn_frontdoor_route) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_endpoint_name"></a> [endpoint\_name](#input\_endpoint\_name) | Globally unique Front Door endpoint name. | `string` | n/a | yes |
| <a name="input_name"></a> [name](#input\_name) | Front Door profile name. | `string` | n/a | yes |
| <a name="input_origin_host_name"></a> [origin\_host\_name](#input\_origin\_host\_name) | Static website origin host without a URL scheme. | `string` | n/a | yes |
| <a name="input_resource_group_name"></a> [resource\_group\_name](#input\_resource\_group\_name) | Existing resource group name. | `string` | n/a | yes |
| <a name="input_sku_name"></a> [sku\_name](#input\_sku\_name) | Front Door Standard or Premium SKU. | `string` | `"Standard_AzureFrontDoor"` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Resource tags. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_endpoint_host_name"></a> [endpoint\_host\_name](#output\_endpoint\_host\_name) | Front Door default hostname. |
| <a name="output_endpoint_id"></a> [endpoint\_id](#output\_endpoint\_id) | Front Door endpoint ID. |
| <a name="output_profile_id"></a> [profile\_id](#output\_profile\_id) | Front Door profile ID. |
<!-- END_TF_DOCS -->