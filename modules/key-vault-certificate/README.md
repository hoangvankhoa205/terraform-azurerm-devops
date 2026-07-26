# Key Vault certificate

A certificate that **Key Vault issues**, in an existing vault. Pass the
`key_vault_id` output of [`key-vault`](../key-vault); this module creates no
vault, so one vault can hold certificates alongside keys and secrets.

## Usage

`module.vault` below is a [`key-vault`](../key-vault) (or
[`key-vault-key`](../key-vault-key)) instance declared alongside this one; see
that module's README for its own arguments.

```hcl
module "tls" {
  source  = "hoangvankhoa205/devops/azurerm//modules/key-vault-certificate"
  version = "0.15.0"

  key_vault_id = module.vault.key_vault_id
  name         = "app-tls"
  subject      = "CN=app.example.com"
  dns_names    = ["app.example.com"]
}
```

## Importing an existing certificate is out of scope

Key Vault can either issue a certificate or take one you already have, and the
two are different resources wearing one name. Import uses a `certificate` block
carrying base64 key material and a password — private key bytes travelling
through Terraform state, with all the problems described in
[`key-vault-secret`](../key-vault-secret).

This module only issues. To import, write `azurerm_key_vault_certificate`
directly in your root with a `certificate` block.

## Use the secret ID, not the certificate ID

A certificate is stored twice: as a certificate object, and as a **secret**
holding the PFX or PEM. Services needing the private key — Application Gateway,
App Service — read the secret. Handing them `certificate_id` fails, and the
error rarely says why.

| Output | Use for |
| ------ | ------- |
| `certificate_id` / `versionless_id` | Reading certificate metadata, thumbprint checks |
| `secret_id` / `versionless_secret_id` | **Application Gateway, App Service** — anything loading the PFX |

Prefer the **versionless** secret ID in a listener. Auto-renewal creates a new
version, and a pinned `secret_id` keeps serving the old certificate until
someone notices it expired.

The private key is only retrievable when `exportable` is `true`, which is why
that is the default. Set it `false` only when nothing needs to pull the PFX out
— a listener will fail without it.

## Self-signed by default, and no client will trust it

`issuer_name` defaults to `Self`. That is right for a learning environment and
wrong for anything real: browsers reject it, and so do Application Gateway
backend health probes unless the check is relaxed.

For a real certificate, either name a CA issuer already configured on the vault,
or use `Unknown`, which has Key Vault produce a CSR to be signed externally and
merged back — a two-step flow this module does not automate.

## Defaults that differ from the provider's example

**`key_usage`** ships as `["digitalSignature", "keyEncipherment"]`, the pair a
TLS server needs. The provider's documentation example lists six, including
`keyCertSign` — which would let the certificate sign other certificates. That
is a certificate authority, not a web server.

**`extended_key_usage`** defaults to serverAuth (`1.3.6.1.5.5.7.3.1`). Add
clientAuth (`1.3.6.1.5.5.7.3.2`) for mutual TLS.

**`reuse_key`** is `false`, so each renewal generates fresh key material.

## Subject alternative names are not optional in practice

Modern clients ignore the subject common name and match on SANs. A certificate
with `CN=app.example.com` and no `dns_names` looks correct and still fails
hostname verification everywhere. Set `dns_names` to every hostname that will
be served.

Leaving it empty omits the SAN block entirely rather than emitting an empty one
— those are not the same thing to Azure.

## Writing a certificate needs its own role

The vault is RBAC-authorized, so creating a certificate needs **Key Vault
Certificates Officer** on the vault or its resource group. `Key Vault Crypto
Officer` covers keys and `Key Vault Secrets Officer` covers secrets; neither
covers certificates. Control-plane `Owner` and `Contributor` grant nothing.

Consumers differ too, and this is the part that catches people: an Application
Gateway reads the certificate through its **user-assigned managed identity**,
not through your credentials, so that identity needs its own role — reading the
backing secret requires **Key Vault Secrets User** in addition to any
certificate role.

Assign in the root and allow for propagation delay before use. Propagation is
minutes, not seconds, so a single apply that creates the role and immediately
uses it will fail intermittently. Order it explicitly:

```hcl
resource "time_sleep" "rbac" {
  depends_on      = [azurerm_role_assignment.certs]
  create_duration = "60s"
}

module "tls" {
  # ...
  depends_on = [time_sleep.rbac]
}
```

## The role is only one of two barriers

A role grants permission; it does not grant reachability.
[`key-vault`](../key-vault) creates the vault with public network access
disabled and its ACL set to `Deny`, so an Application Gateway with every correct
role still cannot fetch the certificate until it is allowed through the network
boundary — via a Private Endpoint, a service endpoint on its subnet, or an IP
exception.

The two failures look nothing alike: a missing role gives a 403, a blocked
network gives a timeout or a connection failure. Check which one you have before
adding more roles.

## HSM key types need a premium vault

`key_type` accepts `RSA` and `EC`. The HSM-backed variants `RSA-HSM` and
`EC-HSM` require a premium Key Vault SKU, and [`key-vault`](../key-vault)
creates a standard one, so they are rejected by validation rather than failing
at apply.

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
| [azurerm_key_vault_certificate.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/key_vault_certificate) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_key_vault_id"></a> [key\_vault\_id](#input\_key\_vault\_id) | ID of an existing Key Vault, typically the key\_vault\_id output of the key-vault module. This module does not create a vault. | `string` | n/a | yes |
| <a name="input_name"></a> [name](#input\_name) | Certificate name inside the vault. | `string` | n/a | yes |
| <a name="input_subject"></a> [subject](#input\_subject) | X.509 subject distinguished name, for example CN=example.com. Modern TLS clients ignore the common name and match on subject alternative names, so set dns\_names too. | `string` | n/a | yes |
| <a name="input_auto_renew"></a> [auto\_renew](#input\_auto\_renew) | Have Key Vault reissue the certificate before it expires. Renewal produces a new version; consumers that reference the versionless secret ID pick it up, consumers pinned to a version do not. | `bool` | `true` | no |
| <a name="input_content_type"></a> [content\_type](#input\_content\_type) | Format the certificate's backing secret is stored in. application/x-pkcs12 yields a PFX, which is what Application Gateway expects; application/x-pem-file yields PEM. | `string` | `"application/x-pkcs12"` | no |
| <a name="input_curve"></a> [curve](#input\_curve) | Elliptic curve name. Ignored when key\_type is RSA. | `string` | `"P-256"` | no |
| <a name="input_dns_names"></a> [dns\_names](#input\_dns\_names) | DNS subject alternative names. Browsers and Application Gateway health probes match on these, not on the subject CN, so a certificate without them will fail hostname verification even when the CN looks right. Empty omits the SAN block entirely. | `set(string)` | `[]` | no |
| <a name="input_exportable"></a> [exportable](#input\_exportable) | Whether the private key can be retrieved from the vault. Application Gateway and App Service read a certificate through its SECRET, which only works when the key is exportable — set false only when nothing needs to pull the PFX out. | `bool` | `true` | no |
| <a name="input_extended_key_usage"></a> [extended\_key\_usage](#input\_extended\_key\_usage) | Extended key usage OIDs. Defaults to serverAuth (1.3.6.1.5.5.7.3.1). Add clientAuth (1.3.6.1.5.5.7.3.2) for mutual TLS. | `set(string)` | <pre>[<br/>  "1.3.6.1.5.5.7.3.1"<br/>]</pre> | no |
| <a name="input_issuer_name"></a> [issuer\_name](#input\_issuer\_name) | Certificate issuer. 'Self' produces a self-signed certificate, which is what a learning environment wants and what no client will trust. 'Unknown' means the CSR is issued outside Terraform and merged in later. Any other value names a CA issuer already configured on the vault. | `string` | `"Self"` | no |
| <a name="input_key_size"></a> [key\_size](#input\_key\_size) | RSA key size. Ignored when key\_type is EC. | `number` | `2048` | no |
| <a name="input_key_type"></a> [key\_type](#input\_key\_type) | Key algorithm. RSA or EC only — the HSM-backed variants (RSA-HSM, EC-HSM) need a premium vault, and the key-vault module in this collection creates a standard one. | `string` | `"RSA"` | no |
| <a name="input_key_usage"></a> [key\_usage](#input\_key\_usage) | X.509 key usage. Defaults to the pair a TLS server certificate actually needs. The provider's own example lists six including keyCertSign, which would let the certificate sign other certificates — deliberately not the default here. | `set(string)` | <pre>[<br/>  "digitalSignature",<br/>  "keyEncipherment"<br/>]</pre> | no |
| <a name="input_renew_days_before_expiry"></a> [renew\_days\_before\_expiry](#input\_renew\_days\_before\_expiry) | How many days before expiry auto-renewal fires. Ignored when auto\_renew is false. | `number` | `30` | no |
| <a name="input_reuse_key"></a> [reuse\_key](#input\_reuse\_key) | Reuse the existing key material on renewal instead of generating a new key. False gives a fresh key each renewal, which is the safer default. | `bool` | `false` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Resource tags. | `map(string)` | `{}` | no |
| <a name="input_validity_in_months"></a> [validity\_in\_months](#input\_validity\_in\_months) | Certificate lifetime in months. | `number` | `12` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_certificate_id"></a> [certificate\_id](#output\_certificate\_id) | Versioned certificate ID. Pins the version that existed at apply time. |
| <a name="output_secret_id"></a> [secret\_id](#output\_secret\_id) | Versioned ID of the certificate's backing secret — the PFX or PEM. This, not certificate\_id, is what an Application Gateway ssl\_certificate block consumes. |
| <a name="output_thumbprint"></a> [thumbprint](#output\_thumbprint) | X.509 SHA-1 thumbprint, for matching what a client actually received against what the vault holds. |
| <a name="output_versionless_id"></a> [versionless\_id](#output\_versionless\_id) | Versionless certificate ID. Follows renewal rather than pinning a version. |
| <a name="output_versionless_secret_id"></a> [versionless\_secret\_id](#output\_versionless\_secret\_id) | Versionless ID of the backing secret. Prefer this in an Application Gateway: auto-renewal creates a new version, and a pinned secret\_id keeps serving the old certificate until someone notices it expired. |
<!-- END_TF_DOCS -->
