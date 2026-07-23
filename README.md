# AzureRM DevOps Module Collection

Reusable AzureRM implementations of the infrastructure concepts demonstrated by
[`brikis98/terraform-book-devops`](https://github.com/brikis98/terraform-book-devops).
This is an independent community module collection: it is not an official
Azure Verified Module and is not affiliated with the original project.

> **Status:** early work in progress. The collection currently ships a single
> module, [`linux-vm`](./modules/linux-vm). More Azure modules will be added
> over time — see [Roadmap](#roadmap).

The root module deliberately creates no resources. Pick a module from
[`modules/`](./modules) and compose it in your own root configuration.

The GitHub repository name is `terraform-azurerm-devops`, which produces the
Terraform Registry package address `hoangvankhoa205/devops/azurerm`.

```hcl
module "vm" {
  source  = "hoangvankhoa205/devops/azurerm//modules/linux-vm"
  version = "0.1.1"

  name                = "learn-vm"
  location            = "Southeast Asia"
  resource_group_name = "learn-rg"
  subnet_id           = azurerm_subnet.workload.id
  ssh_public_key      = file("~/.ssh/id_ed25519.pub")
}
```

## Safety boundary

These modules are intentionally concise so callers can compose each Azure
resource. They avoid embedded credentials, public-by-default VM NICs, and
implicit resource-group creation. The `linux-vm` public IP is opt-in and does
not open ingress by itself. These are reference components, not a complete
production landing zone.

## Modules

| Module | Description |
| ------ | ----------- |
| [`linux-vm`](./modules/linux-vm) | One Ubuntu VM with SSH-key-only auth and a system-assigned managed identity. Private NIC by default; `public_ip_enabled` is opt-in and does not open an NSG rule. |

## Roadmap

Planned modules (not yet implemented). This list is aspirational and will
change:

- `virtual-network`
- `linux-vms` (multi-VM)
- `container-registry`, `aks-cluster`
- `key-vault-key`, `postgresql-flexible-server`
- `state-storage`, `github-actions-federated-identity`

## Compatibility

- Terraform `>= 1.9, < 2.0`
- OpenTofu `>= 1.9, < 2.0`
- AzureRM `>= 4.81.0, < 5.0.0`

Modules configure no providers or backends. Configure those only in a root
module. Run `terraform test` or `tofu test` in an individual module directory;
the tests mock providers and do not deploy Azure resources.

## License

MIT.
