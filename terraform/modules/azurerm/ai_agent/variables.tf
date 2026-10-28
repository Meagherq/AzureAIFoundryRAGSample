variable "name" {
  type        = string
  description = "The name of the AI Agent."
}

variable "sharepoint_connections" {
  description = "SharePoint grounding connections keyed by connection name. Each connection scopes retrieval to one site or folder URL."
  type = map(object({
    site_url         = string
    is_shared_to_all = optional(bool, false)
  }))
  default = {}

  validation {
    condition = alltrue([
      for name, connection in var.sharepoint_connections :
      can(regex("^[a-zA-Z0-9][a-zA-Z0-9_-]{2,32}$", name)) &&
      can(regex("^https://[A-Za-z0-9.-]+/[^?#]+$", connection.site_url))
    ])
    error_message = "SharePoint connection names must be 3-33 alphanumeric, underscore or hyphen characters, starting with an alphanumeric character. Site/folder URLs must use HTTPS and have no query string or fragment."
  }
}

variable "enable_m365_public_endpoint" {
  description = "Enable the source-IP-filtered public Activity Protocol route for Microsoft 365 Copilot, without changing Foundry account public network access."
  type        = bool
  default     = false
}

variable "m365_authorization_scheme" {
  description = "Bot Service authorization for M365: BotServiceRbac for Shared/Personal publishing, or BotServiceTenant for Tenant publishing."
  type        = string
  default     = "BotServiceRbac"

  validation {
    condition     = contains(["BotServiceRbac", "BotServiceTenant"], var.m365_authorization_scheme)
    error_message = "Use BotServiceRbac or BotServiceTenant."
  }
}

variable "agent_definition_template_file" {
  type        = string
  default     = ""
  description = "Optional path to a YAML Terraform template for the agent definition. Defaults to the template shipped with this module."
}

variable "subscription_id" {
  description = "The Azure Subscription ID"
  type        = string
}

variable "resource_group_name" {
  description = "The Azure Resource Group Name"
  type        = string
}

variable "foundry_name" {
  description = "The name of the AI Foundry Cognitive Services Account."
  type        = string
}

variable "cognitive_account_id" {
  type        = string
  description = "The ID of the Cognitive Services Account."
}

variable "model_deployment_name" {
  type        = string
  description = "The name of the model deployment (e.g. gpt-4o)."
}

variable "search_endpoint" {
  type        = string
  description = "The endpoint of the Azure AI Search service."
}

variable "search_index_name" {
  type        = string
  description = "The name of the search index."
}

variable "search_key_names" {
  type        = list(string)
  default     = []
  description = "(Optional) If we need keys, usually we use RBAC now."
}

variable "project_id" {
  type        = string
  description = "The ID of the AI Foundry Project."
}

variable "project_endpoints" {
  type    = map(string)
  default = {}
}

variable "search_service_name" {
  type        = string
  description = "The name of the Azure AI Search service."
}

variable "search_service_id" {
  type        = string
  description = "The ID of the Azure AI Search service."
}

variable "knowledge_base_name" {
  type        = string
  description = "The name of the knowledge base (search index)."
}

variable "instructions" {
  type        = string
  default     = "You are a helpful AI assistant tasked with answering questions based on the provided knowledge base."
  description = "The instructions for the AI Agent."
}

variable "search_api_key" {
  type        = string
  description = "The Search Resource api key"
}

variable "search_index_connection_id" {
  type        = string
  description = "The Search Resource index id"
}