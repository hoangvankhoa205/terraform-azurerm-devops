# GitHub Actions federated identity

Creates a user-assigned managed identity and one exact GitHub OIDC trust
relationship. It creates no client secret and grants no Azure role. Prefer a
separate identity and GitHub Environment subject for each plan/apply boundary;
combine it with `github-actions-rbac` using narrow scopes.


## Usage

```hcl
module "ci_identity" {
  source  = "hoangvankhoa205/devops/azurerm//modules/github-actions-federated-identity"
  version = "0.15.0"

  name                = "learn-gh-dev"
  location            = "Southeast Asia"
  resource_group_name = "learn-identity-rg"

  # Matched literally against the token GitHub presents. One environment, one
  # ref, or pull_request — wildcards are rejected.
  subject = "repo:your-org/your-repo:environment:dev"
}

output "ci_client_id" {
  value = module.ci_identity.client_id
}

output "ci_tenant_id" {
  value = module.ci_identity.tenant_id
}
```

Accepted subject forms:

| Form | Example |
| --- | --- |
| Environment | `repo:your-org/your-repo:environment:dev` |
| Branch | `repo:your-org/your-repo:ref:refs/heads/main` |
| Tag | `repo:your-org/your-repo:ref:refs/tags/v1.0.0` |
| Pull request | `repo:your-org/your-repo:pull_request` |

### Getting the outputs into GitHub

Nothing wires these across for you. Read them out and set them as repository
variables — they are identifiers, not secrets, so `vars` is the right home:

```sh
gh variable set AZURE_CLIENT_ID       --body "$(terraform output -raw ci_client_id)"
gh variable set AZURE_TENANT_ID       --body "$(terraform output -raw ci_tenant_id)"
gh variable set AZURE_SUBSCRIPTION_ID --body "$(az account show --query id -o tsv)"
```

`AZURE_SUBSCRIPTION_ID` comes from your subscription, not from this module —
`azure/login` needs it to pick a subscription, and no module here outputs one.

### The workflow

Two things in this snippet are easy to miss, and each produces a confusing
failure on the first run.

```yaml
permissions:
  id-token: write # without this, no OIDC token is minted at all
  contents: read

jobs:
  deploy:
    runs-on: ubuntu-latest

    # REQUIRED when the subject is `...:environment:dev`. GitHub only puts
    # `environment:dev` in the token when the job declares the environment.
    # Omit it and the token says `ref:refs/heads/main`, Entra sees a subject it
    # does not trust, and login fails with AADSTS70021 — which reads like a
    # broken credential rather than a mismatched string.
    environment: dev

    steps:
      - uses: azure/login@v2
        with:
          client-id: ${{ vars.AZURE_CLIENT_ID }}       # module.ci_identity.client_id
          tenant-id: ${{ vars.AZURE_TENANT_ID }}       # module.ci_identity.tenant_id
          subscription-id: ${{ vars.AZURE_SUBSCRIPTION_ID }}

      # azure/login authenticates the az CLI. It does NOT authenticate the
      # azurerm provider, which reads its own environment. Without these,
      # terraform fails to authenticate in a job where `az account show` works.
      - run: terraform apply -auto-approve
        env:
          ARM_USE_OIDC: true
          ARM_CLIENT_ID: ${{ vars.AZURE_CLIENT_ID }}
          ARM_TENANT_ID: ${{ vars.AZURE_TENANT_ID }}
          ARM_SUBSCRIPTION_ID: ${{ vars.AZURE_SUBSCRIPTION_ID }}
```

If you would rather not repeat those four, set `use_oidc = true` in the
`provider "azurerm"` block instead.

### The identity starts with no permissions

`principal_id` is what [`github-actions-rbac`](../github-actions-rbac) grants
roles to. This module grants none, so until you pair the two, a successful
`azure/login` can still do nothing at all.

### Bootstrapping

Something has to create this identity before CI exists, so the first apply is
from a workstation with `az login`. After that the pipeline can manage
everything else, including itself.

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
| [azurerm_federated_identity_credential.github](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/federated_identity_credential) | resource |
| [azurerm_user_assigned_identity.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/user_assigned_identity) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_location"></a> [location](#input\_location) | Azure region. | `string` | n/a | yes |
| <a name="input_name"></a> [name](#input\_name) | Managed identity name. | `string` | n/a | yes |
| <a name="input_resource_group_name"></a> [resource\_group\_name](#input\_resource\_group\_name) | Existing resource group name. | `string` | n/a | yes |
| <a name="input_subject"></a> [subject](#input\_subject) | Exact GitHub OIDC subject, such as repo:owner/repository:environment:dev. Entra matches this string literally against the token GitHub presents, so it must name one environment, one ref, or pull\_request — anything broader hands every workflow in the repository the same Azure access. | `string` | n/a | yes |
| <a name="input_audiences"></a> [audiences](#input\_audiences) | OIDC audience the token must carry. Entra ID expects api://AzureADTokenExchange and there is rarely a reason to change it. Kept as a list because that is the shape the provider takes, but Azure accepts only one entry. | `list(string)` | <pre>[<br/>  "api://AzureADTokenExchange"<br/>]</pre> | no |
| <a name="input_credential_name"></a> [credential\_name](#input\_credential\_name) | Federated credential name. | `string` | `"github-actions"` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Resource tags. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_client_id"></a> [client\_id](#output\_client\_id) | Client ID used by Azure Login. |
| <a name="output_identity_id"></a> [identity\_id](#output\_identity\_id) | User-assigned managed identity ID. |
| <a name="output_principal_id"></a> [principal\_id](#output\_principal\_id) | Principal ID used for Azure role assignments. |
| <a name="output_tenant_id"></a> [tenant\_id](#output\_tenant\_id) | Microsoft Entra tenant ID used by Azure Login. |
<!-- END_TF_DOCS -->
