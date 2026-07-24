# AzureRM DevOps Module Collection

Reusable AzureRM implementations of the infrastructure concepts demonstrated by
[`brikis98/terraform-book-devops`](https://github.com/brikis98/terraform-book-devops).
This is an independent community module collection: it is not an official
Azure Verified Module and is not affiliated with the original project.

> **Status:** early work in progress. The collection currently ships five
> modules, [`linux-vm`](./modules/linux-vm),
> [`linux-vms`](./modules/linux-vms),
> [`state-storage`](./modules/state-storage),
> [`front-door-static-website`](./modules/front-door-static-website), and
> [`virtual-network`](./modules/virtual-network). More Azure modules will be
> added over time — see [Roadmap](#roadmap).

The root module deliberately creates no resources. Pick a module from
[`modules/`](./modules) and compose it in your own root configuration.

The GitHub repository name is `terraform-azurerm-devops`, which produces the
Terraform Registry package address `hoangvankhoa205/devops/azurerm`.

```hcl
module "vm" {
  source  = "hoangvankhoa205/devops/azurerm//modules/linux-vm"
  version = "0.4.0"

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
| [`linux-vms`](./modules/linux-vms) | Multiple private Ubuntu VMs from a `for_each` map of instance definitions. SSH-key-only auth and a managed identity per VM; no public IP. |
| [`state-storage`](./modules/state-storage) | Hardened Blob container for Terraform/OpenTofu remote state: versioning, soft delete, TLS 1.2, shared-key auth disabled (Entra ID/OIDC only), and deny-by-default networking. Blob leases provide native state locking. |
| [`front-door-static-website`](./modules/front-door-static-website) | Fronts a Storage static-website origin with Front Door Standard/Premium and forces HTTPS. Serves on the default `*.azurefd.net` hostname; custom domain, WAF, and Private Link are left to the caller. |
| [`virtual-network`](./modules/virtual-network) | A VNet with subnets from a `for_each` map keyed by role, each with an auto-created NSG and association. Supports per-subnet service endpoints, delegation, and opt-in default outbound access. |

## Roadmap

Planned modules (not yet implemented). This list is aspirational and will
change:

- `container-registry`, `aks-cluster`
- `key-vault-key`, `postgresql-flexible-server`
- `github-actions-federated-identity`

## Compatibility

- Terraform `>= 1.9, < 2.0`
- OpenTofu `>= 1.9, < 2.0`
- AzureRM `>= 4.81.0, < 5.0.0`

Modules configure no providers or backends. Configure those only in a root
module. Run `terraform test` or `tofu test` in an individual module directory;
the tests mock providers and do not deploy Azure resources.

## License

MIT.
