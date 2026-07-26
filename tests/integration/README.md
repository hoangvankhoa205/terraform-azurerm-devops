# Integration tests

> **These create real, billable Azure resources.** Everything else in this
> repository mocks its providers and costs nothing. This directory does not.

## Why this exists

The mocked suites under `modules/*/tests/` prove that configuration is wired
correctly: that a variable reaches the resource it should, that a validation
fires, that a `for_each` is not transposed. They cannot prove Azure *accepts*
the result — that a subnet delegation is valid, that a globally unique name
passes server-side rules, or that a vault's RBAC really does admit the caller.

`.github/workflows/release.yml` refuses to cut a `1.0.0` tag without
"credentialed Azure integration and upgrade evidence". This is that evidence.

## Status

**This suite has never been executed.** It was written alongside the mocked
tests but has not been run against a real subscription, because doing so
provisions billable resources. Treat the first run as part of the work, not as a
regression check — expect to fix things.

## What it covers

One composed environment: `virtual-network` → `linux-vm`, plus `key-vault` →
`key-vault-secret`. The assertions deliberately target what mocking cannot
reach:

| Assertion | Why a mock cannot prove it |
| --- | --- |
| The VM has a real private IPv4 address | Azure allocated it from the subnet |
| The identity principal is a GUID | Entra minted it |
| An NSG exists per subnet and is associated | Azure allowed the association |
| The vault URI matches its name | The globally unique name was accepted |
| A secret was written | The RBAC role propagated and the data plane admitted the caller |

That last one is the point. `key-vault`'s README claims control-plane rights
grant nothing and every data-plane call needs an Entra role. Only a real apply
tests that claim.

## Running it

You need an authenticated Azure session with rights to create a resource group,
a VNet, a VM, and a Key Vault, and to assign roles at the vault's scope
(`User Access Administrator` or `Owner` on the subscription, since the run
grants itself `Key Vault Secrets Officer`).

```sh
cd tests/integration
terraform init
terraform test
```

`terraform test` destroys what it created when the run finishes, including on
failure. If it is interrupted, clean up by hand:

```sh
az group list --tag purpose=terraform-azurerm-devops-integration -o tsv --query '[].name' \
  | xargs -r -n1 az group delete --yes --no-wait
```

Every run generates a random suffix, so a leftover environment never blocks the
next one. The Key Vault is created with `purge_protection_enabled = false` and a
seven-day soft-delete window, and the provider is configured to purge on
destroy — without that, a failed run would reserve its vault name for days.

## Cost

A `Standard_B1s` VM, a standard Key Vault, and a VNet, alive for the few minutes
the run takes. Pennies per run, but not free, and not zero if a run is
interrupted and leaves resources behind.

## Not covered

The other twelve modules. Extend `main.tf` rather than adding directories — the
value here is in composing modules the way a real root configuration does, and
a second isolated environment would mostly duplicate the setup cost.
