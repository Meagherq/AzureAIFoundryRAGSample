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

variable "enable_apim" {
  description = "Whether to create the API Management gateway and API resources."
  type        = bool
  default     = true
}

variable "enable_rbac" {
  description = "Whether Terraform creates the included role assignments. Disable when roles are managed manually."
  type        = bool
  default     = true
}

variable "enable_private_networking" {
  description = "When true, the Foundry account is reachable only via its private endpoint. When false, it is publicly reachable (Entra ID auth still required)."
  type        = bool
  default     = false
}

variable "use_existing_network" {
  description = "Use an externally managed VNet and subnet data sources instead of creating network resources."
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
  description = "Name of the externally managed subnet used by private endpoints."
  type        = string
  default     = ""
}

variable "existing_apim_subnet_name" {
  description = "Name of the externally managed subnet reserved for APIM. Required when APIM and an existing VNet are enabled."
  type        = string
  default     = ""
}

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
