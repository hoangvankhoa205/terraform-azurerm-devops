mock_provider "azurerm" {
  mock_resource "azurerm_user_assigned_identity" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/learn-identity-rg/providers/Microsoft.ManagedIdentity/userAssignedIdentities/learn-gh-dev"
    }
  }
}

# Runs against the mocked provider, so it creates nothing in Azure. `apply`
# rather than `plan` because the identity's ID is computed and stays unknown
# through the plan phase, which makes the parenting assertion unevaluable.
run "applies_exact_environment_subject" {
  command = apply

  variables {
    name                = "learn-gh-dev"
    location            = "Southeast Asia"
    resource_group_name = "learn-identity-rg"
    subject             = "repo:hoangkhoaa2005/devops-book-azure:environment:dev"
  }

  assert {
    condition     = azurerm_federated_identity_credential.github.subject == "repo:hoangkhoaa2005/devops-book-azure:environment:dev"
    error_message = "The credential must trust the exact subject the caller asked for."
  }

  assert {
    condition     = length(azurerm_federated_identity_credential.github.audience) == 1 && azurerm_federated_identity_credential.github.audience[0] == "api://AzureADTokenExchange"
    error_message = "The default audience must be exactly the Entra ID token-exchange audience."
  }

  # The credential must hang off the identity this module creates, so a caller
  # cannot federate someone else's identity by passing a stray id.
  assert {
    condition     = azurerm_federated_identity_credential.github.user_assigned_identity_id == azurerm_user_assigned_identity.this.id
    error_message = "The credential must be parented to the identity this module creates."
  }
}

run "rejects_wildcard_subject" {
  command = plan

  variables {
    name                = "learn-gh-dev"
    location            = "Southeast Asia"
    resource_group_name = "learn-identity-rg"
    subject             = "repo:hoangkhoaa2005/devops-book-azure:*"
  }

  expect_failures = [var.subject]
}

# A repo-only subject trusts every workflow in the repository, which defeats the
# per-environment boundary this module exists to draw.
run "rejects_repo_only_subject" {
  command = plan

  variables {
    name                = "learn-gh-dev"
    location            = "Southeast Asia"
    resource_group_name = "learn-identity-rg"
    subject             = "repo:hoangkhoaa2005/devops-book-azure"
  }

  expect_failures = [var.subject]
}

run "accepts_branch_ref_subject" {
  command = plan

  variables {
    name                = "learn-gh-main"
    location            = "Southeast Asia"
    resource_group_name = "learn-identity-rg"
    subject             = "repo:hoangkhoaa2005/devops-book-azure:ref:refs/heads/main"
  }

  assert {
    condition     = azurerm_federated_identity_credential.github.subject == "repo:hoangkhoaa2005/devops-book-azure:ref:refs/heads/main"
    error_message = "A branch ref subject must be accepted unchanged."
  }
}
