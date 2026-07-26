# ---------------------------------------------------------------------------------------------------------------------
# REQUIRED PARAMETERS
# ---------------------------------------------------------------------------------------------------------------------

variable "name" {
  description = "Globally unique PostgreSQL server name."
  type        = string
}

variable "location" {
  description = "Azure region."
  type        = string
}

variable "resource_group_name" {
  description = "Existing resource group name."
  type        = string
}

variable "delegated_subnet_id" {
  description = "Subnet delegated to Microsoft.DBforPostgreSQL/flexibleServers. The delegation is mandatory and exclusive: nothing else may share the subnet. virtual-network creates one via a subnet's `delegation` block."
  type        = string
}

variable "private_dns_zone_id" {
  description = "Private DNS zone the server registers its FQDN in. Azure requires the zone name to end in .postgres.database.azure.com — any other suffix fails the apply. The zone must also be linked to the VNet, or clients resolve nothing."
  type        = string
}

variable "administrator_password" {
  description = "Database administrator password. Source it from a secret store rather than a variable file: whatever you pass lands in Terraform state in cleartext. This module never returns it in an output."
  type        = string
  sensitive   = true
}

# ---------------------------------------------------------------------------------------------------------------------
# OPTIONAL PARAMETERS
# ---------------------------------------------------------------------------------------------------------------------

variable "administrator_login" {
  description = "Database administrator username."
  type        = string
  default     = "pgadminuser"
}

variable "postgres_version" {
  description = "PostgreSQL major version."
  type        = string
  default     = "16"
}

variable "sku_name" {
  description = "Compute SKU, in Azure's tier-prefixed form: B_ for burstable, GP_ for general purpose, MO_ for memory optimised — for example B_Standard_B1ms or GP_Standard_D2s_v3. A bare VM size such as Standard_D2s_v3 is rejected, which is the most common mistake here."
  type        = string
  default     = "B_Standard_B1ms"
}

variable "storage_mb" {
  description = "Storage allocation in MiB; 32768 is 32 GiB. Storage can be grown but never shrunk, and growing it may briefly restart the server."
  type        = number
  default     = 32768
}

variable "backup_retention_days" {
  description = "How far back point-in-time restore can reach. Azure permits 7-35."
  type        = number
  default     = 7
  validation {
    condition     = var.backup_retention_days >= 7 && var.backup_retention_days <= 35
    error_message = "backup_retention_days must be 7-35."
  }
}

variable "zone" {
  description = "Availability zone for the primary, as a string such as \"1\". Null lets Azure choose. Set it explicitly when using ZoneRedundant HA so the standby lands somewhere different."
  type        = string
  default     = null
}

variable "high_availability" {
  description = "Optional hot standby. SameZone protects against node failure; ZoneRedundant also protects against losing a zone, and needs a region that has zones. Either mode roughly doubles the compute bill. The standby is NOT a readable replica — it serves no queries and exists only to fail over."
  type = object({
    mode                      = string
    standby_availability_zone = optional(string)
  })
  default = null
  validation {
    condition     = var.high_availability == null || contains(["SameZone", "ZoneRedundant"], var.high_availability.mode)
    error_message = "HA mode must be SameZone or ZoneRedundant."

  }
}

variable "tags" {
  description = "Resource tags."
  type        = map(string)
  default     = {}
}
