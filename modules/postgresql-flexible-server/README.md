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

## Resources

| Name | Type |
| ---- | ---- |
| [azurerm_postgresql_flexible_server.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/postgresql_flexible_server) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_administrator_password"></a> [administrator\_password](#input\_administrator\_password) | Database administrator password. Source it from a secret store rather than a variable file: whatever you pass lands in Terraform state in cleartext. This module never returns it in an output. | `string` | n/a | yes |
| <a name="input_delegated_subnet_id"></a> [delegated\_subnet\_id](#input\_delegated\_subnet\_id) | Subnet delegated to Microsoft.DBforPostgreSQL/flexibleServers. The delegation is mandatory and exclusive: nothing else may share the subnet. virtual-network creates one via a subnet's `delegation` block. | `string` | n/a | yes |
| <a name="input_location"></a> [location](#input\_location) | Azure region. | `string` | n/a | yes |
| <a name="input_name"></a> [name](#input\_name) | Globally unique PostgreSQL server name. | `string` | n/a | yes |
| <a name="input_private_dns_zone_id"></a> [private\_dns\_zone\_id](#input\_private\_dns\_zone\_id) | Private DNS zone the server registers its FQDN in. Azure requires the zone name to end in .postgres.database.azure.com — any other suffix fails the apply. The zone must also be linked to the VNet, or clients resolve nothing. | `string` | n/a | yes |
| <a name="input_resource_group_name"></a> [resource\_group\_name](#input\_resource\_group\_name) | Existing resource group name. | `string` | n/a | yes |
| <a name="input_administrator_login"></a> [administrator\_login](#input\_administrator\_login) | Database administrator username. | `string` | `"pgadminuser"` | no |
| <a name="input_backup_retention_days"></a> [backup\_retention\_days](#input\_backup\_retention\_days) | How far back point-in-time restore can reach. Azure permits 7-35. | `number` | `7` | no |
| <a name="input_high_availability"></a> [high\_availability](#input\_high\_availability) | Optional hot standby. SameZone protects against node failure; ZoneRedundant also protects against losing a zone, and needs a region that has zones. Either mode roughly doubles the compute bill. The standby is NOT a readable replica — it serves no queries and exists only to fail over. | <pre>object({<br/>    mode                      = string<br/>    standby_availability_zone = optional(string)<br/>  })</pre> | `null` | no |
| <a name="input_postgres_version"></a> [postgres\_version](#input\_postgres\_version) | PostgreSQL major version. | `string` | `"16"` | no |
| <a name="input_sku_name"></a> [sku\_name](#input\_sku\_name) | Compute SKU, in Azure's tier-prefixed form: B\_ for burstable, GP\_ for general purpose, MO\_ for memory optimised — for example B\_Standard\_B1ms or GP\_Standard\_D2s\_v3. A bare VM size such as Standard\_D2s\_v3 is rejected, which is the most common mistake here. | `string` | `"B_Standard_B1ms"` | no |
| <a name="input_storage_mb"></a> [storage\_mb](#input\_storage\_mb) | Storage allocation in MiB; 32768 is 32 GiB. Storage can be grown but never shrunk, and growing it may briefly restart the server. | `number` | `32768` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Resource tags. | `map(string)` | `{}` | no |
| <a name="input_zone"></a> [zone](#input\_zone) | Availability zone for the primary, as a string such as "1". Null lets Azure choose. Set it explicitly when using ZoneRedundant HA so the standby lands somewhere different. | `string` | `null` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_fqdn"></a> [fqdn](#output\_fqdn) | Private FQDN clients connect to. It resolves only through the private DNS zone supplied to this module, so a client outside the VNet gets no answer rather than a refused connection. |
| <a name="output_server_id"></a> [server\_id](#output\_server\_id) | PostgreSQL Flexible Server resource ID. |
<!-- END_TF_DOCS -->