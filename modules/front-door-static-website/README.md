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
| <a name="input_endpoint_name"></a> [endpoint\_name](#input\_endpoint\_name) | Front Door endpoint name. Unlike the profile name this DOES have to be globally unique: it becomes the public hostname, <endpoint\_name>.z01.azurefd.net. | `string` | n/a | yes |
| <a name="input_name"></a> [name](#input\_name) | Front Door profile name. Scoped to the resource group, so it does not need to be globally unique. | `string` | n/a | yes |
| <a name="input_origin_host_name"></a> [origin\_host\_name](#input\_origin\_host\_name) | Static website origin host, with no URL scheme — for example learnstaticweb001.z23.web.core.windows.net. Pass storage-static-website's primary\_web\_host output, NOT primary\_web\_endpoint: the latter is a full https:// URL and is rejected here. The value doubles as the origin host header, so the origin's TLS certificate is validated against it. | `string` | n/a | yes |
| <a name="input_resource_group_name"></a> [resource\_group\_name](#input\_resource\_group\_name) | Existing resource group name. | `string` | n/a | yes |
| <a name="input_sku_name"></a> [sku\_name](#input\_sku\_name) | Front Door tier. Standard covers a static site. Premium adds managed WAF rule sets, bot protection, and Private Link to the origin — the last of which is the only way to keep the storage account off the public Internet while Front Door still reaches it. Classic is retired and rejected. | `string` | `"Standard_AzureFrontDoor"` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Resource tags. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_endpoint_host_name"></a> [endpoint\_host\_name](#output\_endpoint\_host\_name) | Public hostname Front Door serves the site on, <endpoint\_name>.z01.azurefd.net. Azure allocates the middle segment, so it cannot be predicted before apply. Pass https://<this> to endpoint-test to verify the site end to end. |
| <a name="output_endpoint_id"></a> [endpoint\_id](#output\_endpoint\_id) | Front Door endpoint resource ID. |
| <a name="output_profile_id"></a> [profile\_id](#output\_profile\_id) | Front Door profile resource ID. Attach a WAF policy or a custom domain at this scope. |
<!-- END_TF_DOCS -->