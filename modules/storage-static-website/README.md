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
Entra-authenticated deployment step. This module manages infrastructure, not
website files.

## Usage

```hcl
module "site" {
  source  = "hoangvankhoa205/devops/azurerm//modules/storage-static-website"
  version = "0.15.0"

  name                = "learnstaticweb001" # lowercase alphanumeric, globally unique
  location            = "Southeast Asia"
  resource_group_name = "learn-rg"

  # A single-page app usually wants the 404 document pointed back at index.html
  # so client-side routing works.
  index_document     = "index.html"
  error_404_document = "404.html"

  # Required for anyone — including Front Door — to reach the site. The default
  # is false, which builds a website nothing can load.
  public_network_access_enabled = true
}
```

Serve it through a CDN with a real HTTPS endpoint by passing `primary_web_host`
— the bare hostname, not `primary_web_endpoint` — to
[`front-door-static-website`](../front-door-static-website):

```hcl
module "cdn" {
  source  = "hoangvankhoa205/devops/azurerm//modules/front-door-static-website"
  version = "0.15.0"

  name                = "learn-frontdoor"
  endpoint_name       = "learn-static-endpoint-001"
  resource_group_name = "learn-rg"
  origin_host_name    = module.site.primary_web_host
}
```

## Uploading content

Enabling static website hosting is what creates the implicit `$web` container,
so anything writing into it must be ordered after that. Use `web_container_id`
and Terraform derives the ordering on its own:

```hcl
resource "azurerm_storage_blob" "index" {
  name                 = "index.html"
  storage_container_id = module.site.web_container_id
  type                 = "Block"
  content_type         = "text/html"
  source               = "site/index.html"
}
```

Do not build the ID out of `storage_account_id` instead. That expression
depends only on the storage account, so Terraform is free to schedule the blob
write alongside the enablement rather than after it, and the apply fails with
`404 ContainerNotFound`. Both outputs produce the same string — Azure gives the
static website resource the account's own ID — but only `web_container_id`
carries the dependency.

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
| [azurerm_storage_account_static_website.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/storage_account_static_website) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_location"></a> [location](#input\_location) | Azure region. | `string` | n/a | yes |
| <a name="input_name"></a> [name](#input\_name) | Globally unique storage account name. | `string` | n/a | yes |
| <a name="input_resource_group_name"></a> [resource\_group\_name](#input\_resource\_group\_name) | Existing resource group name. | `string` | n/a | yes |
| <a name="input_error_404_document"></a> [error\_404\_document](#input\_error\_404\_document) | 404 page filename. | `string` | `"404.html"` | no |
| <a name="input_index_document"></a> [index\_document](#input\_index\_document) | Default page filename. | `string` | `"index.html"` | no |
| <a name="input_network_rules"></a> [network\_rules](#input\_network\_rules) | Deny-by-default static website exceptions for trusted client IPs or connected subnets. | <pre>object({<br/>    bypass                     = optional(set(string), ["AzureServices"])<br/>    ip_rules                   = optional(set(string), [])<br/>    virtual_network_subnet_ids = optional(set(string), [])<br/>  })</pre> | `{}` | no |
| <a name="input_public_network_access_enabled"></a> [public\_network\_access\_enabled](#input\_public\_network\_access\_enabled) | Expose the static website public endpoint. When true, deny-by-default network\_rules still apply. | `bool` | `false` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Resource tags. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_primary_web_endpoint"></a> [primary\_web\_endpoint](#output\_primary\_web\_endpoint) | Static website HTTPS endpoint. |
| <a name="output_primary_web_host"></a> [primary\_web\_host](#output\_primary\_web\_host) | Static website origin hostname. |
| <a name="output_storage_account_id"></a> [storage\_account\_id](#output\_storage\_account\_id) | Storage account ID. |
| <a name="output_web_container_id"></a> [web\_container\_id](#output\_web\_container\_id) | ID of the implicit $web container. Prefer this over composing the ID from storage\_account\_id: it is anchored on the static website resource, so blob writes are ordered after hosting is enabled. |
<!-- END_TF_DOCS -->