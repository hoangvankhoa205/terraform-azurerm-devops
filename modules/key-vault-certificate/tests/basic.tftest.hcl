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
