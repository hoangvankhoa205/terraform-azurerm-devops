# Linux VMs

Demonstrates `for_each` by creating a stable map of private Ubuntu VMs. Every
VM uses SSH-only authentication and a managed identity; no public IP is
created. Use VM Scale Sets rather than this module for elastic production
capacity.

Boot diagnostics is enabled (managed storage account) so these private VMs are
reachable via the Azure **Serial Console** for break-glass access. Since SSH is
key-only, set a local password for console login by passing a cloud-init
`custom_data` per instance (`ssh_pwauth` stays off).

## Usage

```hcl
module "vms" {
  source  = "hoangvankhoa205/devops/azurerm//modules/linux-vms"
  version = "0.3.0"

  location            = "Southeast Asia"
  resource_group_name = "learn-rg"
  ssh_public_key      = file("~/.ssh/id_ed25519.pub")

  instances = {
    web = {
      subnet_id = azurerm_subnet.workload.id
    }
    worker = {
      subnet_id = azurerm_subnet.workload.id
      size      = "Standard_B2s"
    }
  }
}
```

Each map key is the VM name and must stay stable — renaming a key destroys and
recreates that VM. Per-instance `size`, `admin_username`, and `custom_data` are
optional; `ssh_public_key` is shared across all instances. Outputs (`ids`,
`private_ip_addresses`, `principal_ids`) are maps keyed by the same names.


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

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_instances"></a> [instances](#input\_instances) | VM definitions keyed by stable logical name. | <pre>map(object({<br/>    subnet_id      = string<br/>    size           = optional(string, "Standard_D2s_v3")<br/>    admin_username = optional(string, "azureuser")<br/>    custom_data    = optional(string)<br/>  }))</pre> | n/a | yes |
| <a name="input_location"></a> [location](#input\_location) | Azure region. | `string` | n/a | yes |
| <a name="input_resource_group_name"></a> [resource\_group\_name](#input\_resource\_group\_name) | Existing resource group name. | `string` | n/a | yes |
| <a name="input_ssh_public_key"></a> [ssh\_public\_key](#input\_ssh\_public\_key) | Shared OpenSSH public key. | `string` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | Resource tags. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_ids"></a> [ids](#output\_ids) | VM IDs keyed by logical name. |
| <a name="output_principal_ids"></a> [principal\_ids](#output\_principal\_ids) | Managed identity principal IDs keyed by name. |
| <a name="output_private_ip_addresses"></a> [private\_ip\_addresses](#output\_private\_ip\_addresses) | Private IPs keyed by logical name. |
<!-- END_TF_DOCS -->