mock_provider "azurerm" {
  mock_resource "azurerm_key_vault_certificate" {
    defaults = {
      id                    = "https://learn-key-vault-001.vault.azure.net/certificates/tls/abc123"
      versionless_id        = "https://learn-key-vault-001.vault.azure.net/certificates/tls"
      secret_id             = "https://learn-key-vault-001.vault.azure.net/secrets/tls/abc123"
      versionless_secret_id = "https://learn-key-vault-001.vault.azure.net/secrets/tls"
      thumbprint            = "0123456789ABCDEF0123456789ABCDEF01234567"
    }
  }
}

variables {
  key_vault_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/learn-rg/providers/Microsoft.KeyVault/vaults/learn-key-vault-001"
  name         = "tls"
  subject      = "CN=example.com"
}

run "plans_a_self_signed_tls_certificate" {
  command = plan

  assert {
    condition     = azurerm_key_vault_certificate.this.certificate_policy[0].issuer_parameters[0].name == "Self"
    error_message = "The default issuer must be Self."

  }
  assert {
    condition = (
      azurerm_key_vault_certificate.this.certificate_policy[0].key_properties[0].key_type == "RSA" &&
      azurerm_key_vault_certificate.this.certificate_policy[0].key_properties[0].key_size == 2048 &&
      azurerm_key_vault_certificate.this.certificate_policy[0].key_properties[0].exportable
    )
    error_message = "Default key properties must be an exportable 2048-bit RSA key."

  }
  assert {
    condition = (
      azurerm_key_vault_certificate.this.certificate_policy[0].x509_certificate_properties[0].subject == "CN=example.com" &&
      azurerm_key_vault_certificate.this.certificate_policy[0].x509_certificate_properties[0].validity_in_months == 12
    )
    error_message = "Subject and validity must reach the policy."

  }
}

# The provider's own documentation example lists six key usages including
# keyCertSign, which would let the certificate sign other certificates. This
# module ships the two a TLS server actually needs.
run "defaults_to_least_privilege_key_usage" {
  command = plan

  # Terraform has no setequal function, and these two attributes are not even
  # the same type — key_usage is a set, extended_key_usage a list. Subtracting
  # both directions tests equality regardless of type or ordering.
  assert {
    condition = (
      length(setsubtract(azurerm_key_vault_certificate.this.certificate_policy[0].x509_certificate_properties[0].key_usage, ["digitalSignature", "keyEncipherment"])) == 0 &&
      length(setsubtract(["digitalSignature", "keyEncipherment"], azurerm_key_vault_certificate.this.certificate_policy[0].x509_certificate_properties[0].key_usage)) == 0
    )
    error_message = "Default key_usage must be the TLS server pair, not the provider example's broader set."

  }
  assert {
    condition = (
      length(setsubtract(azurerm_key_vault_certificate.this.certificate_policy[0].x509_certificate_properties[0].extended_key_usage, ["1.3.6.1.5.5.7.3.1"])) == 0 &&
      length(setsubtract(["1.3.6.1.5.5.7.3.1"], azurerm_key_vault_certificate.this.certificate_policy[0].x509_certificate_properties[0].extended_key_usage)) == 0
    )
    error_message = "Default extended_key_usage must be serverAuth."

  }
}

# An empty SAN block is not the same as no SAN block, so the dynamic block must
# disappear entirely rather than emit an empty one.
run "omits_the_san_block_when_no_dns_names" {
  command = plan

  assert {
    condition     = length(azurerm_key_vault_certificate.this.certificate_policy[0].x509_certificate_properties[0].subject_alternative_names) == 0
    error_message = "With no dns_names the subject_alternative_names block must not be emitted at all."

  }
}

run "emits_the_san_block_when_dns_names_given" {
  command = plan
  variables {
    dns_names = ["example.com", "www.example.com"]
  }

  assert {
    condition = (
      length(setsubtract(azurerm_key_vault_certificate.this.certificate_policy[0].x509_certificate_properties[0].subject_alternative_names[0].dns_names, ["example.com", "www.example.com"])) == 0 &&
      length(setsubtract(["example.com", "www.example.com"], azurerm_key_vault_certificate.this.certificate_policy[0].x509_certificate_properties[0].subject_alternative_names[0].dns_names)) == 0
    )
    error_message = "dns_names must reach subject_alternative_names."

  }
}

run "auto_renew_on_by_default" {
  command = plan

  assert {
    condition = (
      length(azurerm_key_vault_certificate.this.certificate_policy[0].lifetime_action) == 1 &&
      azurerm_key_vault_certificate.this.certificate_policy[0].lifetime_action[0].action[0].action_type == "AutoRenew" &&
      azurerm_key_vault_certificate.this.certificate_policy[0].lifetime_action[0].trigger[0].days_before_expiry == 30
    )
    error_message = "Auto-renewal must be on by default, firing 30 days before expiry."

  }
}

# auto_renew = false is expressed by emitting no lifetime_action at all, since
# the block has no disabling flag.
run "auto_renew_off_emits_no_lifetime_action" {
  command = plan
  variables {
    auto_renew = false
  }

  assert {
    condition     = length(azurerm_key_vault_certificate.this.certificate_policy[0].lifetime_action) == 0
    error_message = "With auto_renew false there must be no lifetime_action block."

  }
}

# key_size applies to RSA and curve to EC, so main.tf nulls whichever does not
# apply. Only the curve half is assertable: key_size is optional/computed, so
# nulling it leaves the attribute unknown at plan and filled by the provider at
# apply — it never reads back as null, whichever command is used.
run "ec_key_sends_the_curve" {
  command = plan
  variables {
    key_type = "EC"
    curve    = "P-384"
  }

  assert {
    condition     = azurerm_key_vault_certificate.this.certificate_policy[0].key_properties[0].curve == "P-384"
    error_message = "An EC key must carry the requested curve."

  }
  assert {
    condition     = azurerm_key_vault_certificate.this.certificate_policy[0].key_properties[0].key_type == "EC"
    error_message = "key_type must reach the policy."

  }
}

run "exportable_and_reuse_key_defaults" {
  command = plan

  assert {
    condition = (
      azurerm_key_vault_certificate.this.certificate_policy[0].key_properties[0].exportable &&
      !azurerm_key_vault_certificate.this.certificate_policy[0].key_properties[0].reuse_key
    )
    error_message = "The key must be exportable by default and must not be reused across renewals."
  }
}

# A non-exportable key cannot be pulled out as a PFX, which is exactly what an
# Application Gateway listener does — so this combination is legal but breaks
# the main consumer, and the variable description says so.
run "exportable_can_be_turned_off" {
  command = plan
  variables {
    exportable = false
  }

  assert {
    condition     = !azurerm_key_vault_certificate.this.certificate_policy[0].key_properties[0].exportable
    error_message = "exportable must be honoured when a caller turns it off."
  }
}

run "reuse_key_can_be_turned_on" {
  command = plan
  variables {
    reuse_key = true
  }

  assert {
    condition     = azurerm_key_vault_certificate.this.certificate_policy[0].key_properties[0].reuse_key
    error_message = "reuse_key must be honoured when a caller turns it on."
  }
}

run "content_type_defaults_to_pfx" {
  command = plan

  assert {
    condition     = azurerm_key_vault_certificate.this.certificate_policy[0].secret_properties[0].content_type == "application/x-pkcs12"
    error_message = "The backing secret must default to PFX, which is what Application Gateway expects."
  }
}

run "content_type_can_be_pem" {
  command = plan
  variables {
    content_type = "application/x-pem-file"
  }

  assert {
    condition     = azurerm_key_vault_certificate.this.certificate_policy[0].secret_properties[0].content_type == "application/x-pem-file"
    error_message = "A PEM content type must reach the policy."
  }
}

run "renew_window_is_configurable" {
  command = plan
  variables {
    renew_days_before_expiry = 60
  }

  assert {
    condition     = azurerm_key_vault_certificate.this.certificate_policy[0].lifetime_action[0].trigger[0].days_before_expiry == 60
    error_message = "renew_days_before_expiry must reach the lifetime action trigger."
  }
}

run "extended_key_usage_supports_mutual_tls" {
  command = plan
  variables {
    extended_key_usage = ["1.3.6.1.5.5.7.3.1", "1.3.6.1.5.5.7.3.2"]
  }

  assert {
    condition     = length(azurerm_key_vault_certificate.this.certificate_policy[0].x509_certificate_properties[0].extended_key_usage) == 2
    error_message = "A caller must be able to add clientAuth for mutual TLS."
  }
}

run "tags_reach_the_certificate" {
  command = plan
  variables {
    tags = { env = "learn" }
  }

  assert {
    condition     = azurerm_key_vault_certificate.this.tags["env"] == "learn"
    error_message = "Tags must reach the certificate."
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# OUTPUTS
# ---------------------------------------------------------------------------------------------------------------------

# The distinction these five outputs draw is the module's headline gotcha: a
# certificate is stored twice, and the thing an Application Gateway listener
# consumes is the SECRET id, not the certificate id.
run "exposes_certificate_and_secret_ids_separately" {
  command = apply

  assert {
    condition = (
      output.certificate_id == azurerm_key_vault_certificate.this.id &&
      output.versionless_id == azurerm_key_vault_certificate.this.versionless_id &&
      output.secret_id == azurerm_key_vault_certificate.this.secret_id &&
      output.versionless_secret_id == azurerm_key_vault_certificate.this.versionless_secret_id &&
      output.thumbprint == azurerm_key_vault_certificate.this.thumbprint
    )
    error_message = "All five certificate identifiers must be exposed."
  }

  # If these ever collapsed to the same value the documented distinction would
  # be meaningless and callers could not tell which one they had.
  assert {
    condition = (
      output.certificate_id != output.secret_id &&
      output.versionless_id != output.versionless_secret_id &&
      output.certificate_id != output.versionless_id
    )
    error_message = "Certificate ids and secret ids must be distinct, and versioned must differ from versionless."
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# VALIDATION
# ---------------------------------------------------------------------------------------------------------------------

run "rejects_hsm_key_type" {
  command = plan
  variables {
    key_type = "RSA-HSM"
  }

  expect_failures = [var.key_type]
}

run "rejects_underscore_in_name" {
  command = plan
  variables {
    name = "tls_cert"
  }

  expect_failures = [var.name]
}

run "rejects_subject_without_cn" {
  command = plan
  variables {
    subject = "example.com"
  }

  expect_failures = [var.subject]
}

run "rejects_odd_key_size" {
  command = plan
  variables {
    key_size = 1024
  }

  expect_failures = [var.key_size]
}

run "rejects_an_unknown_curve" {
  command = plan
  variables {
    key_type = "EC"
    curve    = "P-192"
  }

  expect_failures = [var.curve]
}

run "rejects_zero_validity" {
  command = plan
  variables {
    validity_in_months = 0
  }

  expect_failures = [var.validity_in_months]
}

run "rejects_validity_beyond_ten_years" {
  command = plan
  variables {
    validity_in_months = 121
  }

  expect_failures = [var.validity_in_months]
}

run "rejects_an_unknown_content_type" {
  command = plan
  variables {
    content_type = "application/x-pkcs7"
  }

  expect_failures = [var.content_type]
}

run "rejects_a_zero_day_renew_window" {
  command = plan
  variables {
    renew_days_before_expiry = 0
  }

  expect_failures = [var.renew_days_before_expiry]
}
