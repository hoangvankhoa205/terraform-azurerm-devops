resource "azurerm_user_assigned_identity" "this" {
  name                = var.name
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_federated_identity_credential" "github" {
  name                      = var.credential_name
  user_assigned_identity_id = azurerm_user_assigned_identity.this.id
  audience                  = var.audiences
  issuer                    = "https://token.actions.githubusercontent.com"
  subject                   = var.subject
}
