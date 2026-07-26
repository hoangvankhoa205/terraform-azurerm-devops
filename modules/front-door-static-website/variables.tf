# ---------------------------------------------------------------------------------------------------------------------
# REQUIRED PARAMETERS
# ---------------------------------------------------------------------------------------------------------------------

variable "name" {
  description = "Front Door profile name. Scoped to the resource group, so it does not need to be globally unique."
  type        = string
}

variable "endpoint_name" {
  description = "Front Door endpoint name. Unlike the profile name this DOES have to be globally unique: it becomes the public hostname, <endpoint_name>.z01.azurefd.net."
  type        = string
}

variable "resource_group_name" {
  description = "Existing resource group name."
  type        = string
}

variable "origin_host_name" {
  description = "Static website origin host, with no URL scheme — for example learnstaticweb001.z23.web.core.windows.net. Pass storage-static-website's primary_web_host output, NOT primary_web_endpoint: the latter is a full https:// URL and is rejected here. The value doubles as the origin host header, so the origin's TLS certificate is validated against it."
  type        = string
  validation {
    condition     = !can(regex("^https?://", var.origin_host_name))
    error_message = "origin_host_name must be a bare hostname with no URL scheme. Use the storage account's primary_web_host, not primary_web_endpoint."
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# OPTIONAL PARAMETERS
# ---------------------------------------------------------------------------------------------------------------------

variable "sku_name" {
  description = "Front Door tier. Standard covers a static site. Premium adds managed WAF rule sets, bot protection, and Private Link to the origin — the last of which is the only way to keep the storage account off the public Internet while Front Door still reaches it. Classic is retired and rejected."
  type        = string
  default     = "Standard_AzureFrontDoor"
  validation {
    condition     = contains(["Standard_AzureFrontDoor", "Premium_AzureFrontDoor"], var.sku_name)
    error_message = "Use Front Door Standard or Premium; Classic is retired."
  }
}

variable "tags" {
  description = "Resource tags."
  type        = map(string)
  default     = {}
}
