# Linux VM

Creates one Ubuntu VM with SSH-key-only authentication and a system-assigned
managed identity. The default is a private-only NIC. Set
`public_ip_enabled = true` only for an explicit, short-lived test; doing so
creates a Standard static IPv4 address but does not open an NSG rule.

For a complete CIDR-scoped interactive test, use
[`examples/public-ssh-smoke`](../../examples/public-ssh-smoke). Production
callers should keep the private default and reach the VM through Bastion, VPN,
or another approved private management path.


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
| [azurerm_linux_virtual_machine.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/linux_virtual_machine) | resource |
| [azurerm_network_interface.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/network_interface) | resource |
| [azurerm_public_ip.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/public_ip) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_admin_username"></a> [admin\_username](#input\_admin\_username) | Local administrator username. | `string` | `"azureuser"` | no |
| <a name="input_custom_data"></a> [custom\_data](#input\_custom\_data) | Optional cloud-init text. | `string` | `null` | no |
| <a name="input_location"></a> [location](#input\_location) | Azure region. | `string` | n/a | yes |
| <a name="input_name"></a> [name](#input\_name) | VM name. | `string` | n/a | yes |
| <a name="input_public_ip_enabled"></a> [public\_ip\_enabled](#input\_public\_ip\_enabled) | Create and attach a Standard static public IPv4 address. This does not create an inbound NSG rule. Intended for explicit, short-lived tests. | `bool` | `false` | no |
| <a name="input_resource_group_name"></a> [resource\_group\_name](#input\_resource\_group\_name) | Existing resource group name. | `string` | n/a | yes |
| <a name="input_size"></a> [size](#input\_size) | Azure VM SKU. Defaults to a general-purpose x86 size with broad regional capacity; override for cheaper burstable SKUs (e.g. Standard\_B1s/B2s) where your region and subscription have capacity. | `string` | `"Standard_D2s_v3"` | no |
| <a name="input_ssh_public_key"></a> [ssh\_public\_key](#input\_ssh\_public\_key) | OpenSSH public key; private keys are never accepted. | `string` | n/a | yes |
| <a name="input_subnet_id"></a> [subnet\_id](#input\_subnet\_id) | ID of the subnet for the private NIC. | `string` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | Resource tags. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_id"></a> [id](#output\_id) | VM resource ID. |
| <a name="output_network_interface_id"></a> [network\_interface\_id](#output\_network\_interface\_id) | Network interface resource ID. |
| <a name="output_principal_id"></a> [principal\_id](#output\_principal\_id) | System-assigned identity principal ID. |
| <a name="output_private_ip_address"></a> [private\_ip\_address](#output\_private\_ip\_address) | Private NIC address. |
| <a name="output_public_ip_address"></a> [public\_ip\_address](#output\_public\_ip\_address) | Allocated public IPv4 address when public\_ip\_enabled is true; otherwise null. |
| <a name="output_public_ip_id"></a> [public\_ip\_id](#output\_public\_ip\_id) | Public IP resource ID when public\_ip\_enabled is true; otherwise null. |
<!-- END_TF_DOCS -->
