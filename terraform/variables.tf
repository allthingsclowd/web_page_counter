variable "arm_subscription_id" {
  description = "Azure subscription identifier"
}

variable "arm_client_id" {
  description = "Service principal client identifier"
}

variable "arm_client_secret" {
  description = "Service principal secret"
}

variable "arm_tenant_id" {
  description = "Azure tenant identifier"
}

variable "arm_sshkey" {
  description = "Azure ssh public key"
}

variable "arm_resource_group" {
  description = "Resource Group Name"
}

variable "local_cidr" {
  description = "Firewall Access"
}

variable "location" {
  description = "The location where resources are created"
  default     = "West Europe"
}

variable "resource_group_name" {
  description = "The name of the resource group in which the resources are created"
  default     = "gjl-dev"
}