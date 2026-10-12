variable "subscription_id" {
  description = "The Azure Subscription ID"
  type        = string
}

variable "location" {
  description = "The Azure region where resources will be created"
  type        = string
  default     = "eastus"
}

variable "tags" {
  description = "A mapping of tags to assign to the resources"
  type        = map(string)
  default     = {}
}

variable "environment_prefix" {
  description = "Environment prefix (e.g., dev, prod)"
  type        = string
  default     = "dev"
}

variable "workload" {
  description = "Workload name"
  type        = string
}

variable "data_location" {
  description = "Azure region for data resources (defaults to location if not specified)"
  type        = string
  default     = ""
}

variable "apim_publisher_name" {
  description = "The name of publisher/company for APIM"
  type        = string
  default     = "Contoso"
}

variable "apim_publisher_email" {
  description = "The email of publisher/company for APIM"
  type        = string
  default     = "admin@contoso.com"
}

variable "apim_sku" {
  description = "The SKU name of the API Management Service"
  type        = string
  default     = "Developer"
}

variable "apim_sku_count" {
  description = "The number of units of the SKU"
  type        = number
  default     = 1
}

variable "enable_apim" {
  description = "Whether to create API Management and its API resources."
  type        = bool
  default     = true
}

variable "enable_rbac" {
  description = "Whether Terraform creates the included role assignments. Set false when roles are managed manually."
  type        = bool
  default     = true
}

variable "enable_private_networking" {
  description = "When true, the Foundry account is reachable only via its private endpoint. When false, it is publicly reachable (Entra ID auth still required)."
  type        = bool
  default     = false
}

variable "use_existing_network" {
  description = "Use a VNet and subnets managed by another team."
  type        = bool
  default     = false
}

variable "existing_network_resource_group_name" {
  description = "Resource group containing the externally managed VNet and subnets."
  type        = string
  default     = ""
}

variable "existing_vnet_name" {
  description = "Name of the externally managed VNet."
  type        = string
  default     = ""
}

variable "existing_private_endpoint_subnet_name" {
  description = "Name of the externally managed private-endpoint subnet."
  type        = string
  default     = ""
}

variable "existing_apim_subnet_name" {
  description = "Name of the externally managed APIM subnet."
  type        = string
  default     = ""
}

variable "agent_definition_template_file" {
  description = "Optional path to a custom YAML Terraform template for the agent definition."
  type        = string
  default     = ""
}

variable "openai_deployment_name" {
  description = "Name of the OpenAI deployment"
  type        = string
  default     = "gpt-4.1"
}

variable "openai_model_name" {
  description = "Name of the OpenAI model"
  type        = string
  default     = "gpt-4.1"
}

variable "openai_model_version" {
  description = "Version of the OpenAI model"
  type        = string
  default     = "2025-04-14"
}

variable "openai_model_sku_name" {
  description = "The SKU Name for the model deployment"
  default     = "GlobalStandard"
  type        = string
}

variable "openai_model_sku_capacity" {
  description = "The SKU Capacity for the model deployment"
  default     = 50
  type        = number
}