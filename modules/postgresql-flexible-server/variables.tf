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
  description = "Subnet delegated to Microsoft.DBforPostgreSQL/flexibleServers."
  type        = string
}

variable "private_dns_zone_id" {
  description = "Private DNS zone ID for delegated networking."
  type        = string
}

variable "administrator_password" {
  description = "Database administrator password; source this from a secret store."
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
  description = "Flexible Server compute SKU."
  type        = string
  default     = "B_Standard_B1ms"
}

variable "storage_mb" {
  description = "Storage allocation in MiB."
  type        = number
  default     = 32768
}

variable "backup_retention_days" {
  description = "Point-in-time restore retention."
  type        = number
  default     = 7
  validation {
    condition     = var.backup_retention_days >= 7 && var.backup_retention_days <= 35
    error_message = "backup_retention_days must be 7-35."
  }
}

variable "zone" {
  description = "Primary availability zone or null."
  type        = string
  default     = null
}

variable "high_availability" {
  description = "Optional same-zone or zone-redundant HA settings."
  type = object({
  mode = string, standby_availability_zone = optional(string) })
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
