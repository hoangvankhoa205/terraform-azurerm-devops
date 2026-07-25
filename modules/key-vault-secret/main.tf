# for_each is driven by var.secrets, which stays non-sensitive; the value is
# looked up from the sensitive var.secret_values by the same key. Indexing a
# sensitive map yields a sensitive value, which is fine for a resource
# attribute — only for_each rejects one. See variables.tf for the full reason.
#
# A name present in secrets but missing from secret_values fails here with an
# index error naming the key.
resource "azurerm_key_vault_secret" "this" {
  for_each = var.secrets

  name         = each.key
  value        = var.secret_values[each.key]
  key_vault_id = var.key_vault_id

  content_type    = each.value.content_type
  expiration_date = each.value.expiration_date
  not_before_date = each.value.not_before_date
  tags            = merge(var.tags, each.value.tags)
}
