output "assignment_ids" {
  description = "Role assignment IDs keyed by input label."
  value       = { for key, assignment in azurerm_role_assignment.this : key => assignment.id }
}

