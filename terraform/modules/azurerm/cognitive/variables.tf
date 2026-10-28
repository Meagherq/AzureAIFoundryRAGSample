variable "name" {
  description = "Base name for resources (will be used to generate names for Hub, Project, Storage, etc.)"
  type        = string
}

variable "location" {
  description = "The Azure location where the resources should exist"
  type        = string
}

variable "resource_group_name" {
  description = "The name of the Resource Group"
  type        = string
}

variable "tags" {
  description = "A mapping of tags to assign to the resources"
  type        = map(string)
  default     = {}
}

variable "storage_account_id" {
  description = "The ID of the Storage Account"
  type        = string
}

variable "key_vault_id" {
  description = "The ID of the Key Vault"
  type        = string
}

variable "application_insights_id" {
  description = "The ID of the Application Insights"
  type        = string
}

variable "enable_private_networking" {
  description = "When true, disables public network access so the account is reachable only via its private endpoint."
  type        = bool
  default     = false
}

variable "agent_subnet_id" {
  description = "The ID of the dedicated subnet delegated to Microsoft.App/environments for Foundry Agent VNet injection."
  type        = string
}

variable "private_endpoint_subnet_id" {
  description = "The ID of the externally managed subnet for the private endpoint."
  type        = string
}

variable "private_dns_zone_ids" {
  description = "The IDs of the externally managed Private DNS Zones used when the DNS zone group is configured manually."
  type        = list(string)
}
