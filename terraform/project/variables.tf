variable "subscription_id" {
  description = "The Azure Subscription ID"
  type        = string
}

variable "existing_resource_group_name" {
  description = "The name of the existing resource group"
  type        = string
}

variable "location" {
  description = "The Azure region where resources will be created"
  type        = string
  default     = "eastus2"
}

variable "tags" {
  description = "A mapping of tags to assign to the resources"
  type        = map(string)
  default     = {}
}

variable "enable_rbac" {
  description = "Whether Terraform creates the included role assignments. Disable when roles are managed manually."
  type        = bool
  default     = true
}

variable "enable_private_networking" {
  description = "Disable account-wide public network access. The separately configured M365 Activity Protocol exception can still allow authenticated Microsoft channel traffic."
  type        = bool
  default     = false
}

variable "sharepoint_connections" {
  description = "SharePoint grounding connections keyed by connection name, each with a site or folder URL."
  type = map(object({
    site_url         = string
    is_shared_to_all = optional(bool, false)
  }))
  default = {}
}

variable "enable_m365_public_endpoint" {
  description = "Enable source-IP-filtered public Activity Protocol access for Microsoft 365 Copilot, independently of account public network access."
  type        = bool
  default     = false
}

variable "m365_authorization_scheme" {
  description = "BotServiceRbac for Shared/Personal publishing, or BotServiceTenant for Tenant publishing."
  type        = string
  default     = "BotServiceRbac"
}

variable "existing_network_resource_group_name" {
  description = "Resource group containing the externally managed VNet and subnets."
  type        = string
}

variable "existing_vnet_name" {
  description = "Name of the externally managed VNet."
  type        = string
}

variable "existing_private_endpoint_subnet_name" {
  description = "Name of the externally managed subnet used by private endpoints."
  type        = string
}

variable "existing_agent_subnet_name" {
  description = "Name of the dedicated subnet delegated to Microsoft.App/environments for Foundry Agent VNet injection."
  type        = string
}

# variable "existing_private_dns_zone_resource_group_name" {
#   description = "Resource group containing the externally managed Private DNS Zones."
#   type        = string
# }

variable "agent_definition_template_file" {
  description = "Optional YAML Terraform template path for the Foundry agent definition."
  type        = string
  default     = ""
}

variable "environment_prefix" {
  description = "Environment prefix"
  type        = string
}

variable "suffix" {
  description = "Random suffix for uniqueness"
  type        = string
}

variable "data_location" {
  description = "Azure region for data resources"
  type        = string
}

variable "workload" {
  description = "Workload name"
  type        = string
}

variable "openai_deployment_name" {
  description = "Name of the OpenAI deployment"
  type        = string
  default     = "gpt-4"
}

variable "openai_model_name" {
  description = "Name of the OpenAI model"
  type        = string
  default     = "gpt-4"
}

variable "openai_model_version" {
  description = "Version of the OpenAI model"
  type        = string
  default     = "1106-Preview"
}

variable "openai_model_sku_name" {
  description = "The SKU Name for the model deployment"
  type        = string
}

variable "openai_model_sku_capacity" {
  description = "The SKU Capacity for the model deployment"
  type        = number
}
