# linux-vms

Several private Ubuntu VMs from one map, each with its own NIC and
system-assigned managed identity. No public IPs at all.

## Usage

`module.network` below is a [`virtual-network`](../virtual-network) instance
declared alongside this one; it supplies the `subnet_ids` map.

```hcl
module "vms" {
  source  = "hoangvankhoa205/devops/azurerm//modules/linux-vms"
  version = "0.15.0"

  location            = "Southeast Asia"
  resource_group_name = "learn-rg"
  ssh_public_key      = file("~/.ssh/id_ed25519.pub")

  instances = {
    control = {
      subnet_id = module.network.subnet_ids["workload_private"]
      size      = "Standard_B2s"
    }

    worker-1 = {
      subnet_id   = module.network.subnet_ids["workload_private"]
      custom_data = file("${path.module}/cloud-init/worker.yaml")
    }
  }
}

output "addresses" {
  value = module.vms.private_ip_addresses # { control = "10.42.1.4", worker-1 = ... }
}
```

## Map keys are permanent names

Each key becomes the VM's Azure name and the stem of its NIC name
(`worker-1` → `worker-1-nic`), and is the key of every map this module outputs.

Renaming a key destroys and recreates that machine. Adding or removing an entry
touches only that entry — which is the reason for a map rather than a count.

## Every instance shares one SSH key, and nothing else has to match

`ssh_public_key` is module-wide. Everything else is per instance, with defaults
that make the common case short:

| Attribute | Required | Default |
| --- | --- | --- |
| `subnet_id` | yes | — |
| `size` | no | `Standard_D2s_v3` |
| `admin_username` | no | `azureuser` |
| `custom_data` | no | none |

Instances may sit in different subnets. `custom_data` is passed as plain text
and base64-encoded by the module, so encoding it yourself produces a VM that
boots and ignores it.

Both a private key in `ssh_public_key` and a reserved `admin_username` (`root`,
`admin`, `administrator`, and similar) are rejected at plan time rather than
failing partway through an apply.

## There is no public IP, and no way to add one here

Unlike [`linux-vm`](../linux-vm), this module has no public IP resource at all.
Reaching these machines means a bastion, a VPN, or a peered network.

That is why `boot_diagnostics {}` is enabled with no storage account URI: it
uses a managed account and turns on the **Azure serial console**, which is the
only break-glass route left when networking or SSH configuration is broken. It
costs nothing and is the difference between a recoverable mistake and a rebuild.

## Choosing between this and its siblings

Use `linux-vms` when the machines are individuals that differ in name, subnet,
size, or startup configuration. For a single machine use
[`linux-vm`](../linux-vm); for interchangeable copies whose count changes, use
[`vm-scale-set`](../vm-scale-set).

## What this module leaves out

- **The resource group, VNet, and subnets.**
- **Security rules and any bastion.**
- **Data disks.**
- **Role assignments.** Grant roles to the entries in `principal_ids`.
- **Per-instance tags.** `tags` applies to every VM and NIC alike.

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
| [azurerm_linux_virtual_machine.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/linux_virtual_machine) | resource |
| [azurerm_network_interface.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/network_interface) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_instances"></a> [instances](#input\_instances) | VM definitions keyed by stable logical name. The key becomes the VM name and its NIC name, so renaming a key destroys and recreates that VM — choose keys you can live with. | <pre>map(object({<br/>    subnet_id      = string<br/>    size           = optional(string, "Standard_D2s_v3")<br/>    admin_username = optional(string, "azureuser")<br/>    custom_data    = optional(string)<br/>  }))</pre> | n/a | yes |
| <a name="input_location"></a> [location](#input\_location) | Azure region. | `string` | n/a | yes |
| <a name="input_resource_group_name"></a> [resource\_group\_name](#input\_resource\_group\_name) | Existing resource group name. | `string` | n/a | yes |
| <a name="input_ssh_public_key"></a> [ssh\_public\_key](#input\_ssh\_public\_key) | OpenSSH public key shared by every VM in the map. Pass the contents of a .pub file, never the private key. Password login is disabled, so this is the only way in. | `string` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | Resource tags. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_ids"></a> [ids](#output\_ids) | Virtual machine resource IDs keyed by logical name. |
| <a name="output_principal_ids"></a> [principal\_ids](#output\_principal\_ids) | System-assigned identity principal IDs keyed by logical name. Grant Azure roles to these so each VM can reach Key Vault, Storage, or a registry without a stored credential. |
| <a name="output_private_ip_addresses"></a> [private\_ip\_addresses](#output\_private\_ip\_addresses) | Private addresses keyed by logical name. These are the only addresses these VMs have; there is no public IP. |
<!-- END_TF_DOCS -->