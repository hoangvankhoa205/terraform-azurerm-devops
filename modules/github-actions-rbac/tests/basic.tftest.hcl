mock_provider "azurerm" {}

run "plans_narrow_assignment" {
  command = plan

  variables {
    principal_id = "00000000-0000-0000-0000-000000000001"
    assignments = {
      state = {
        scope                = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/learn-state-rg"
        role_definition_name = "Storage Blob Data Contributor"
      }
    }
  }

  assert {
    condition     = azurerm_role_assignment.this["state"].scope == "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/learn-state-rg"
    error_message = "The assignment must land on the scope the caller passed."
  }

  # The module only ever assigns to a managed identity, so principal_type is
  # fixed. Azure rejects the assignment if this disagrees with the real
  # principal, which is why it is asserted rather than left to the provider.
  assert {
    condition     = azurerm_role_assignment.this["state"].principal_type == "ServicePrincipal"
    error_message = "Assignments must be typed as ServicePrincipal for a managed identity."
  }
}

run "creates_one_assignment_per_entry" {
  command = plan

  variables {
    principal_id = "00000000-0000-0000-0000-000000000001"
    assignments = {
      state = {
        scope                = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/learn-state-rg"
        role_definition_name = "Storage Blob Data Contributor"
      }
      workload = {
        scope                = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/learn-workload-rg"
        role_definition_name = "Contributor"
      }
    }
  }

  assert {
    condition     = length(azurerm_role_assignment.this) == 2
    error_message = "Each entry in assignments must produce its own role assignment."
  }

  assert {
    condition     = azurerm_role_assignment.this["workload"].role_definition_name == "Contributor"
    error_message = "Each assignment must keep the role its own entry named."
  }
}

run "rejects_owner_role" {
  command = plan

  variables {
    principal_id = "00000000-0000-0000-0000-000000000001"
    assignments = {
      everything = {
        scope                = "/subscriptions/00000000-0000-0000-0000-000000000000"
        role_definition_name = "Owner"
      }
    }
  }

  expect_failures = [var.assignments]
}

# Owner is rejected even when it rides along with a legitimately narrow role.
run "rejects_owner_alongside_narrow_role" {
  command = plan

  variables {
    principal_id = "00000000-0000-0000-0000-000000000001"
    assignments = {
      state = {
        scope                = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/learn-state-rg"
        role_definition_name = "Storage Blob Data Contributor"
      }
      everything = {
        scope                = "/subscriptions/00000000-0000-0000-0000-000000000000"
        role_definition_name = "Owner"
      }
    }
  }

  expect_failures = [var.assignments]
}

# An empty map grants nothing, which reads as a working pipeline right up until
# the first apply fails on permissions.
run "rejects_empty_assignments" {
  command = plan

  variables {
    principal_id = "00000000-0000-0000-0000-000000000001"
    assignments  = {}
  }

  expect_failures = [var.assignments]
}
