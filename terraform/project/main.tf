terraform {
  required_providers {
    azurerm = {
      source                = "hashicorp/azurerm"
      # configuration_aliases = [azurerm.private_dns]
    }
    azapi = {
      source = "Azure/azapi"
    }
  }
}

data "azurerm_client_config" "current" {}

data "azurerm_virtual_network" "existing" {
  name                = var.existing_vnet_name
  resource_group_name = var.existing_network_resource_group_name
}

data "azurerm_subnet" "existing_private_endpoint" {
  name                 = var.existing_private_endpoint_subnet_name
  virtual_network_name = data.azurerm_virtual_network.existing.name
  resource_group_name  = var.existing_network_resource_group_name
}

data "azurerm_subnet" "existing_agent" {
  name                 = var.existing_agent_subnet_name
  virtual_network_name = data.azurerm_virtual_network.existing.name
  resource_group_name  = var.existing_network_resource_group_name
}

# data "azurerm_private_dns_zone" "cognitive" {
#   name                = "privatelink.cognitiveservices.azure.com"
#   resource_group_name = var.existing_private_dns_zone_resource_group_name
#   provider            = azurerm.private_dns
# }

# data "azurerm_private_dns_zone" "azureml" {
#   name                = "privatelink.azureml.azure.com"
#   resource_group_name = var.existing_private_dns_zone_resource_group_name
#   provider            = azurerm.private_dns
# }

# data "azurerm_private_dns_zone" "blob" {
#   name                = "privatelink.blob.core.windows.net"
#   resource_group_name = var.existing_private_dns_zone_resource_group_name
#   provider            = azurerm.private_dns
# }

# data "azurerm_private_dns_zone" "key_vault" {
#   name                = "privatelink.vaultcore.azure.net"
#   resource_group_name = var.existing_private_dns_zone_resource_group_name
#   provider            = azurerm.private_dns
# }

# data "azurerm_private_dns_zone" "search" {
#   name                = "privatelink.search.windows.net"
#   resource_group_name = var.existing_private_dns_zone_resource_group_name
#   provider            = azurerm.private_dns
# }

locals {
  actual_data_location = var.data_location != "" ? var.data_location : var.location
}

data "azurerm_resource_group" "existing_resource_group" {
  name = var.existing_resource_group_name
}

module "storage_account" {
  source = "../modules/azurerm/storage_account"

  name                       = "st${var.workload}${var.environment_prefix}${var.suffix}"
  location                   = var.location
  resource_group_name        = data.azurerm_resource_group.existing_resource_group.name
  containers                 = { "test" = { access_type = "private" } }
  private_endpoint_subnet_id = data.azurerm_subnet.existing_private_endpoint.id
  private_dns_zone_ids       = []
  # private_dns_zone_ids       = [data.azurerm_private_dns_zone.blob.id]
  tags                       = var.tags
}

module "key_vault" {
  source = "../modules/azurerm/key_vault"

  name                       = "kv-${var.workload}-${var.environment_prefix}-${var.suffix}"
  location                   = var.location
  resource_group_name        = data.azurerm_resource_group.existing_resource_group.name
  private_endpoint_subnet_id = data.azurerm_subnet.existing_private_endpoint.id
  private_dns_zone_ids       = []
  # private_dns_zone_ids       = [data.azurerm_private_dns_zone.key_vault.id]
  tags                       = var.tags
}

module "log_analytics" {
  source = "../modules/azurerm/log_analytics"

  name                = "log-${var.workload}-${var.environment_prefix}-${var.suffix}"
  location            = var.location
  resource_group_name = data.azurerm_resource_group.existing_resource_group.name
  tags                = var.tags
}

module "application_insights" {
  source = "../modules/azurerm/application_insights"

  name                = "appi-${var.workload}-${var.environment_prefix}-${var.suffix}"
  location            = var.location
  resource_group_name = data.azurerm_resource_group.existing_resource_group.name
  workspace_id        = module.log_analytics.id
  tags                = var.tags
}

module "search_service" {
  source = "../modules/azurerm/search_service"

  name                = "srch-${var.workload}-${var.environment_prefix}-${var.suffix}"
  location            = var.location
  resource_group_name = data.azurerm_resource_group.existing_resource_group.name
  tags                = var.tags

  # Semantic search typically requires Standard SKU.
  sku             = "standard"
  replica_count   = 1
  partition_count = 1

  public_network_access_enabled = false
  # Prefer Entra ID over admin keys.
  local_authentication_enabled = false
  private_endpoint_subnet_id   = data.azurerm_subnet.existing_private_endpoint.id
  # private_dns_zone_ids         = [data.azurerm_private_dns_zone.search.id]
  private_dns_zone_ids         = []
}

module "search_service_index" {
  source = "../modules/azurerm/search_service_index/"

  resource_group_name       = data.azurerm_resource_group.existing_resource_group.name
  location                  = var.location
  search_service_name       = module.search_service.name
  storage_connection_string = module.storage_account.primary_connection_string
  storage_account_name      = module.storage_account.name
  blob_container_name       = "test"

  datasource_name = "doc-datasource"
  index_name      = "ragdocs"
  skillset_name   = "doc-skillset"
  indexer_name    = "doc-indexer"

  # Indexer validates storage access on create, so the search MI role must be live first.
  depends_on = [
    time_sleep.wait_for_search_storage_role,
    azurerm_role_assignment.current_user_search_contributor,
  ]
}

resource "azurerm_role_assignment" "cognitive_search_reader" {
  count                = var.enable_rbac ? 1 : 0
  scope                = module.search_service.id
  role_definition_name = "Search Index Data Reader"
  principal_id         = module.cognitive.identity_principal_id
}

# Keyless (AAD) search connections use the Foundry account identity.
resource "azurerm_role_assignment" "cognitive_search_index_contributor" {
  count                = var.enable_rbac ? 1 : 0
  scope                = module.search_service.id
  role_definition_name = "Search Index Data Contributor"
  principal_id         = module.cognitive.identity_principal_id
}

resource "azurerm_role_assignment" "cognitive_search_service_contributor" {
  count                = var.enable_rbac ? 1 : 0
  scope                = module.search_service.id
  role_definition_name = "Search Service Contributor"
  principal_id         = module.cognitive.identity_principal_id
}

resource "azurerm_role_assignment" "current_user_search_contributor" {
  count                = var.enable_rbac ? 1 : 0
  scope                = module.search_service.id
  role_definition_name = "Search Index Data Contributor"
  principal_id         = data.azurerm_client_config.current.object_id
}

resource "azurerm_role_assignment" "cognitive_project_search_reader" {
  count                = var.enable_rbac ? 1 : 0
  scope                = module.search_service.id
  role_definition_name = "Search Index Data Reader"
  principal_id         = module.cognitive_project.identity_principal_id
}

resource "azurerm_role_assignment" "current_user_search_project_contributor" {
  count                = var.enable_rbac ? 1 : 0
  scope                = module.search_service.id
  role_definition_name = "Search Index Data Contributor"
  principal_id         = module.cognitive_project.identity_principal_id
}

resource "azurerm_role_assignment" "current_search_project_contributor" {
  count                = var.enable_rbac ? 1 : 0
  scope                = module.search_service.id
  role_definition_name = "Search Service Contributor"
  principal_id         = module.cognitive_project.identity_principal_id
}

resource "azurerm_role_assignment" "search_storage_reader" {
  count                = var.enable_rbac ? 1 : 0
  scope                = module.storage_account.id
  role_definition_name = "Storage Blob Data Reader"
  principal_id         = module.search_service.principal_id
}

resource "time_sleep" "wait_for_search_storage_role" {
  count           = var.enable_rbac ? 1 : 0
  depends_on      = [azurerm_role_assignment.search_storage_reader]
  create_duration = "120s"
}

# The deploying principal needs permission to create AI agents via the REST API.
# "Foundry User" (formerly "Azure AI User") includes the Microsoft.CognitiveServices/accounts/AIServices/agents/* data action.
resource "azurerm_role_assignment" "deployer_cognitive_ai_user" {
  count              = var.enable_rbac ? 1 : 0
  scope              = module.cognitive.id
  role_definition_id = "/subscriptions/${data.azurerm_client_config.current.subscription_id}/providers/Microsoft.Authorization/roleDefinitions/53ca6127-db72-4b80-b1b0-d745d6d5456d"
  principal_id       = data.azurerm_client_config.current.object_id
}

resource "time_sleep" "wait_for_ai_developer_role" {
  count           = var.enable_rbac ? 1 : 0
  depends_on      = [azurerm_role_assignment.deployer_cognitive_ai_user]
  create_duration = "60s"
}

module "cognitive" {
  source = "../modules/azurerm/cognitive"

  name                    = "${var.workload}-${var.environment_prefix}-${var.suffix}"
  location                = var.location
  resource_group_name     = data.azurerm_resource_group.existing_resource_group.name
  storage_account_id      = module.storage_account.id
  key_vault_id            = module.key_vault.id
  application_insights_id = module.application_insights.id
  tags                    = var.tags

  enable_private_networking  = var.enable_private_networking
  agent_subnet_id            = data.azurerm_subnet.existing_agent.id
  private_endpoint_subnet_id = data.azurerm_subnet.existing_private_endpoint.id
  private_dns_zone_ids = [
    data.azurerm_private_dns_zone.cognitive.id,
    data.azurerm_private_dns_zone.azureml.id,
  ]
}

module "cognitive_project" {
  source = "../modules/azurerm/cognitive_project"

  name                 = "${var.workload}-${var.environment_prefix}-${var.suffix}"
  display_name         = "RAG Project"
  description          = "RAG Project for Azure AI Foundry"
  location             = var.location
  cognitive_account_id = module.cognitive.id
  tags                 = var.tags
}

module "cognitive_deployment" {
  source = "../modules/azurerm/cognitive_deployment"

  deployment_name      = var.openai_deployment_name
  cognitive_account_id = module.cognitive.id
  model_name           = var.openai_model_name
  model_version        = var.openai_model_version
  model_sku_name       = var.openai_model_sku_name
  model_sku_capacity   = var.openai_model_sku_capacity

}

module "ai_agent" {
  source = "../modules/azurerm/ai_agent"

  name                           = "agent-${var.workload}-${var.environment_prefix}-${var.suffix}"
  agent_definition_template_file = var.agent_definition_template_file
  cognitive_account_id           = module.cognitive.id
  model_deployment_name          = var.openai_deployment_name
  search_endpoint                = module.search_service.endpoint
  search_index_name              = "ragdocs"

  project_id                 = module.cognitive_project.id
  project_endpoints          = module.cognitive_project.endpoints
  search_service_name        = module.search_service.name
  knowledge_base_name        = "ragdocs"
  search_api_key             = module.search_service.apiKey
  search_service_id          = module.search_service.id
  search_index_connection_id = module.search_service.id
  subscription_id            = var.subscription_id
  resource_group_name        = data.azurerm_resource_group.existing_resource_group.name
  foundry_name               = module.cognitive.name

  depends_on = [module.cognitive_deployment, module.search_service_index]
}
