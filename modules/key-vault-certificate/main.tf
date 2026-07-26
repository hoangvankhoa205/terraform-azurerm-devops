# A certificate Key Vault ISSUES. Importing an existing PFX is deliberately out
# of scope: it uses a different block (`certificate`, carrying base64 key
# material and a password) and would drag private key bytes through Terraform
# state. Import one directly with azurerm_key_vault_certificate in your root if
# you need it.
resource "azurerm_key_vault_certificate" "this" {
  name         = var.name
  key_vault_id = var.key_vault_id
  tags         = var.tags

  certificate_policy {
    issuer_parameters {
      name = var.issuer_name
    }

    key_properties {
      exportable = var.exportable
      key_type   = var.key_type
      reuse_key  = var.reuse_key

      # key_size applies to RSA and curve to EC; both are optional/computed, so
      # the unused one is left null rather than sent as a contradictory value.
      key_size = var.key_type == "RSA" ? var.key_size : null
      curve    = var.key_type == "EC" ? var.curve : null
    }

    secret_properties {
      content_type = var.content_type
    }

    # lifetime_action accepts zero or more entries, so auto_renew = false is
    # expressed by emitting none at all rather than by a disabling flag.
    dynamic "lifetime_action" {
      for_each = var.auto_renew ? [1] : []
      content {
        action {
          action_type = "AutoRenew"
        }
        trigger {
          days_before_expiry = var.renew_days_before_expiry
        }
      }
    }

    x509_certificate_properties {
      subject            = var.subject
      validity_in_months = var.validity_in_months
      key_usage          = var.key_usage
      extended_key_usage = var.extended_key_usage

      # Omitted entirely when no DNS names are given — an empty SAN block is
      # not the same as no SAN block.
      dynamic "subject_alternative_names" {
        for_each = length(var.dns_names) > 0 ? [1] : []
        content {
          dns_names = var.dns_names
        }
      }
    }
  }
}
