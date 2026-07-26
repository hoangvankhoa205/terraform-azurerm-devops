# The registry only. Images, Private Endpoints, and the privatelink DNS zone a
# private registry needs are the caller's, the same way key-vault builds the
# vault and leaves the secrets to the root.
#
# admin_enabled is hard-coded false rather than exposed as a variable. The admin
# account is a single username and password stored on the registry itself: every
# consumer shares it, it cannot be scoped, and it bypasses Entra entirely. A
# managed identity holding AcrPull is the alternative, so there is no
# configuration here worth offering.
resource "azurerm_container_registry" "this" {
  name                          = var.name
  location                      = var.location
  resource_group_name           = var.resource_group_name
  sku                           = var.sku
  admin_enabled                 = false
  public_network_access_enabled = var.public_network_access_enabled
  tags                          = var.tags
}
