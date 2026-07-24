# PostgreSQL Flexible Server

Creates a private, delegated-subnet PostgreSQL Flexible Server with PITR
backups. The caller supplies a password from a secret store; it is never
output. HA is optional because the default SKU is intentionally inexpensive.
An HA standby is not a readable replica. Production should add Entra auth,
diagnostics, locks, customer requirements for geo-backup, and restore testing.


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
| [azurerm_postgresql_flexible_server.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/postgresql_flexible_server) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_administrator_login"></a> [administrator\_login](#input\_administrator\_login) | Database administrator username. | `string` | `"pgadminuser"` | no |
| <a name="input_administrator_password"></a> [administrator\_password](#input\_administrator\_password) | Database administrator password; source this from a secret store. | `string` | n/a | yes |
| <a name="input_backup_retention_days"></a> [backup\_retention\_days](#input\_backup\_retention\_days) | Point-in-time restore retention. | `number` | `7` | no |
| <a name="input_delegated_subnet_id"></a> [delegated\_subnet\_id](#input\_delegated\_subnet\_id) | Subnet delegated to Microsoft.DBforPostgreSQL/flexibleServers. | `string` | n/a | yes |
| <a name="input_high_availability"></a> [high\_availability](#input\_high\_availability) | Optional same-zone or zone-redundant HA settings. | <pre>object({<br/>  mode = string, standby_availability_zone = optional(string) })</pre> | `null` | no |
| <a name="input_location"></a> [location](#input\_location) | Azure region. | `string` | n/a | yes |
| <a name="input_name"></a> [name](#input\_name) | Globally unique PostgreSQL server name. | `string` | n/a | yes |
| <a name="input_postgres_version"></a> [postgres\_version](#input\_postgres\_version) | PostgreSQL major version. | `string` | `"16"` | no |
| <a name="input_private_dns_zone_id"></a> [private\_dns\_zone\_id](#input\_private\_dns\_zone\_id) | Private DNS zone ID for delegated networking. | `string` | n/a | yes |
| <a name="input_resource_group_name"></a> [resource\_group\_name](#input\_resource\_group\_name) | Existing resource group name. | `string` | n/a | yes |
| <a name="input_sku_name"></a> [sku\_name](#input\_sku\_name) | Flexible Server compute SKU. | `string` | `"B_Standard_B1ms"` | no |
| <a name="input_storage_mb"></a> [storage\_mb](#input\_storage\_mb) | Storage allocation in MiB. | `number` | `32768` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Resource tags. | `map(string)` | `{}` | no |
| <a name="input_zone"></a> [zone](#input\_zone) | Primary availability zone or null. | `string` | `null` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_fqdn"></a> [fqdn](#output\_fqdn) | Private PostgreSQL server FQDN. |
| <a name="output_id"></a> [id](#output\_id) | PostgreSQL server ID. |
<!-- END_TF_DOCS -->