# GitHub Actions RBAC

Grants an existing managed identity explicit named roles at explicit scopes.
The module rejects `Owner`; use custom roles or the smallest built-in roles that
cover state, plan, or apply operations. Azure RBAC can take several minutes to
propagate, so integration tests need bounded retries.


## Usage

```hcl
module "ci_rbac" {
  source  = "hoangvankhoa205/devops/azurerm//modules/github-actions-rbac"
  version = "0.15.0"

  # From github-actions-federated-identity. Note: principal_id, not client_id.
  principal_id = module.ci_identity.principal_id

  # Map keys are labels for your own benefit; they name nothing in Azure.
  assignments = {
    state = {
      scope                = module.state.storage_account_id
      role_definition_name = "Storage Blob Data Contributor"
    }

    workload = {
      scope                = azurerm_resource_group.workload.id
      role_definition_name = "Contributor"
    }
  }
}
```

`Owner` is rejected, and so is an empty map — the latter because a pipeline with
no permissions looks like it works right up until the first apply fails.

## Data-plane roles are not control-plane roles

`Contributor` on a subscription lets a principal create and delete a storage
account but **not** read a blob inside it. Terraform state needs
`Storage Blob Data Contributor`; Key Vault secrets need
`Key Vault Secrets Officer`; keys need `Key Vault Crypto Officer`, and holding
one does not grant the other.

Getting this wrong produces a 403 at apply time from the data plane, long after
the role assignment itself succeeded.

## Propagation is eventually consistent

An assignment can take several minutes to take effect. A pipeline that creates
an identity and immediately uses it will intermittently fail with authorisation
errors that disappear on retry. Give the first call bounded retries rather than
treating the failure as a configuration problem.

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
| [azurerm_role_assignment.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_assignment) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_assignments"></a> [assignments](#input\_assignments) | Narrow Azure RBAC assignments keyed by a stable label. | <pre>map(object({<br/>    scope                = string<br/>    role_definition_name = string<br/>  }))</pre> | n/a | yes |
| <a name="input_principal_id"></a> [principal\_id](#input\_principal\_id) | Managed identity principal ID. | `string` | n/a | yes |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_assignment_ids"></a> [assignment\_ids](#output\_assignment\_ids) | Role assignment IDs keyed by input label. |
<!-- END_TF_DOCS -->
