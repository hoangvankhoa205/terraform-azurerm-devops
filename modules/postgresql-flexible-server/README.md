# postgresql-flexible-server

A PostgreSQL Flexible Server injected into a delegated subnet, reachable only
from inside the virtual network.

## Usage

The subnet must be delegated to the service, and a private DNS zone must exist
and be linked to the VNet. Both are inputs rather than resources here, because
both are usually shared:

```hcl
module "network" {
  source  = "hoangvankhoa205/devops/azurerm//modules/virtual-network"
  version = "0.15.0"

  name                = "learn-vnet"
  location            = "Southeast Asia"
  resource_group_name = "learn-rg"
  address_space       = ["10.42.0.0/16"]

  subnets = {
    data_private = {
      address_prefixes = ["10.42.2.0/24"]
      delegation = {
        service_name = "Microsoft.DBforPostgreSQL/flexibleServers"
        actions      = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
      }
    }
  }
}

# The zone name MUST end .postgres.database.azure.com.
resource "azurerm_private_dns_zone" "pg" {
  name                = "learn.postgres.database.azure.com"
  resource_group_name = "learn-rg"
}

resource "azurerm_private_dns_zone_virtual_network_link" "pg" {
  name                  = "learn-pg-link"
  resource_group_name   = "learn-rg"
  private_dns_zone_name = azurerm_private_dns_zone.pg.name
  virtual_network_id    = module.network.vnet_id
}

module "database" {
  source  = "hoangvankhoa205/devops/azurerm//modules/postgresql-flexible-server"
  version = "0.15.0"

  name                = "learn-postgres-001"
  location            = "Southeast Asia"
  resource_group_name = "learn-rg"

  delegated_subnet_id = module.network.subnet_ids["data_private"]
  private_dns_zone_id = azurerm_private_dns_zone.pg.id

  # Read this from a secret store, not a .tfvars file.
  administrator_password = data.azurerm_key_vault_secret.pg_admin.value

  depends_on = [azurerm_private_dns_zone_virtual_network_link.pg]
}
```

## Three things that fail the apply, in order of how often

1. **The SKU is not a bare VM size.** It carries a tier prefix:
   `B_Standard_B1ms`, `GP_Standard_D2s_v3`, `MO_Standard_E2s_v3`. Passing
   `Standard_D2s_v3` is rejected.
2. **The DNS zone name must end `.postgres.database.azure.com`.** Any other
   suffix is refused, and the message does not make the reason obvious.
3. **The subnet delegation is mandatory and exclusive.** A subnet delegated to
   Flexible Server can host nothing else, so give the database its own.

The zone also has to be *linked* to the VNet. Without the link the server
creates successfully and then nothing can resolve its name.

## The password is yours to protect

`administrator_password` is marked sensitive, so it stays out of plan output and
the console, and this module never returns it in an output — a property pinned
by a test.

That does not keep it out of **Terraform state**, where it is stored in
cleartext. Key Vault does not change that. Protect the state file (see
[`state-storage`](../state-storage)), or read the password from a data source at
apply time so the value at least never sits in a `.tfvars` file in your repo.

## High availability is not a read replica

`high_availability` is off by default and roughly doubles the compute bill when
enabled.

- `SameZone` protects against node failure within one zone.
- `ZoneRedundant` also survives losing a zone, and needs a region that has them.
  Set `zone` explicitly so the standby lands somewhere different.

In both modes the standby serves **no queries**. It exists to fail over. If you
want to offload reads, you want a read replica, which this module does not
create.

## Settings that are fixed rather than exposed

- `public_network_access_enabled` is always `false`. A VNet-integrated Flexible
  Server cannot serve a public endpoint at all, so a knob would only let you
  write a configuration Azure rejects.
- `geo_redundant_backup_enabled` is always `false`. It cannot be changed after
  creation, so exposing it would invite an edit that silently replaces the
  server and takes the data with it.
- Entra authentication is off. Enabling it needs an administrator principal this
  module does not accept.

## What this module leaves out

- **Databases, roles, extensions, and firewall rules.** The server is empty.
- **The private DNS zone and its VNet link.**
- **Read replicas.**
- **Connection pooling (PgBouncer) and server parameters.**
- **Monitoring, alerting, and log routing.**

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