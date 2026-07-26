# front-door-static-website

Puts Azure Front Door Standard/Premium in front of a Storage static website and
forces HTTPS, serving on the default `*.azurefd.net` hostname.

## Usage

Pair it with [`storage-static-website`](../storage-static-website), which
produces the origin hostname this module needs:

```hcl
module "site" {
  source  = "hoangvankhoa205/devops/azurerm//modules/storage-static-website"
  version = "0.15.0"

  name                          = "learnstaticweb001"
  location                      = "Southeast Asia"
  resource_group_name           = "learn-rg"
  public_network_access_enabled = true
}

module "cdn" {
  source  = "hoangvankhoa205/devops/azurerm//modules/front-door-static-website"
  version = "0.15.0"

  name                = "learn-frontdoor"
  endpoint_name       = "learn-static-endpoint-001" # globally unique
  resource_group_name = "learn-rg"

  # primary_web_host, NOT primary_web_endpoint — see below.
  origin_host_name = module.site.primary_web_host
}

output "site_url" {
  value = "https://${module.cdn.endpoint_host_name}"
}
```

## Pass the host, not the URL

`origin_host_name` wants a bare hostname —
`learnstaticweb001.z23.web.core.windows.net` — with no scheme. The storage
module exposes both forms, and they are easy to mix up:

| Output | Value | Use it for |
| --- | --- | --- |
| `primary_web_host` | `learnstaticweb001.z23.web.core.windows.net` | This module's `origin_host_name` |
| `primary_web_endpoint` | `https://learnstaticweb001.z23.web.core.windows.net/` | Browsing the origin directly, or `endpoint-test` |

Passing the endpoint URL is rejected by a validation here rather than producing
a Front Door that returns errors at runtime.

## Two settings that both say "HTTPS" and mean different things

- `https_redirect_enabled` governs the hop from the **visitor to Front Door**.
  It sends a plain-HTTP request back as a redirect to the HTTPS URL.
- `forwarding_protocol = "HttpsOnly"` governs the hop from **Front Door to the
  origin**. Without it, Front Door could serve a padlock to the visitor while
  fetching the page from Storage over plain HTTP.

Both are set. `supported_protocols` deliberately still includes `Http`, because
the edge has to accept the plain-HTTP request in order to redirect it — dropping
it would make those visitors fail instead.

The hop to the origin is also *verified*, not merely encrypted:
`certificate_name_check_enabled` is on, which works because the origin host
header is set to the same hostname the Storage certificate is issued for.

## Why five resources for one site

Front Door Standard/Premium models a site as a chain, and every link is
required:

```
profile ──owns──> endpoint (the public hostname)
   │
   ├──owns──> origin group (health probe + load balancing policy)
   │              └──owns──> origin (the storage account)
   │
   └── route ──joins──> endpoint + origin group
```

The origin group's numbers look arbitrary but are not: a `HEAD` probe against
`/` every 120 seconds keeps probe billing down against an origin that rarely
fails on its own, and requiring 3 of the last 4 samples stops a single slow
response taking the site offline while still recovering within a few intervals.

## The origin's firewall has to let Front Door in

This is the failure that looks like propagation but never resolves. Front Door
reaches the storage account **over the public Internet from Microsoft's edge**,
not over the Azure backbone, so a storage account with
`public_network_access_enabled = false` returns errors to Front Door forever.

`network_rules.bypass = ["AzureServices"]`, the storage module's default, does
**not** cover Front Door. There are two workable arrangements:

| Arrangement | What to do | Trade-off |
| --- | --- | --- |
| Public origin (what the example above does) | `public_network_access_enabled = true` on the storage module | The origin is reachable directly, bypassing Front Door |
| Private origin | Front Door **Premium** plus a Private Link origin connection | Keeps the origin off the Internet; needs Premium and a manual approval |

This module creates no Private Link connection, so the public-origin
arrangement is the one it supports out of the box. Locking the origin down
properly is a Premium exercise left to the caller.

Symptom check: if the Front Door hostname returns errors but
`https://<primary_web_endpoint>` also fails from your machine, the problem is
the origin firewall, not Front Door.

## Propagation is slow, and the site is not instantly live

A Front Door apply typically takes several minutes, and the endpoint keeps
answering with errors for a while after Terraform reports success. If you chain
[`endpoint-test`](../endpoint-test) onto this, expect the first run to fail on a
fresh deployment — that is Front Door still propagating, not a broken
configuration.

## What this module leaves out

- **Custom domains and managed certificates.** The site serves on
  `*.azurefd.net` only.
- **WAF policies.** These need Premium and a separate policy resource.
- **Private Link to the origin**, the only way to keep the storage account off
  the public Internet while Front Door still reaches it. Also Premium-only.
- **Caching rules and rule sets.** The route ships with defaults.
- **Multiple origins.** `priority` and `weight` are set to the single-origin
  defaults.

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