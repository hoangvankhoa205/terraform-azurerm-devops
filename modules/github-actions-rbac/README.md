# GitHub Actions RBAC

Grants an existing managed identity explicit named roles at explicit scopes.
The module rejects `Owner`; use custom roles or the smallest built-in roles that
cover state, plan, or apply operations. Azure RBAC can take several minutes to
propagate, so integration tests need bounded retries.


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
