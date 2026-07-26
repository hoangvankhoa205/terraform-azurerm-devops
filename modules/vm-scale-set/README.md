# VM Scale Set

Creates a small private Linux VM Scale Set with SSH-key authentication and no
public instance IPs. This learning module uses manual upgrades; production
modules should add health probes, automatic repair, rolling upgrades, and
autoscale rules.


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
| [azurerm_linux_virtual_machine_scale_set.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/linux_virtual_machine_scale_set) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_location"></a> [location](#input\_location) | Azure region. | `string` | n/a | yes |
| <a name="input_name"></a> [name](#input\_name) | Scale set name. Instance computer names are derived from it by Azure. | `string` | n/a | yes |
| <a name="input_resource_group_name"></a> [resource\_group\_name](#input\_resource\_group\_name) | Existing resource group name. | `string` | n/a | yes |
| <a name="input_ssh_public_key"></a> [ssh\_public\_key](#input\_ssh\_public\_key) | OpenSSH public key shared by every instance. Pass the contents of a .pub file, never the private key. Password login is disabled, so this is the only way onto an instance. | `string` | n/a | yes |
| <a name="input_subnet_id"></a> [subnet\_id](#input\_subnet\_id) | Subnet every instance joins. Take this from virtual-network's subnet\_ids output, and size the subnet for the highest instance count you expect — a scale set that cannot allocate addresses fails to scale out. | `string` | n/a | yes |
| <a name="input_admin_username"></a> [admin\_username](#input\_admin\_username) | Local administrator username on every instance. Azure rejects a list of reserved names (root, admin, administrator and similar) at create time, so a typo here fails the apply rather than the boot. | `string` | `"azureuser"` | no |
| <a name="input_custom_data"></a> [custom\_data](#input\_custom\_data) | Optional cloud-init text, passed as plain text. The module base64-encodes it, so encoding it yourself first produces instances that boot and silently ignore the configuration. With Manual upgrade mode, changing this affects new instances only until existing ones are rolled. | `string` | `null` | no |
| <a name="input_instances"></a> [instances](#input\_instances) | Fixed instance count. This module ships no autoscale rules, so the count only changes when you change it here. Scaling out needs spare addresses in the subnet. | `number` | `2` | no |
| <a name="input_sku"></a> [sku](#input\_sku) | Azure VM size for every instance, such as Standard\_B2s or Standard\_D2s\_v3. Burstable B-series is cheapest for a lab; check the size is available in your region and zones before relying on it. | `string` | `"Standard_B2s"` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Resource tags. | `map(string)` | `{}` | no |
| <a name="input_zones"></a> [zones](#input\_zones) | Availability zones to spread instances across. Empty is both the default and correct in regions that have no zones — a zone list Azure does not recognise fails the apply. | `list(string)` | `[]` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_principal_id"></a> [principal\_id](#output\_principal\_id) | System-assigned identity principal ID, shared by every instance. Grant Azure roles to this so instances can reach Key Vault, Storage, or a registry without a stored credential. |
| <a name="output_scale_set_id"></a> [scale\_set\_id](#output\_scale\_set\_id) | Scale set resource ID. Autoscale settings, instance repair, and a load balancer backend pool all attach at this scope. |
<!-- END_TF_DOCS -->