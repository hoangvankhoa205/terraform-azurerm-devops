variable "location" {
  description = "Azure region the disposable integration resources are created in."
  type        = string
  default     = "Southeast Asia"
}

variable "vm_size" {
  description = "VM size for the integration VM. Kept small deliberately — this exists to prove the module applies, not to run anything."
  type        = string
  default     = "Standard_B1s"
}
