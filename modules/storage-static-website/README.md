# Storage static website

Enables Azure Storage static website hosting with HTTPS and shared-key access
disabled. The public endpoint is disabled and its firewall defaults to `Deny`.
For a narrow learning-only client path, opt in explicitly:

```hcl
public_network_access_enabled = true
network_rules = {
  ip_rules = [var.trusted_client_ip]
}
```

Static website content is anonymous to clients that pass the network boundary;
blob container public ACLs remain disabled. Upload content through an
Entra-authenticated deployment step. A global Front Door composition should use
the production storage/edge modules with Private Link rather than broad origin
firewall exceptions. This module manages infrastructure, not website files.

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
| [azurerm_storage_account.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/storage_account) | resource |
| [azurerm_storage_account_static_website.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/storage_account_static_website) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_error_404_document"></a> [error\_404\_document](#input\_error\_404\_document) | 404 page filename. | `string` | `"404.html"` | no |
| <a name="input_index_document"></a> [index\_document](#input\_index\_document) | Default page filename. | `string` | `"index.html"` | no |
| <a name="input_location"></a> [location](#input\_location) | Azure region. | `string` | n/a | yes |
| <a name="input_name"></a> [name](#input\_name) | Globally unique storage account name. | `string` | n/a | yes |
| <a name="input_network_rules"></a> [network\_rules](#input\_network\_rules) | Deny-by-default static website exceptions for trusted client IPs or connected subnets. | <pre>object({<br/>    bypass                     = optional(set(string), ["AzureServices"])<br/>    ip_rules                   = optional(set(string), [])<br/>    virtual_network_subnet_ids = optional(set(string), [])<br/>  })</pre> | `{}` | no |
| <a name="input_public_network_access_enabled"></a> [public\_network\_access\_enabled](#input\_public\_network\_access\_enabled) | Expose the static website public endpoint. When true, deny-by-default network\_rules still apply. | `bool` | `false` | no |
| <a name="input_resource_group_name"></a> [resource\_group\_name](#input\_resource\_group\_name) | Existing resource group name. | `string` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | Resource tags. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_primary_web_endpoint"></a> [primary\_web\_endpoint](#output\_primary\_web\_endpoint) | Static website HTTPS endpoint. |
| <a name="output_primary_web_host"></a> [primary\_web\_host](#output\_primary\_web\_host) | Static website origin hostname. |
| <a name="output_storage_account_id"></a> [storage\_account\_id](#output\_storage\_account\_id) | Storage account ID. |
<!-- END_TF_DOCS -->