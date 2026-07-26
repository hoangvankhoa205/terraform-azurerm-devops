mock_provider "azurerm" {
  mock_resource "azurerm_role_assignment" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/learn-state-rg/providers/Microsoft.Authorization/roleAssignments/44444444-4444-4444-4444-444444444444"
    }
  }
}

variables {
  principal_id = "00000000-0000-0000-0000-000000000001"
  assignments = {
    state = {
      scope                = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/learn-state-rg"
      role_definition_name = "Storage Blob Data Contributor"
    }
  }
}

run "plans_narrow_assignment" {
  command = plan

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

# Every assignment goes to the one principal the module was given. Nothing in
# the assignments map can redirect a grant to a different identity.
run "every_assignment_targets_the_supplied_principal" {
  command = plan
  variables {
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
    condition = alltrue([
      for assignment in values(azurerm_role_assignment.this) : assignment.principal_id == var.principal_id
    ])
    error_message = "Every assignment must be granted to the principal_id the caller supplied."
  }
}

run "creates_one_assignment_per_entry" {
  command = plan
  variables {
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

  # Each entry keeps its own scope. A single shared scope would quietly widen
  # or narrow one of the grants.
  assert {
    condition     = azurerm_role_assignment.this["state"].scope != azurerm_role_assignment.this["workload"].scope
    error_message = "Each assignment must keep the scope its own entry named."
  }
}

# The ids are what a caller needs to wait on, since RBAC propagation is
# eventually consistent and a dependent apply can otherwise race the grant.
run "exposes_assignment_ids_keyed_by_label" {
  command = apply

  assert {
    condition = (
      length(setsubtract(keys(output.assignment_ids), keys(var.assignments))) == 0 &&
      output.assignment_ids["state"] == azurerm_role_assignment.this["state"].id
    )
    error_message = "assignment_ids must be keyed by the caller's labels and carry each assignment's id."
  }
}

run "rejects_owner_role" {
  command = plan
  variables {
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
    assignments = {}
  }

  expect_failures = [var.assignments]
}
