mock_provider "azurerm" {
  mock_resource "azurerm_user_assigned_identity" {
    defaults = {
      id           = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/learn-identity-rg/providers/Microsoft.ManagedIdentity/userAssignedIdentities/learn-gh-dev"
      client_id    = "11111111-1111-1111-1111-111111111111"
      principal_id = "22222222-2222-2222-2222-222222222222"
      tenant_id    = "33333333-3333-3333-3333-333333333333"
    }
  }
}

variables {
  name                = "learn-gh-dev"
  location            = "Southeast Asia"
  resource_group_name = "learn-identity-rg"
  subject             = "repo:hoangkhoaa2005/devops-book-azure:environment:dev"
}

# Runs against the mocked provider, so it creates nothing in Azure. `apply`
# rather than `plan` because the identity's ID is computed and stays unknown
# through the plan phase, which makes the parenting assertion unevaluable.
run "applies_exact_environment_subject" {
  command = apply

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

# The issuer is hard-coded, not a variable. It is the single URL that GitHub
# signs Actions tokens with; making it configurable would only ever let a caller
# trust a different, untrusted issuer.
run "issuer_is_githubs_and_is_not_configurable" {
  command = plan

  assert {
    condition     = azurerm_federated_identity_credential.github.issuer == "https://token.actions.githubusercontent.com"
    error_message = "The issuer must be GitHub's Actions OIDC endpoint."
  }
}

run "credential_name_defaults_and_is_overridable" {
  command = plan

  assert {
    condition     = azurerm_federated_identity_credential.github.name == "github-actions"
    error_message = "credential_name must default to github-actions."
  }
}

run "credential_name_override_reaches_the_credential" {
  command = plan
  variables {
    credential_name = "deploy-dev"
  }

  assert {
    condition     = azurerm_federated_identity_credential.github.name == "deploy-dev"
    error_message = "credential_name must reach the credential."
  }
}

run "audience_is_overridable" {
  command = plan
  variables {
    audiences = ["api://custom"]
  }

  assert {
    condition = (
      length(azurerm_federated_identity_credential.github.audience) == 1 &&
      azurerm_federated_identity_credential.github.audience[0] == "api://custom"
    )
    error_message = "A caller-supplied audience must reach the credential."
  }
}

# Azure accepts exactly one audience. Without this validation the provider
# rejects a second entry with a message that points at the resource attribute
# rather than at the variable the caller actually set.
run "rejects_more_than_one_audience" {
  command = plan
  variables {
    audiences = ["api://AzureADTokenExchange", "api://custom"]
  }

  expect_failures = [var.audiences]
}

run "rejects_an_empty_audience_list" {
  command = plan
  variables {
    audiences = []
  }

  expect_failures = [var.audiences]
}

run "tags_reach_the_identity" {
  command = plan
  variables {
    tags = { env = "learn" }
  }

  assert {
    condition     = azurerm_user_assigned_identity.this.tags["env"] == "learn"
    error_message = "Tags must reach the managed identity."
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# SUBJECT FORMS — every branch the validation permits
# ---------------------------------------------------------------------------------------------------------------------

run "accepts_branch_ref_subject" {
  command = plan
  variables {
    name    = "learn-gh-main"
    subject = "repo:hoangkhoaa2005/devops-book-azure:ref:refs/heads/main"
  }

  assert {
    condition     = azurerm_federated_identity_credential.github.subject == "repo:hoangkhoaa2005/devops-book-azure:ref:refs/heads/main"
    error_message = "A branch ref subject must be accepted unchanged."
  }
}

run "accepts_tag_ref_subject" {
  command = plan
  variables {
    subject = "repo:hoangkhoaa2005/devops-book-azure:ref:refs/tags/v1.0.0"
  }

  assert {
    condition     = azurerm_federated_identity_credential.github.subject == "repo:hoangkhoaa2005/devops-book-azure:ref:refs/tags/v1.0.0"
    error_message = "A tag ref subject must be accepted unchanged."
  }
}

# pull_request has no trailing value: GitHub emits exactly this subject for a
# workflow triggered by a PR, regardless of branch.
run "accepts_pull_request_subject" {
  command = plan
  variables {
    subject = "repo:hoangkhoaa2005/devops-book-azure:pull_request"
  }

  assert {
    condition     = azurerm_federated_identity_credential.github.subject == "repo:hoangkhoaa2005/devops-book-azure:pull_request"
    error_message = "A pull_request subject must be accepted unchanged."
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# OUTPUTS
# ---------------------------------------------------------------------------------------------------------------------

# These four are exactly what an azure/login step needs: client_id and tenant_id
# go in the workflow, principal_id is what github-actions-rbac grants roles to.
run "exposes_everything_a_login_step_needs" {
  command = apply

  assert {
    condition = (
      output.identity_id == azurerm_user_assigned_identity.this.id &&
      output.client_id == azurerm_user_assigned_identity.this.client_id &&
      output.principal_id == azurerm_user_assigned_identity.this.principal_id &&
      output.tenant_id == azurerm_user_assigned_identity.this.tenant_id
    )
    error_message = "The identity id, client id, principal id, and tenant id must all be exposed."
  }

  # client_id and principal_id are different GUIDs for the same identity and are
  # easy to confuse; azure/login wants the client id, RBAC wants the principal.
  assert {
    condition     = output.client_id != output.principal_id
    error_message = "client_id and principal_id must be distinct values."
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# VALIDATION
# ---------------------------------------------------------------------------------------------------------------------

run "rejects_wildcard_subject" {
  command = plan
  variables {
    subject = "repo:hoangkhoaa2005/devops-book-azure:*"
  }

  expect_failures = [var.subject]
}

# A repo-only subject trusts every workflow in the repository, which defeats the
# per-environment boundary this module exists to draw.
run "rejects_repo_only_subject" {
  command = plan
  variables {
    subject = "repo:hoangkhoaa2005/devops-book-azure"
  }

  expect_failures = [var.subject]
}

run "rejects_a_wildcard_environment" {
  command = plan
  variables {
    subject = "repo:hoangkhoaa2005/devops-book-azure:environment:*"
  }

  expect_failures = [var.subject]
}

run "rejects_a_subject_with_no_repo_prefix" {
  command = plan
  variables {
    subject = "hoangkhoaa2005/devops-book-azure:environment:dev"
  }

  expect_failures = [var.subject]
}
