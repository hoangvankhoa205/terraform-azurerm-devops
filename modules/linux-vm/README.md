# linux-vm

One Ubuntu 22.04 VM with SSH-key-only authentication and a system-assigned
managed identity. Private by default.

## Usage

`module.network` below is a [`virtual-network`](../virtual-network) instance
declared alongside this one; it supplies the `subnet_ids` map.

```hcl
module "vm" {
  source  = "hoangvankhoa205/devops/azurerm//modules/linux-vm"
  version = "0.15.0"

  name                = "learn-vm"
  location            = "Southeast Asia"
  resource_group_name = "learn-rg"
  subnet_id           = module.network.subnet_ids["workload_private"]
  ssh_public_key      = file("~/.ssh/id_ed25519.pub")
}
```

With cloud-init, passed as **plain text** — the module base64-encodes it:

```hcl
  custom_data = <<-EOT
    #cloud-config
    packages:
      - nginx
  EOT
```

Encoding it yourself first produces a VM that boots normally and silently
ignores the configuration, which is unpleasant to diagnose after the fact.

## There is no password login

`disable_password_authentication` is hard-coded true, so the SSH key is the only
credential. A key you cannot use is a VM you cannot reach — and since the NIC is
private, there is no console fallback beyond the Azure serial console.

The key is installed for `admin_username`, and the module wires the same value
to both places so the two cannot drift apart.

Two things are rejected at plan time rather than at apply:

- **A private key.** An OpenSSH private key starts `-----BEGIN`, so requiring a
  public-key algorithm prefix (`ssh-ed25519`, `ssh-rsa`, `ecdsa-sha2-*`) catches
  the paste mistake.
- **A reserved username.** Azure refuses `root`, `admin`, `administrator`,
  `guest`, `test`, `user` and similar, and would otherwise fail the apply after
  the NIC already exists.

## The public IP is opt-in and opens nothing

`public_ip_enabled = true` allocates a Standard static IPv4 address and attaches
it to the NIC. It does **not** create an inbound security rule, so nothing can
reach port 22 until you add one yourself:

```hcl
resource "azurerm_network_security_rule" "ssh" {
  name                        = "allow-ssh-from-office"
  resource_group_name         = "learn-rg"
  network_security_group_name = module.network.network_security_group_names["workload_private"]
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "22"
  source_address_prefix       = "203.0.113.10/32" # never "*"
  destination_address_prefix  = "*"
}
```

Two decisions rather than one, deliberately. For anything beyond a short-lived
test, prefer a bastion or a VPN and leave the address off.

Both public IP outputs are `null` when the address is not created, so a caller
can reference them without guarding on the flag.

## Reaching it without a public IP

- Azure Bastion, from a `AzureBastionSubnet` in the same VNet.
- A VPN or ExpressRoute connection.
- A peered network.
- The serial console, for break-glass access when networking itself is broken.

## Choosing between this and its siblings

Use `linux-vm` for one machine that matters — a control node, a build agent, a
jump host. For several machines that differ per instance, use
[`linux-vms`](../linux-vms). For interchangeable copies behind a load balancer,
use [`vm-scale-set`](../vm-scale-set).

## The size default is not the cheapest

`Standard_D2s_v3` is chosen for broad regional capacity rather than price. For a
lab, `Standard_B1s` or `Standard_B2s` is considerably cheaper — check they are
available in your region and that your subscription has quota, since a size with
no capacity fails the apply rather than falling back.

## What this module leaves out

- **The resource group, VNet, and subnet.**
- **Security rules**, including the one the public IP needs.
- **Data disks.** The VM gets a Standard_LRS OS disk only.
- **Role assignments.** Grant roles to `principal_id` yourself.
- **Backup, monitoring agents, and patch management.**

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
| [azurerm_public_ip.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/public_ip) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_location"></a> [location](#input\_location) | Azure region. | `string` | n/a | yes |
| <a name="input_name"></a> [name](#input\_name) | Virtual machine name. Also names the NIC (<name>-nic) and, when enabled, the public IP (<name>-pip). | `string` | n/a | yes |
| <a name="input_resource_group_name"></a> [resource\_group\_name](#input\_resource\_group\_name) | Existing resource group name. | `string` | n/a | yes |
| <a name="input_ssh_public_key"></a> [ssh\_public\_key](#input\_ssh\_public\_key) | OpenSSH public key; private keys are never accepted. Pass the contents of a .pub file, e.g. file("~/.ssh/id\_ed25519.pub") — not the matching private key. There is no password login to fall back on, so a key you cannot use means a VM you cannot reach. | `string` | n/a | yes |
| <a name="input_subnet_id"></a> [subnet\_id](#input\_subnet\_id) | Subnet the private NIC joins. Take this from virtual-network's subnet\_ids output. Azure subnets are regional, so this also fixes the region the VM can run in. | `string` | n/a | yes |
| <a name="input_admin_username"></a> [admin\_username](#input\_admin\_username) | Local administrator username. Azure rejects a list of reserved names (root, admin, administrator and similar) at create time, so a typo here fails the apply rather than the boot. | `string` | `"azureuser"` | no |
| <a name="input_custom_data"></a> [custom\_data](#input\_custom\_data) | Optional cloud-init text, passed as plain text. The module base64-encodes it, so encoding it yourself first produces a VM that boots and silently ignores the configuration. Changing this replaces the VM. | `string` | `null` | no |
| <a name="input_public_ip_enabled"></a> [public\_ip\_enabled](#input\_public\_ip\_enabled) | Create and attach a Standard static public IPv4 address. This does not create an inbound NSG rule. Intended for explicit, short-lived tests. | `bool` | `false` | no |
| <a name="input_size"></a> [size](#input\_size) | Azure VM SKU. Defaults to a general-purpose x86 size with broad regional capacity; override for cheaper burstable SKUs (e.g. Standard\_B1s/B2s) where your region and subscription have capacity. | `string` | `"Standard_D2s_v3"` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Resource tags. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_network_interface_id"></a> [network\_interface\_id](#output\_network\_interface\_id) | Network interface resource ID, for attaching a load balancer backend pool or an application security group. |
| <a name="output_principal_id"></a> [principal\_id](#output\_principal\_id) | System-assigned identity principal ID. Grant Azure roles to this so the VM can reach Key Vault, Storage, or a registry without a stored credential. |
| <a name="output_private_ip_address"></a> [private\_ip\_address](#output\_private\_ip\_address) | Private address on the workload subnet. This is how to reach the VM from a bastion, a VPN, or a peered network. |
| <a name="output_public_ip_address"></a> [public\_ip\_address](#output\_public\_ip\_address) | Allocated public IPv4 address when public\_ip\_enabled is true; otherwise null. Reaching it still needs an inbound NSG rule, which this module does not create. |
| <a name="output_public_ip_id"></a> [public\_ip\_id](#output\_public\_ip\_id) | Public IP resource ID when public\_ip\_enabled is true; otherwise null. |
| <a name="output_vm_id"></a> [vm\_id](#output\_vm\_id) | Virtual machine resource ID. |
<!-- END_TF_DOCS -->
