# virtual-network

A virtual network with subnets defined as a map keyed by role, each getting its
own empty network security group, already associated.

## Usage

```hcl
module "network" {
  source  = "hoangvankhoa205/devops/azurerm//modules/virtual-network"
  version = "0.15.0"

  name                = "learn-vnet"
  location            = "Southeast Asia"
  resource_group_name = "learn-rg"
  address_space       = ["10.42.0.0/16"]

  subnets = {
    workload_private = {
      address_prefixes = ["10.42.1.0/24"]
    }

    # A subnet PostgreSQL Flexible Server can be injected into. The delegation
    # is mandatory for that service and makes the subnet exclusive to it.
    data_private = {
      address_prefixes = ["10.42.2.0/24"]
      delegation = {
        service_name = "Microsoft.DBforPostgreSQL/flexibleServers"
        actions      = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
      }
    }
  }
}

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

## Azure subnets are regional, so role names are not zones

There is no AWS-style pattern of a public and a private subnet in each
availability zone. An Azure subnet spans every zone in its region, and a VM
chooses its zone independently of which subnet it sits in.

So a subnet key describes **what runs there** — `workload_private`,
`data_private` — rather than where it sits. Zone spreading is a property of
[`vm-scale-set`](../vm-scale-set) or of individual VMs, not of this module.

## The map key is load-bearing

The key you choose becomes three things:

1. The subnet's Azure name, with underscores rewritten to hyphens
   (`workload_private` → `workload-private`).
2. The NSG name, with the key left **unmodified**
   (`learn-vnet-workload_private-nsg`).
3. The key of every map this module outputs.

That asymmetry between (1) and (2) is deliberate and pinned by a test: renaming
an NSG destroys and recreates it, taking every rule a caller has added with it.

Renaming a key therefore replaces the subnet. Choose keys you can live with.

## Every subnet gets an empty NSG, on purpose

Azure's built-in rules already allow traffic within the VNet and deny inbound
from the Internet, so an empty group changes nothing on day one. What it buys is
somewhere to put a rule later without first having to create a group, associate
it, and work out why traffic stopped in between.

Add rules at the group this module hands back:

```hcl
resource "azurerm_network_security_rule" "ssh_from_bastion" {
  name                        = "allow-ssh-from-bastion"
  resource_group_name         = "learn-rg"
  network_security_group_name = module.network.network_security_group_names["workload_private"]

  priority                   = 100
  direction                  = "Inbound"
  access                     = "Allow"
  protocol                   = "Tcp"
  source_port_range          = "*"
  destination_port_range     = "22"
  source_address_prefix      = "10.42.3.0/24"
  destination_address_prefix = "*"
}
```

## Outbound access is off by default

`default_outbound_access_enabled` defaults to `false` on every subnet. Azure's
default outbound access gives instances an unpredictable, shared set of source
addresses that Microsoft is retiring, and which cannot be allow-listed by anyone
downstream.

A workload that genuinely needs egress should get a NAT Gateway with an address
you control. Flipping this to `true` is available for a lab where that is
overkill — but it is a deliberate choice rather than a default.

## What this module leaves out

- **Security rules.** The groups are created empty.
- **NAT Gateways, route tables, and peering.**
- **Bastion.** These subnets are private; reaching a VM in them needs a bastion,
  a VPN, or a peered network.
- **Private DNS zones**, including the one
  [`postgresql-flexible-server`](../postgresql-flexible-server) needs.

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
| [azurerm_network_security_group.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/network_security_group) | resource |
| [azurerm_subnet.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subnet) | resource |
| [azurerm_subnet_network_security_group_association.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subnet_network_security_group_association) | resource |
| [azurerm_virtual_network.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_network) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_address_space"></a> [address\_space](#input\_address\_space) | CIDR ranges assigned to the virtual network. Every subnet prefix must fall inside one of these. Adding a range later is non-disruptive; shrinking one that subnets already occupy is not. | `list(string)` | n/a | yes |
| <a name="input_location"></a> [location](#input\_location) | Azure region. | `string` | n/a | yes |
| <a name="input_name"></a> [name](#input\_name) | Virtual network name. Also prefixes every generated network security group name, as <name>-<subnet key>-nsg. | `string` | n/a | yes |
| <a name="input_resource_group_name"></a> [resource\_group\_name](#input\_resource\_group\_name) | Existing resource group name. | `string` | n/a | yes |
| <a name="input_subnets"></a> [subnets](#input\_subnets) | Subnets keyed by role, such as workload\_private or data\_private. The key becomes the subnet name with underscores rewritten to hyphens, and is the key of every map this module outputs — so renaming a key replaces the subnet. Azure subnets are regional and span all availability zones in the region, so a role name describes what runs there rather than where it sits; there is no AWS-style public and private subnet per zone. | <pre>map(object({<br/>    address_prefixes                = list(string)<br/>    service_endpoints               = optional(list(string), [])<br/>    default_outbound_access_enabled = optional(bool, false)<br/>    delegation = optional(object({<br/>      name         = optional(string, "service-delegation")<br/>      service_name = string<br/>      actions      = optional(list(string), [])<br/>    }))<br/>  }))</pre> | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | Resource tags. Applied to the virtual network and to every generated network security group. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_network_security_group_ids"></a> [network\_security\_group\_ids](#output\_network\_security\_group\_ids) | Network security group IDs keyed by subnet role. Add azurerm\_network\_security\_rule resources at these scopes; the groups this module creates are empty. |
| <a name="output_network_security_group_names"></a> [network\_security\_group\_names](#output\_network\_security\_group\_names) | Network security group names keyed by subnet role, for az CLI calls that take --nsg-name. |
| <a name="output_subnet_ids"></a> [subnet\_ids](#output\_subnet\_ids) | Subnet IDs keyed by the supplied role names. Pass one of these to linux-vm, vm-scale-set, or postgresql-flexible-server. |
| <a name="output_vnet_id"></a> [vnet\_id](#output\_vnet\_id) | Virtual network resource ID. |
| <a name="output_vnet_name"></a> [vnet\_name](#output\_vnet\_name) | Virtual network name. |
<!-- END_TF_DOCS -->