# Endpoint test

A provider-neutral HTTP data source plus a `check` assertion. It demonstrates
post-deployment verification but does not replace retries, authentication, TLS
inspection, or an application test suite. The response body output is marked
sensitive to reduce accidental disclosure.

This is the only module in the collection that creates no Azure resources, and
the only one that needs a provider other than `azurerm`.

## The two failure modes are not equally loud

| What went wrong | Terraform reports | `apply` exit code |
| --------------- | ----------------- | ----------------- |
| Endpoint reachable, wrong status | Check block warning | **0** |
| Endpoint unreachable — DNS, TLS, timeout | Data source error | **1** |

A failed `check` assertion is a **warning**. It does not fail `terraform apply`,
does not change the exit code, and does not roll anything back. That is
deliberate — verification running inside the same apply that built the thing
should not leave a half-applied root — but it means this module *gates* on
reachability while only *observing* status.

Read the consequence before relying on this in automation: a pipeline step that
runs `terraform apply` and checks only the exit code will pass while the site
serves 500s. If you need a hard failure on status, assert on the `status_code`
output from a `terraform test` run, or scan the apply output for warnings.

The data source is read on every plan and apply, so a drifted endpoint surfaces
without a code change. Note the corollary: an endpoint that goes unreachable
starts failing every plan, including plans for unrelated changes.

## Usage

```hcl
module "site_up" {
  source  = "hoangvankhoa205/devops/azurerm//modules/endpoint-test"
  version = "0.12.0"

  url = module.static_site.primary_web_endpoint
}
```

Pair it with the module whose output it verifies — referencing that output is
also what orders the request after the thing exists.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.9, < 2.0 |
| <a name="requirement_http"></a> [http](#requirement\_http) | >= 3.5.0, < 4.0.0 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_http"></a> [http](#provider\_http) | >= 3.5.0, < 4.0.0 |

## Resources

| Name | Type |
| ---- | ---- |
| [http_http.this](https://registry.terraform.io/providers/hashicorp/http/latest/docs/data-sources/http) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_url"></a> [url](#input\_url) | HTTP(S) URL to test. | `string` | n/a | yes |
| <a name="input_expected_status"></a> [expected\_status](#input\_expected\_status) | Expected HTTP status code. | `number` | `200` | no |
| <a name="input_request_headers"></a> [request\_headers](#input\_request\_headers) | Optional request headers; do not put long-lived secrets in configuration. | `map(string)` | `{}` | no |
| <a name="input_timeout_ms"></a> [timeout\_ms](#input\_timeout\_ms) | Request timeout in milliseconds. | `number` | `5000` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_response_body"></a> [response\_body](#output\_response\_body) | Observed response body; treat it as potentially sensitive application data. |
| <a name="output_status_code"></a> [status\_code](#output\_status\_code) | Observed HTTP status code. |
<!-- END_TF_DOCS -->
