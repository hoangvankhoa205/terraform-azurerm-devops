# Virtual network

Creates one VNet, role-named subnets, and an empty NSG attached to every
subnet. Empty NSGs retain Azure's built-in rules but add no Internet ingress.
`default_outbound_access_enabled` defaults to `false`; add explicit NAT or
firewall egress when workloads need the Internet.

Azure subnets are regional and span zones. Names such as `ingress` and
`workload_private` describe purpose, not an AWS-style public/private property.
An optional typed delegation supports service subnets such as PostgreSQL
Flexible Server without embedding a database resource in the network module.

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
| [azurerm_network_security_group.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/network_security_group) | resource |
| [azurerm_subnet.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subnet) | resource |
| [azurerm_subnet_network_security_group_association.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subnet_network_security_group_association) | resource |
| [azurerm_virtual_network.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_network) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_address_space"></a> [address\_space](#input\_address\_space) | CIDR ranges assigned to the virtual network. | `list(string)` | n/a | yes |
| <a name="input_location"></a> [location](#input\_location) | Azure region for the virtual network. | `string` | n/a | yes |
| <a name="input_name"></a> [name](#input\_name) | Name of the virtual network. | `string` | n/a | yes |
| <a name="input_resource_group_name"></a> [resource\_group\_name](#input\_resource\_group\_name) | Name of an existing resource group. | `string` | n/a | yes |
| <a name="input_subnets"></a> [subnets](#input\_subnets) | Subnets keyed by role. Azure subnets span availability zones. | <pre>map(object({<br/>    address_prefixes                = list(string)<br/>    service_endpoints               = optional(list(string), [])<br/>    default_outbound_access_enabled = optional(bool, false)<br/>    delegation = optional(object({<br/>      name         = optional(string, "service-delegation")<br/>      service_name = string<br/>      actions      = optional(list(string), [])<br/>    }))<br/>  }))</pre> | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags applied to all resources. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_network_security_group_ids"></a> [network\_security\_group\_ids](#output\_network\_security\_group\_ids) | Network security group IDs keyed by subnet role. |
| <a name="output_network_security_group_names"></a> [network\_security\_group\_names](#output\_network\_security\_group\_names) | Network security group names keyed by subnet role. |
| <a name="output_subnet_ids"></a> [subnet\_ids](#output\_subnet\_ids) | Subnet IDs keyed by the supplied role names. |
| <a name="output_vnet_id"></a> [vnet\_id](#output\_vnet\_id) | ID of the virtual network. |
| <a name="output_vnet_name"></a> [vnet\_name](#output\_vnet\_name) | Name of the virtual network. |
<!-- END_TF_DOCS -->