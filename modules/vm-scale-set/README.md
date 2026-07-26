# vm-scale-set

A private Linux VM Scale Set with SSH-key-only authentication and a
system-assigned managed identity shared by every instance.

## Usage

`module.network` below is a [`virtual-network`](../virtual-network) instance
declared alongside this one; it supplies the `subnet_ids` map.

```hcl
module "workers" {
  source  = "hoangvankhoa205/devops/azurerm//modules/vm-scale-set"
  version = "0.15.0"

  name                = "learn-vmss"
  location            = "Southeast Asia"
  resource_group_name = "learn-rg"
  subnet_id           = module.network.subnet_ids["workload_private"]
  ssh_public_key      = file("~/.ssh/id_ed25519.pub")

  instances = 3
  sku       = "Standard_B2s"
  zones     = ["1", "2", "3"]
}
```

## Choosing between this and linux-vms

Both give you several Linux machines. They differ in whether the machines are
individuals:

| | `vm-scale-set` | [`linux-vms`](../linux-vms) |
| --- | --- | --- |
| Machines are | interchangeable copies | named individuals |
| Count comes from | one number | the size of a map |
| Per-machine subnet, size, cloud-init | no | yes |
| Addressed as | one resource | a map keyed by your names |
| Suits | stateless workers behind a load balancer | a control node, a build agent, a database host |

If you find yourself wanting instance number 2 to be different, you want
`linux-vms`.

## Manual upgrade mode, and what that costs you

`upgrade_mode` is fixed to `Manual`. Changing the image or `custom_data` updates
the scale set *model*, but running instances keep the old configuration until
somebody rolls them.

That is the safe default here because the alternatives need things this module
does not create: `Automatic` reimages every instance the moment a plan applies,
with no health signal to stop a bad rollout, and `Rolling` requires a health
probe attached to a load balancer.

The practical consequence: after changing `custom_data`, the plan is clean and
nothing happens. Roll the instances yourself with
`az vmss update-instances --instance-ids '*'`, or destroy and recreate.

## Scaling out needs addresses

`instances` is a fixed number — this module ships no autoscale rules, so the
count only changes when you change it. Whatever ceiling you expect to reach,
the subnet must have room for that many addresses. A scale set that cannot
allocate one fails to scale out, and the error surfaces in Azure's activity log
rather than in Terraform.

## Zones are optional because not every region has them

`zones` defaults to empty, which is correct in regions with no availability
zones. Passing a zone list that a region does not recognise fails the apply, so
check the region before setting it.

## Reaching an instance

Instances get private addresses only — there is no `public_ip_address` block
configured, and no per-instance public IPs. Access needs a bastion, a VPN, or a
peered network. Password authentication is disabled, so the SSH key is the only
credential; a key you cannot use means instances you cannot reach.

## What this module leaves out

- **Autoscale rules.** The instance count is whatever you set.
- **Load balancer or Application Gateway**, and therefore any health probe.
- **Automatic instance repair**, which needs that probe.
- **Rolling upgrade policy.**
- **Data disks.** Instances get an OS disk only.

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